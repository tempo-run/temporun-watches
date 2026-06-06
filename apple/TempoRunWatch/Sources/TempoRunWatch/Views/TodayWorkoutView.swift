import SwiftUI

// Tela principal quando o app abre e há um treino do dia
struct TodayWorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        if let workout = planManager.todayWorkout {
            WorkoutDetailView(workout: workout)
        } else if planManager.isLoadingPlan {
            LoadingPlanView()
        } else {
            NoPlanView()
        }
    }
}

// MARK: - Detalhe do treino do dia

struct WorkoutDetailView: View {
    let workout: DailyWorkout
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {

                // Header: ícone + tipo
                HStack(spacing: 6) {
                    Image(systemName: workout.workoutType.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundColor(intensityColor)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(workout.tipo)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(workout.dia)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Métricas-alvo
                if !workout.workoutType.isRest {
                    HStack(spacing: 0) {
                        TargetCell(label: "Distância",
                                   value: String(format: "%.1f", workout.distancia_km),
                                   unit: "km",
                                   color: intensityColor)
                        Divider().background(Color.gray.opacity(0.3)).frame(height: 30)
                        TargetCell(label: "Pace alvo",
                                   value: workout.pace_alvo.replacingOccurrences(of: "/km", with: ""),
                                   unit: "/km",
                                   color: .white)
                    }
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                }

                // Descrição
                Text(workout.descricao)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Detalhe (breakdown)
                if !workout.detalhe_treino.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estrutura")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.tempoOrange)
                        ForEach(workout.detalhe_treino.components(separatedBy: " - "), id: \.self) { block in
                            HStack(spacing: 4) {
                                Circle().fill(intensityColor).frame(width: 5, height: 5)
                                Text(block)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                }

                // Alerta de lesão
                if !workout.alerta_lesao.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow).font(.system(size: 11))
                        Text(workout.alerta_lesao)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(10)
                }

                // Botões
                if workout.workoutType.isRest {
                    Label("Dia de descanso", systemImage: "moon.zzz.fill")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                } else {
                    Button(action: { workoutManager.startWorkout() }) {
                        Label("Iniciar treino", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(intensityColor)
                            .cornerRadius(24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    private var intensityColor: Color {
        switch workout.workoutType.intensityColor {
        case .rest:     return .gray
        case .easy:     return .green
        case .moderate: return .tempoOrange
        case .hard:     return .red
        }
    }
}

// MARK: - Semana completa

struct WeekPlanView: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                Text("Esta semana")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.tempoOrange)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if planManager.weekWorkouts.isEmpty {
                    Text("Nenhum plano carregado")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                } else {
                    ForEach(planManager.weekWorkouts) { day in
                        WeekDayRow(workout: day)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

private struct WeekDayRow: View {
    let workout: DailyWorkout

    private var isToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let names = ["Domingo","Segunda","Terça","Quarta","Quinta","Sexta","Sábado"]
        return names[weekday - 1] == workout.dia
    }

    private var intensityColor: Color {
        switch workout.workoutType.intensityColor {
        case .rest:     return .gray
        case .easy:     return .green
        case .moderate: return .tempoOrange
        case .hard:     return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Indicador de dia
            VStack(spacing: 1) {
                Text(workout.dia.prefix(3))
                    .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundColor(isToday ? .tempoOrange : .gray)
                if isToday {
                    Circle().fill(Color.tempoOrange).frame(width: 4, height: 4)
                }
            }
            .frame(width: 30)

            // Ícone de tipo
            Image(systemName: workout.workoutType.sfSymbol)
                .foregroundColor(intensityColor)
                .font(.system(size: 13))
                .frame(width: 18)

            // Tipo + distância
            VStack(alignment: .leading, spacing: 1) {
                Text(workout.tipo)
                    .font(.system(size: 11, weight: isToday ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isToday ? .white : .gray)
                if !workout.workoutType.isRest {
                    Text("\(String(format: "%.1f", workout.distancia_km)) km · \(workout.pace_alvo)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isToday ? Color.white.opacity(0.08) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - States auxiliares

private struct LoadingPlanView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.tempoOrange)
            Text("Carregando plano...")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.gray)
        }
    }
}

private struct NoPlanView: View {
    @EnvironmentObject var planManager: TrainingPlanManager

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28)).foregroundColor(.gray)
            Text("Sem plano ativo")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("Crie um plano no app do iPhone")
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: { planManager.requestPlanFromPhone() }) {
                Text("Sincronizar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.tempoOrange)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Cell reutilizável

private struct TargetCell: View {
    let label: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color).monospacedDigit()
            Text(unit)
                .font(.system(size: 9)).foregroundColor(.gray)
            Text(label)
                .font(.system(size: 9)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
