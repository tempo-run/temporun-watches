import Foundation

// MARK: - Item da fila

struct QueuedWorkout: Codable, Identifiable {
    let id: UUID
    let payload: [String: AnyCodable]   // dados da corrida prontos para o Supabase
    let queuedAt: Date
    var attempts: Int = 0
    var lastError: String?

    init(payload: [String: Any]) {
        self.id        = UUID()
        self.payload   = payload.mapValues { AnyCodable($0) }
        self.queuedAt  = Date()
    }

    var payloadDict: [String: Any] {
        payload.mapValues { $0.value }
    }
}

// Wrapper Codable para Any (necessário para serializar [String: Any])
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self)           { value = v }
        else if let v = try? container.decode(Int.self)       { value = v }
        else if let v = try? container.decode(Double.self)    { value = v }
        else if let v = try? container.decode(String.self)    { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v.map(\.value) }
        else if let v = try? container.decode([String: AnyCodable].self) {
            value = v.mapValues(\.value)
        } else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:              try container.encode(v)
        case let v as Int:               try container.encode(v)
        case let v as Double:            try container.encode(v)
        case let v as String:            try container.encode(v)
        case let v as [Any]:             try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]:     try container.encode(v.mapValues { AnyCodable($0) })
        default:                         try container.encodeNil()
        }
    }
}

// MARK: - OfflineQueue

@MainActor
final class OfflineQueue: ObservableObject {
    static let shared = OfflineQueue()

    @Published var pendingCount: Int = 0
    @Published var isSyncing = false
    @Published var lastSyncStatus: SyncStatus = .idle

    private let appGroupID  = "group.com.temporun.run"
    private let queueKey    = "offlineWorkoutQueue"
    private let maxAttempts = 5

    enum SyncStatus: Equatable {
        case idle, syncing, success(Int), failed(String)
    }

    private var queue: [QueuedWorkout] = [] {
        didSet { pendingCount = queue.count; persist() }
    }

    private init() { load() }

    // MARK: - Enfileirar

    @discardableResult
    func enqueue(_ payload: [String: Any]) -> UUID {
        let item = QueuedWorkout(payload: payload)
        queue.append(item)
        lastSyncStatus = .idle
        return item.id
    }

    // MARK: - Sincronizar

    // Drena a fila. Ponto de entrada único — protegido por `isSyncing` (exclusão
    // mútua). Todas as mutações são feitas RE-LOCALIZANDO o item por `id`, nunca
    // por índice capturado antes de um `await`: isso elimina o crash de "index out
    // of range" quando outro caminho (remove/enqueue) muta a fila durante a rede.
    //
    // Política de retry: corrida NUNCA é descartada por falha transitória.
    //  - Sem credenciais / 401 sem refresh → mantém e aguarda novo login.
    //  - Rede fora / timeout / 5xx → mantém; retry no próximo gatilho.
    //  - Só 4xx permanente (payload rejeitado) conta tentativa e descarta após
    //    maxAttempts, para não travar a fila com lixo.
    func syncAll() async {
        _ = await flush(target: nil)
    }

    // Drena a fila e devolve o WatchSaveResult do item `target` (se ele foi
    // gravado nesta passagem). `endWorkout` usa isso para mostrar XP/streak.
    @discardableResult
    func flush(target: UUID?) async -> WatchSaveResult? {
        guard !isSyncing else { return nil }
        guard SupabaseConfig.isConfigured else { return nil }   // aguarda credenciais
        guard !queue.isEmpty else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        lastSyncStatus = .syncing
        var synced = 0
        var targetResult: WatchSaveResult?

        // Processa por id, sempre re-localizando o item (nunca por índice
        // capturado antes de um `await`). O laço pega também itens que chegam
        // DURANTE a drenagem (ex.: corrida encerrada enquanto um sync já rodava),
        // cada id no máximo uma vez — `processed` evita loop infinito em falhas.
        var processed = Set<UUID>()
        loop: while true {
            guard let id = queue.first(where: { !processed.contains($0.id) })?.id else {
                break loop
            }
            processed.insert(id)
            guard let payloadDict = queue.first(where: { $0.id == id })?.payloadDict else {
                continue   // item já removido por outro caminho
            }

            do {
                let result = try await SupabaseClient.shared.insertCorrida(payloadDict)
                queue.removeAll { $0.id == id }
                synced += 1
                if id == target { targetResult = result }
            } catch SupabaseError.notConfigured {
                break loop   // credenciais sumiram no meio (logout) — aguarda login
            } catch SupabaseError.httpError(401, _) {
                // Token expirado — tenta refresh uma vez
                let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
                guard let refreshTok = defaults.string(forKey: "supabaseRefreshToken") else {
                    setError(id, "aguardando novo login (401)")
                    break loop
                }
                _ = try? await SupabaseClient.shared.refreshToken(refreshToken: refreshTok)
                do {
                    let result = try await SupabaseClient.shared.insertCorrida(payloadDict)
                    queue.removeAll { $0.id == id }
                    synced += 1
                    if id == target { targetResult = result }
                } catch {
                    setError(id, error.localizedDescription)
                    break loop
                }
            } catch SupabaseError.httpError(let code, let msg)
                    where (400...499).contains(code) && code != 408 && code != 429 {
                // Erro permanente: servidor rejeitou o payload. Única situação
                // que conta tentativa e pode descartar (após maxAttempts).
                bumpAttempt(id, error: "HTTP \(code): \(msg)")
            } catch {
                // Transitório (rede, timeout, 5xx): mantém sem contar tentativa.
                setError(id, error.localizedDescription)
            }
        }

        lastSyncStatus = synced > 0 ? .success(synced) : (queue.isEmpty ? .success(0) : .failed(queue.last?.lastError ?? "erro"))
        return targetResult
    }

    // Atualiza lastError de um item (re-localiza por id).
    private func setError(_ id: UUID, _ message: String) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[idx].lastError = message
    }

    // Conta uma tentativa permanente; descarta se passar do teto.
    private func bumpAttempt(_ id: UUID, error: String) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[idx].attempts += 1
        queue[idx].lastError = error
        if queue[idx].attempts >= maxAttempts {
            queue.removeAll { $0.id == id }
        }
    }

    // MARK: - Persistência (UserDefaults App Group)

    private func persist() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: queueKey)
        }
    }

    private func load() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = defaults.data(forKey: queueKey),
              let saved = try? JSONDecoder().decode([QueuedWorkout].self, from: data)
        else { return }
        queue = saved
    }

    func clear() { queue = [] }
}
