// CredentialSyncToWatch.swift
// Adicionar ao target iOS do temporun-app
// Envia credenciais Supabase ao Watch via WatchConnectivity + App Group
// Chamar syncCredentials() após login bem-sucedido e ao abrir o app

import Foundation
import WatchConnectivity

final class CredentialSyncToWatch {
    static let shared = CredentialSyncToWatch()
    static let contextKey = "supabaseCredentials"
    static let appGroupID = "group.com.temporun.run"

    private init() {}

    func syncCredentials(
        url: String,
        anonKey: String,
        accessToken: String,
        refreshToken: String,
        userId: String
    ) {
        // Persiste no App Group (compartilhado com Watch Extension)
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        defaults.set(url,          forKey: "supabaseUrl")
        defaults.set(anonKey,      forKey: "supabaseAnonKey")
        defaults.set(accessToken,  forKey: "supabaseAccessToken")
        defaults.set(refreshToken, forKey: "supabaseRefreshToken")
        defaults.set(userId,       forKey: "supabaseUserId")

        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated
        else { return }

        // Envia via WatchConnectivity para o Watch ter as credenciais em memória
        // Não enviamos a anon key em plaintext na mensagem — já está no App Group
        let context: [String: Any] = [
            Self.contextKey: [
                "url":          url,
                "anonKey":      anonKey,
                "accessToken":  accessToken,
                "refreshToken": refreshToken,
                "userId":       userId
            ]
        ]
        try? WCSession.default.updateApplicationContext(context)
    }

    // Invalida credenciais ao fazer logout
    func clearCredentials() {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        ["supabaseUrl", "supabaseAnonKey", "supabaseAccessToken",
         "supabaseRefreshToken", "supabaseUserId"].forEach {
            defaults.removeObject(forKey: $0)
        }
        try? WCSession.default.updateApplicationContext([Self.contextKey: NSNull()])
    }
}
