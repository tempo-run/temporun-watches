import SwiftUI

// MARK: - Widgets tab (Smart Stack preview)

struct WidgetsView: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    private var weekDone: Double {
        guard let week = planManager.plan?.currentWeek else { return 0 }
        return week.volume_km * 0.48  // placeholder: ~half done
    }
    private var weekTotal: Double {
        planManager.plan?.currentWeek?.volume_km ?? 0
    }
    private var nextWorkout: DailyWorkout? {
        let today = Calendar.current.component(.weekday, from: Date())
        let names = ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"]
        let todayName = names[today - 1]
        var foundToday = false
        for w in planManager.weekWorkouts {
            if foundToday && !w.workoutType.isRest { return w }
            if w.dia == todayName { foundToday = true }
        }
        return planManager.weekWorkouts.first { !$0.workoutType.isRest }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("SMART STACK")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.tempoCyan)
                    .kerning(1.5)

                Text("Atalhos rápidos")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // 2×2 grid
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        // Semana
                        WidgetCard(
                            header: "SEMANA",
                            value: weekTotal > 0
                                ? "\(String(format: "%.0f", weekDone))/\(String(format: "%.0f", weekTotal))"
                                : "--",
                            sub: "km"
                        )

                        // Próximo
                        WidgetCard(
                            header: "PRÓXIMO",
                            value: nextWorkout.map { String(format: "%.0fk", $0.distancia_km) } ?? "--",
                            sub: nextWorkout?.tipo.components(separatedBy: " ").first?.lowercased() ?? "treino"
                        )
                    }

                    HStack(spacing: 6) {
                        // Streak (from saveResult if available, else "--")
                        WidgetCard(
                            header: "STREAK",
                            value: "--",
                            sub: "dias"
                        )

                        // XP
                        WidgetCard(
                            header: "XP",
                            value: "--",
                            sub: "total"
                        )
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Widget card

private struct WidgetCard: View {
    let header: String; let value: String; let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.tempoCyan)
                .kerning(0.8)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.tempoCard)
        .cornerRadius(12)
    }
}
