import SwiftUI
import CoreLocation

// MARK: - Home (Treino de hoje)

struct TodayWorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Brand
                Text("TEMPORUN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.tempoCyan)
                    .kerning(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Cartão do plano (se houver)
                if planManager.isLoadingPlan {
                    HomeLoadingView()
                } else if let workout = planManager.todayWorkout {
                    if workout.workoutType.isRest {
                        RestNote()
                    } else {
                        PlanCard(workout: workout)
                    }
                } else {
                    NoPlanNote()
                }

                // Aviso de GPS
                GPSNoticeBanner()

                // Seletor corrida / caminhada
                ActivitySelector(selection: $workoutManager.activityType)

                // Botão grande de iniciar
                StartActivityButton()
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Seletor de atividade

struct ActivitySelector: View {
    @Binding var selection: ActivityType

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ActivityType.allCases) { type in
                let isSelected = selection == type
                Button(action: { selection = type }) {
                    HStack(spacing: 5) {
                        Image(systemName: type.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(type.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .tempoCyan : .white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isSelected ? Color.tempoCard : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(isSelected ? Color.tempoCyan.opacity(0.7)
                                                             : Color.white.opacity(0.12),
                                                  lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Botão grande de iniciar

struct StartActivityButton: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        Button(action: {
            CrashReporter.beginAttempt()
            CrashReporter.breadcrumb("UI: tocou Iniciar atividade (\(workoutManager.activityType.dbValue))")
            Task {
                await workoutManager.requestAuthorization()
                workoutManager.startWorkout()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                Text("Iniciar atividade")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LinearGradient.tempoPurpleCyan)
            .cornerRadius(26)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cartão do plano

private struct PlanCard: View {
    let workout: DailyWorkout
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TREINO DE HOJE")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.tempoCyan.opacity(0.7))
                .kerning(1)

            Text(workout.tipo)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.tempoCyan)

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
            .foregroundColor(.white.opacity(0.5))

            if let obj = planManager.plan?.objetivo, !obj.isEmpty {
                Text(obj)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.tempoCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.tempoCyan.opacity(0.6), lineWidth: 1)
                )
        )
    }
}

private struct RestNote: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill").foregroundColor(.gray)
            Text("Descanso hoje — bora de caminhada leve?")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

private struct NoPlanNote: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 22)).foregroundColor(.gray)
            Text("Sem plano ativo")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("Crie um plano no iPhone — ou inicie uma atividade livre abaixo")
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: { planManager.requestPlanFromPhone() }) {
                Text("Sincronizar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - GPS notice banner

struct GPSNoticeBanner: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        switch workoutManager.locationStatus {
        case .notDetermined:
            banner(icon: "location.circle", color: .tempoCyan,
                   text: "Ative o GPS para rastrear sua atividade",
                   action: { workoutManager.requestLocationAuthorization() },
                   actionLabel: "Ativar GPS")
        case .denied, .restricted:
            banner(icon: "location.slash.fill", color: .red,
                   text: "GPS desativado. Ative em Ajustes › Privacidade › Localização",
                   action: nil, actionLabel: nil)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func banner(icon: String, color: Color, text: String,
                        action: (() -> Void)?, actionLabel: String?) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(text)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action, let actionLabel {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.25))
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(color.opacity(0.12))
        .cornerRadius(12)
    }
}

// MARK: - Loading

private struct HomeLoadingView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView().tint(.tempoCyan)
            Text("Carregando plano...")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
