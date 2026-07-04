import SwiftUI

// MARK: - Plano tab (visão semanal)

struct PlanoView: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // Header
                Text("TRAINING")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.tempoCyan)
                    .kerning(1.5)

                if let week = planManager.plan?.currentWeek {
                    Text("Semana \(week.semana)/\(planManager.plan?.semanas.count ?? 0)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(week.foco) · \(String(format: "%.0f", week.volume_km)) km planejados")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                } else {
                    Text("Plano semanal")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                // Day bubbles
                if !planManager.weekWorkouts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(planManager.weekWorkouts) { day in
                                DayBubble(workout: day)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Workout list
                if planManager.weekWorkouts.isEmpty {
                    Text("Nenhum plano carregado")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                } else {
                    VStack(spacing: 4) {
                        ForEach(planManager.weekWorkouts) { day in
                            PlanoDayRow(workout: day)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Day bubble

private struct DayBubble: View {
    let workout: DailyWorkout

    private var isToday: Bool { todayName() == workout.dia }

    private var abbreviation: String {
        let map = ["Segunda": "Seg", "Terça": "Ter", "Quarta": "Qua",
                   "Quinta": "Qui", "Sexta": "Sex", "Sábado": "Sáb", "Domingo": "Dom"]
        return map[workout.dia] ?? String(workout.dia.prefix(3))
    }

    private var content: String {
        workout.workoutType.isRest ? "Off" : String(format: "%.0fk", workout.distancia_km)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(abbreviation)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(isToday ? .white : .gray)

            ZStack {
                if isToday {
                    Circle()
                        .fill(LinearGradient.tempoPurpleCyan)
                        .frame(width: 30, height: 30)
                } else {
                    Circle()
                        .fill(Color.tempoCard)
                        .frame(width: 30, height: 30)
                }
                Text(content)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isToday ? .white : .gray)
            }
        }
    }
}

// MARK: - Day row

private struct PlanoDayRow: View {
    let workout: DailyWorkout

    private var isToday: Bool { todayName() == workout.dia }

    private var typeInitial: String {
        switch workout.workoutType.intensityColor {
        case .rest:     return "–"
        case .easy:     return "L"
        case .moderate: return "M"
        case .hard:     return "I"
        }
    }

    private var typeColor: Color {
        switch workout.workoutType.intensityColor {
        case .rest:     return .gray
        case .easy:     return .tempoCyan
        case .moderate: return .tempoPurple
        case .hard:     return .tempoMagenta
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                Text(typeInitial)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(typeColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(workout.tipo)
                    .font(.system(size: 11, weight: isToday ? .semibold : .regular))
                    .foregroundColor(isToday ? .white : .white.opacity(0.55))
                    .lineLimit(1)
                if !workout.workoutType.isRest {
                    Text("\(String(format: "%.1f", workout.distancia_km)) km · "
                         + workout.pace_alvo.replacingOccurrences(of: "/km", with: ""))
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            if isToday {
                Circle()
                    .fill(LinearGradient.tempoPurpleCyan)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isToday ? Color.tempoCard : Color.clear)
        .cornerRadius(10)
    }
}

// MARK: - Helper

private func todayName() -> String {
    let weekday = Calendar.current.component(.weekday, from: Date())
    return ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"][weekday - 1]
}
