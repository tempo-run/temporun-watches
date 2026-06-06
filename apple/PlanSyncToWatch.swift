// PlanSyncToWatch.swift
// Adicionar ao target iOS do temporun-app (ios/App/App/)
// Responsável por enviar o plano de treino ativo ao Watch via WatchConnectivity
// Chamar PlanSyncToWatch.shared.syncActivePlan(plan) sempre que:
//   - O app abre e há um plano ativo
//   - O usuário gera/atualiza um plano
//   - O Watch solicita via requestPlanFromPhone()

import Foundation
import WatchConnectivity

// Estrutura que espelha o formato do SYS_PLAN_WEEK para serialização
// (mesmos campos de DailyWorkout no Watch)
struct DailyWorkoutTransfer: Codable {
    let dia: String
    let tipo: String
    let distancia_km: Double
    let pace_alvo: String
    let descricao: String
    let detalhe_treino: String
    let alerta_lesao: String
}

struct TrainingWeekTransfer: Codable {
    let semana: Int
    let foco: String
    let volume_km: Double
    let treinos_chave: [String]
    let descansos: Int
    let resumo: String
    let intensidade: String
    let dias: [DailyWorkoutTransfer]
}

struct TrainingPlanTransfer: Codable {
    let id: String
    let objetivo: String
    let nivel: String
    let semanas: [TrainingWeekTransfer]
    let resumo_semanal: String
    let ativo: Bool
}

// MARK: - PlanSyncToWatch

final class PlanSyncToWatch: NSObject {
    static let shared = PlanSyncToWatch()
    static let planContextKey = "trainingPlan"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Chamado quando o plano ativo muda ou o app abre
    func syncActivePlan(_ plan: TrainingPlanTransfer) {
        guard WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(plan)
        else { return }

        if WCSession.default.isReachable {
            // Watch por perto: atualiza contexto imediatamente
            try? WCSession.default.updateApplicationContext([Self.planContextKey: data])
        } else {
            // Watch offline: enfileira para entrega posterior
            WCSession.default.transferUserInfo([Self.planContextKey: data])
        }
    }

    // Converte o JSON do Supabase (planos_treino.semanas) para TrainingPlanTransfer
    // Chamar com os dados da tabela planos_treino após query ao Supabase
    func buildTransfer(from supabaseRow: [String: Any]) -> TrainingPlanTransfer? {
        guard
            let id        = supabaseRow["id"]       as? String,
            let objetivo  = supabaseRow["objetivo"] as? String,
            let nivel     = supabaseRow["nivel"]    as? String,
            let semanasRaw = supabaseRow["semanas"] as? [[String: Any]]
        else { return nil }

        let semanas = semanasRaw.compactMap { buildWeek(from: $0) }

        return TrainingPlanTransfer(
            id:             id,
            objetivo:       objetivo,
            nivel:          nivel,
            semanas:        semanas,
            resumo_semanal: supabaseRow["resumo_semanal"] as? String ?? "",
            ativo:          supabaseRow["ativo"] as? Bool ?? true
        )
    }

    private func buildWeek(from dict: [String: Any]) -> TrainingWeekTransfer? {
        guard let semana = dict["semana"] as? Int else { return nil }
        let dias = (dict["dias"] as? [[String: Any]] ?? []).compactMap { buildDay(from: $0) }
        return TrainingWeekTransfer(
            semana:        semana,
            foco:          dict["foco"]        as? String ?? "",
            volume_km:     dict["volume_km"]   as? Double ?? 0,
            treinos_chave: dict["treinos_chave"] as? [String] ?? [],
            descansos:     dict["descansos"]   as? Int ?? 0,
            resumo:        dict["resumo"]      as? String ?? "",
            intensidade:   dict["intensidade"] as? String ?? "",
            dias:          dias
        )
    }

    private func buildDay(from dict: [String: Any]) -> DailyWorkoutTransfer? {
        guard let dia  = dict["dia"]  as? String,
              let tipo = dict["tipo"] as? String
        else { return nil }
        return DailyWorkoutTransfer(
            dia:            dia,
            tipo:           tipo,
            distancia_km:   dict["distancia_km"]  as? Double ?? 0,
            pace_alvo:      dict["pace_alvo"]     as? String ?? "",
            descricao:      dict["descricao"]     as? String ?? "",
            detalhe_treino: dict["detalhe_treino"] as? String ?? "",
            alerta_lesao:   dict["alerta_lesao"]  as? String ?? ""
        )
    }
}

// MARK: - WCSessionDelegate (iOS)

extension PlanSyncToWatch: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // Watch pediu o plano via requestPlanFromPhone()
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["request"] as? String == "trainingPlan" else {
            replyHandler([:])
            return
        }
        // Notifica o app iOS para responder com o plano atual
        NotificationCenter.default.post(
            name: .watchRequestedPlan,
            object: replyHandler
        )
    }
}

extension Notification.Name {
    static let watchRequestedPlan = Notification.Name("watchRequestedPlan")
}
