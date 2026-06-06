// ComplicationSyncToWatch.swift
// Adicionar ao target iOS do temporun-app
// Envia dados de streak, XP, progresso semanal e próximo treino para as complicações
// Chamar syncComplicationData() sempre que:
//   - O usuário termina uma corrida
//   - O plano de treino é atualizado
//   - O app volta ao foreground

import Foundation
import WatchConnectivity
import ClockKit   // para CLKComplicationServer

final class ComplicationSyncToWatch {
    static let shared = ComplicationSyncToWatch()
    static let contextKey = "complicationData"

    private init() {}

    // Montar e enviar os dados de complicação
    // Parâmetros vêm do estado atual do app (Supabase / estado local)
    func syncComplicationData(
        weeklyKm: Double,
        weeklyGoalKm: Double,
        streakDays: Int,
        xp: Int,
        plan: TrainingPlanTransfer?
    ) {
        let nextWorkout = nextWorkout(from: plan)

        var data = ComplicationDataTransfer()
        data.weeklyKm       = weeklyKm
        data.weeklyGoalKm   = weeklyGoalKm
        data.streakDays     = streakDays
        data.xp             = xp
        data.nextWorkoutType = nextWorkout?.tipo ?? ""
        data.nextWorkoutKm   = nextWorkout?.distancia_km ?? 0
        data.nextWorkoutPace = nextWorkout?.pace_alvo ?? ""
        data.nextWorkoutDay  = nextWorkoutLabel(workout: nextWorkout)

        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let encoded = try? JSONEncoder().encode(data)
        else { return }

        // transferCurrentComplicationUserInfo garante prioridade máxima de entrega
        if WCSession.default.isComplicationEnabled {
            WCSession.default.transferCurrentComplicationUserInfo(
                [Self.contextKey: encoded]
            )
        } else {
            // Fallback: context normal
            try? WCSession.default.updateApplicationContext([Self.contextKey: encoded])
        }
    }

    // Determina qual é o próximo treino (hoje ou amanhã)
    private func nextWorkout(from plan: TrainingPlanTransfer?) -> DailyWorkoutTransfer? {
        guard let plan else { return nil }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let names = ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"]

        for week in plan.semanas {
            // Busca hoje primeiro
            if let today = week.dias.first(where: { $0.dia == names[weekday - 1] }),
               !WorkoutTypeHelper.isRest(today.tipo) {
                return today
            }
            // Busca amanhã
            let tomorrowIdx = weekday % 7
            if let tomorrow = week.dias.first(where: { $0.dia == names[tomorrowIdx] }),
               !WorkoutTypeHelper.isRest(tomorrow.tipo) {
                return tomorrow
            }
        }
        return nil
    }

    private func nextWorkoutLabel(workout: DailyWorkoutTransfer?) -> String {
        guard let workout else { return "" }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let names = ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"]
        if workout.dia == names[weekday - 1] { return "Hoje" }
        let tomorrowIdx = weekday % 7
        if workout.dia == names[tomorrowIdx] { return "Amanhã" }
        return workout.dia
    }
}

// Codable espelhando ComplicationData do Watch
struct ComplicationDataTransfer: Codable {
    var weeklyKm: Double = 0
    var weeklyGoalKm: Double = 0
    var streakDays: Int = 0
    var xp: Int = 0
    var nextWorkoutType: String = ""
    var nextWorkoutKm: Double = 0
    var nextWorkoutPace: String = ""
    var nextWorkoutDay: String = ""
}

// Helper para checar tipo de descanso sem depender do Watch target
enum WorkoutTypeHelper {
    static func isRest(_ tipo: String) -> Bool {
        tipo == "Descanso" || tipo == "Descanso Ativo"
    }
}
