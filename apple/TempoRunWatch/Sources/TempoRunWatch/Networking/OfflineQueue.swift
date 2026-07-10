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

    func enqueue(_ payload: [String: Any]) {
        let item = QueuedWorkout(payload: payload)
        queue.append(item)
        lastSyncStatus = .idle
    }

    // MARK: - Sincronizar

    func syncAll() async {
        guard !queue.isEmpty, !isSyncing else { return }
        isSyncing = true
        lastSyncStatus = .syncing
        var synced = 0

        for i in queue.indices.reversed() {
            var item = queue[i]
            guard item.attempts < maxAttempts else {
                // Descarta após max tentativas para não travar a fila
                queue.remove(at: i)
                continue
            }

            do {
                try await SupabaseClient.shared.insertCorrida(item.payloadDict)
                queue.remove(at: i)
                synced += 1
            } catch SupabaseError.httpError(401, _) {
                // Token expirado — tenta refresh uma vez
                let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
                if let refreshTok = defaults.string(forKey: "supabaseRefreshToken") {
                    _ = try? await SupabaseClient.shared.refreshToken(refreshToken: refreshTok)
                    // Retry imediato após refresh
                    do {
                        try await SupabaseClient.shared.insertCorrida(item.payloadDict)
                        queue.remove(at: i)
                        synced += 1
                    } catch {
                        item.attempts += 1
                        item.lastError = error.localizedDescription
                        queue[i] = item
                    }
                } else {
                    // Sem refresh token: conta a tentativa para não travar a fila
                    // indefinidamente (descartada após maxAttempts).
                    item.attempts += 1
                    item.lastError = "401 sem refresh token"
                    queue[i] = item
                }
            } catch {
                item.attempts += 1
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
