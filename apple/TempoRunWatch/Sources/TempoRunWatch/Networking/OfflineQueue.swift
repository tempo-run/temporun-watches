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

    // Remove um item específico (chamado quando o servidor confirmou o insert
    // por outro caminho — ex.: envio direto no endWorkout).
    func remove(_ id: UUID) {
        queue.removeAll { $0.id == id }
    }

    // MARK: - Sincronizar

    // Política de retry: corrida NUNCA é descartada por falha transitória.
    //  - Sem credenciais / 401 sem refresh → mantém e aguarda novo login
    //    (applyCredentials dispara syncAll ao receber credenciais do iPhone).
    //  - Rede fora / timeout / 5xx → mantém; retry no próximo gatilho
    //    (rede voltou, app em foreground, credenciais chegaram).
    //  - Só 4xx permanente (payload rejeitado pelo servidor) conta tentativa
    //    e descarta após maxAttempts, para não travar a fila com lixo.
    func syncAll() async {
        guard !queue.isEmpty, !isSyncing else { return }
        guard SupabaseConfig.isConfigured else { return }   // aguarda credenciais
        isSyncing = true
        lastSyncStatus = .syncing
        var synced = 0

        outer: for i in queue.indices.reversed() {
            var item = queue[i]

            do {
                try await SupabaseClient.shared.insertCorrida(item.payloadDict)
                queue.remove(at: i)
                synced += 1
            } catch SupabaseError.notConfigured {
                break outer   // credenciais sumiram no meio (logout) — aguarda login
            } catch SupabaseError.httpError(401, _) {
                // Token expirado — tenta refresh uma vez
                let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
                guard let refreshTok = defaults.string(forKey: "supabaseRefreshToken") else {
                    // Sem refresh token (ex.: logout): mantém a corrida e para;
                    // sincroniza quando o iPhone reenviar credenciais válidas.
                    item.lastError = "aguardando novo login (401)"
                    queue[i] = item
                    break outer
                }
                _ = try? await SupabaseClient.shared.refreshToken(refreshToken: refreshTok)
                // Retry imediato após refresh
                do {
                    try await SupabaseClient.shared.insertCorrida(item.payloadDict)
                    queue.remove(at: i)
                    synced += 1
                } catch {
                    // Refresh não resolveu agora; para de martelar o backend e
                    // espera o próximo gatilho de sync.
                    item.lastError = error.localizedDescription
                    queue[i] = item
                    break outer
                }
            } catch SupabaseError.httpError(let code, let msg)
                    where (400...499).contains(code) && code != 408 && code != 429 {
                // Erro permanente: o servidor rejeitou o payload. Única situação
                // que conta tentativa e pode descartar (após maxAttempts).
                item.attempts += 1
                item.lastError = "HTTP \(code): \(msg)"
                if item.attempts >= maxAttempts {
                    queue.remove(at: i)
                } else {
                    queue[i] = item
                }
            } catch {
                // Transitório (rede, timeout, 5xx): mantém sem contar tentativa.
                item.lastError = error.localizedDescription
                queue[i] = item
            }
        }

        isSyncing = false
        lastSyncStatus = synced > 0 ? .success(synced) : (queue.isEmpty ? .success(0) : .failed(queue.last?.lastError ?? "erro"))
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
