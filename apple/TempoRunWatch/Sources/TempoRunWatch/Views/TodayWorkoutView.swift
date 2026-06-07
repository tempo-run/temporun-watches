import SwiftUI

// MARK: - Home (Treino de hoje)

struct TodayWorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        if planManager.isLoadingPlan {
            HomeLoadingView()
        } else if let workout = planManager.todayWorkout {
            HomeWorkoutCard(workout: workout)
        } else {
            HomeNoPlanView()
        }
    }
}

// MARK: - Gradient card

private struct HomeWorkoutCard: View {
    let workout: DailyWorkout
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Brand label
                Text("TEMPORUN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.tempoCyan)
                    .kerning(1.5)

                // Screen title
                Text(workout.workoutType.isRest ? "Descanso hoje" : "Treino de hoje")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Description
                if !workout.descricao.isEmpty {
                    Text(workout.descricao)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(2)
                }

                // Gradient workout card
                if !workout.workoutType.isRest {
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.tempoGradient)

                        VStack(alignment: .leading, spacing: 4) {
                            // Objective tag
                            if let obj = planManager.plan?.objetivo, !obj.isEmpty {
                                Text(obj)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            // Workout name
                            Text(workout.tipo)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            // Distance · Pace · Week
                            HStack(spacing: 4) {
                                Text(String(format: "%.0f km", workout.distancia_km))
                                Text("·")
                                Text(workout.pace_alvo.replacingOccurrences(of: "/km", with: "") + "/km")
                                if let wk = planManager.plan?.currentWeek {
                                    Text("·")
                                    Text("Sem \(wk.semana)/\(planManager.plan?.semanas.count ?? 0)")
                                }
                            }
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(10)
                    }
                    .frame(minHeight: 70)
                }

                // Action button
                if workout.workoutType.isRest {
                    HStack {
                        Image(systemName: "moon.zzz.fill").foregroundColor(.gray)
                        Text("Dia de descanso")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    Button(action: { workoutManager.startWorkout() }) {
                        Text("Iniciar corrida")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(LinearGradient.tempoPurpleCyan)
                            .cornerRadius(24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Loading / No plan

private struct HomeLoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.tempoCyan)
            Text("Carregando plano...")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)
        }
    }
}

private struct HomeNoPlanView: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        VStack(spacing: 10) {
            Text("TEMPORUN")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.tempoCyan)
                .kerning(1.5)
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 26)).foregroundColor(.gray)
            Text("Sem plano ativo")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("Crie um plano no app do iPhone")
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: { planManager.requestPlanFromPhone() }) {
                Text("Sincronizar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(LinearGradient.tempoPurpleCyan)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
