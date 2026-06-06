import Foundation

// MARK: - Configuração
// Preencher com as variáveis do projeto Supabase (mesmo do temporun-app)
// Recomendado: guardar no App Group UserDefaults, recebido do iPhone via WatchConnectivity

struct SupabaseConfig {
    static let appGroupID = "group.com.temporun.run"

    static var url: String {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "supabaseUrl") ?? ""
    }
    static var anonKey: String {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "supabaseAnonKey") ?? ""
    }
    static var accessToken: String {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "supabaseAccessToken") ?? ""
    }
    static var userId: String {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "supabaseUserId") ?? ""
    }

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty && !accessToken.isEmpty && !userId.isEmpty
    }
}

// MARK: - Resultado da edge function

struct WatchSaveResult: Codable {
    let corrida_id: String
    let xp_ganho: Int
    let streak_atual: Int
    let novos_recordes: [RecordPayload]
    let is_duplicate: Bool
}

struct RecordPayload: Codable {
    let distancia: String
    let tempo_anterior: Int?
    let tempo_novo: Int
}

// MARK: - Erros

enum SupabaseError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case noNetwork

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "Credenciais Supabase não configuradas"
        case .invalidURL:         return "URL inválida"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodingError(let e):    return "Decodificação: \(e.localizedDescription)"
        case .noNetwork:          return "Sem conexão"
        }
    }
}

// MARK: - SupabaseClient

final class SupabaseClient {
    static let shared = SupabaseClient()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true   // espera rede ao invés de falhar
        session = URLSession(configuration: config)
    }

    // MARK: - Salvar corrida via edge function watch-workout-save
    // Calcula XP, streak e recordes atomicamente no servidor

    @discardableResult
    func insertCorrida(_ payload: [String: Any]) async throws -> WatchSaveResult {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfig.url)/functions/v1/watch-workout-save") else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.httpError(0, "sem resposta")
        }

        if http.statusCode == 401 { throw SupabaseError.httpError(401, "token expirado") }

        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "erro desconhecido"
            throw SupabaseError.httpError(http.statusCode, msg)
        }

        // Decodifica resultado com XP e streak para exibir no SummaryView
        let result = try JSONDecoder().decode(WatchSaveResult.self, from: data)
        return result
    }

    // MARK: - Fallback REST direto (usado quando edge function não está disponível)

    func insertCorridaREST(_ payload: [String: Any]) async throws {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        guard let url = URL(string: "\(SupabaseConfig.url)/rest/v1/corridas") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var body = payload
        body["user_id"] = SupabaseConfig.userId
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        if !(200...299).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? "erro desconhecido"
            throw SupabaseError.httpError(http.statusCode, msg)
        }
    }

    // MARK: - Buscar plano ativo (fallback standalone)

    func fetchActivePlan() async throws -> [String: Any]? {
        guard SupabaseConfig.isConfigured else { throw SupabaseError.notConfigured }
        let urlStr = "\(SupabaseConfig.url)/rest/v1/planos_treino?ativo=eq.true&user_id=eq.\(SupabaseConfig.userId)&limit=1"
        guard let url = URL(string: urlStr) else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey,      forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",          forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return rows?.first
    }

    // MARK: - Refresh de token

    func refreshToken(refreshToken: String) async throws -> (accessToken: String, newRefresh: String) {
        guard let url = URL(string: "\(SupabaseConfig.url)/auth/v1/token?grant_type=refresh_token") else {
            throw SupabaseError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, _) = try await session.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access  = json["access_token"]  as? String,
              let refresh = json["refresh_token"] as? String
        else { throw SupabaseError.decodingError(NSError(domain: "token", code: 0)) }

        // Persiste tokens atualizados no App Group
        let defaults = UserDefaults(suiteName: SupabaseConfig.appGroupID) ?? .standard
        defaults.set(access,  forKey: "supabaseAccessToken")
        defaults.set(refresh, forKey: "supabaseRefreshToken")

        return (access, refresh)
    }
}
