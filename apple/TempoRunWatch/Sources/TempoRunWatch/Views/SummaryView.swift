import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26)).foregroundColor(.tempoOrange)
                    Text("Corrida salva!")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Text("Sincronizando com o Health...")
                        .font(.system(size: 10)).foregroundColor(.gray)
                }

                divider()

                // Primárias
                group("Corrida") {
                    SRow(icon: "figure.run",     label: "Distância",    value: m.distanceKm.formattedDistance + " km",    color: .tempoOrange)
                    SRow(icon: "clock",          label: "Tempo",        value: workoutManager.elapsedTime.formattedDuration)
                    SRow(icon: "speedometer",    label: "Pace médio",   value: m.averagePace.formattedPace + "/km")
                    SRow(icon: "speedometer",    label: "Melhor pace",  value: m.bestPace.formattedPace + "/km",           color: .tempoOrange)
                    SRow(icon: "gauge.medium",   label: "Vel. média",   value: "\(m.currentSpeed, default: "%.1f") m/s")
                }

                divider()

                // Cardio
                group("Cardio") {
                    SRow(icon: "heart.fill",        label: "FC média",    value: "\(m.averageHeartRate, default: "%.0f") bpm", color: .red)
                    SRow(icon: "arrow.down.heart",  label: "FC mín",      value: "\(m.minHeartRate == 999 ? 0 : m.minHeartRate, default: "%.0f") bpm", color: .blue)
                    SRow(icon: "arrow.up.heart",    label: "FC máx",      value: "\(m.maxHeartRate, default: "%.0f") bpm", color: .red)
                    SRow(icon: "waveform.path.ecg", label: "HRV",         value: "\(m.heartRateVariability, default: "%.1f") ms", color: .tempoOrange)
                    SRow(icon: "lungs.fill",        label: "SpO₂",        value: "\(m.oxygenSaturation, default: "%.0f") %", color: .blue)
                    SRow(icon: "chart.bar.fill",    label: "VO₂ máx",     value: "\(m.vo2Max, default: "%.1f") ml/kg", color: .green)
                }

                divider()

                // Biomecânica
                group("Biomecânica") {
                    SRow(icon: "bolt.fill",             label: "Potência",        value: "\(m.runningPower, default: "%.0f") W", color: .tempoOrange)
                    SRow(icon: "shoeprints.fill",       label: "Cadência",        value: "\(m.cadence, default: "%.0f") spm")
                    SRow(icon: "arrow.left.and.right",  label: "Passada",         value: "\(m.strideLength, default: "%.2f") m")
                    SRow(icon: "arrow.up.and.down",     label: "Oscilação",       value: "\(m.verticalOscillation, default: "%.1f") cm")
                    SRow(icon: "percent",               label: "Vert. Ratio",     value: "\(m.verticalRatio, default: "%.1f") %")
                    SRow(icon: "timer",                 label: "Contato solo",    value: "\(m.groundContactTime, default: "%.0f") ms")
                    SRow(icon: "figure.run",            label: "Passos",          value: "\(m.stepCount, default: "%.0f")")
                }

                divider()

                // Energia
                group("Energia") {
                    SRow(icon: "flame.fill", label: "Energia ativa",  value: "\(m.activeEnergyBurned, default: "%.0f") kcal", color: .tempoOrange)
                    SRow(icon: "flame",      label: "Total calorias", value: "\(m.totalEnergyBurned, default: "%.0f") kcal")
                }

                divider()

                // Altitude
                group("Altitude") {
                    SRow(icon: "arrow.up.right",    label: "Ganho elev.",  value: "+ \(m.elevationGain, default: "%.0f") m",  color: .green)
                    SRow(icon: "arrow.down.right",  label: "Perda elev.",  value: "- \(m.elevationLoss, default: "%.0f") m",  color: .red)
                    SRow(icon: "mountain.2.fill",   label: "Alt. máxima",  value: "\(m.maxAltitude, default: "%.0f") m")
                    SRow(icon: "stairs",            label: "Lances",       value: "\(m.flightsClimbed, default: "%.0f")")
                }

                divider()

                // Predições
                if m.vo2Max > 0 {
                    group("Predição · Daniels") {
                        SRow(icon: "flag.fill", label: "5 km",      value: m.racePredictions.km5.formattedRaceTime,          color: .tempoOrange)
                        SRow(icon: "flag.fill", label: "10 km",     value: m.racePredictions.km10.formattedRaceTime)
                        SRow(icon: "flag.fill", label: "Meia",      value: m.racePredictions.halfMarathon.formattedRaceTime)
                        SRow(icon: "flag.fill", label: "Maratona",  value: m.racePredictions.marathon.formattedRaceTime)
                    }
                    divider()
                }

                // XP, streak e recordes (quando disponível via edge function)
                if let result = workoutManager.saveResult, !result.is_duplicate {
                    divider()
                    group("Conquistas") {
                        SRow(icon: "bolt.fill",  label: "XP ganho",
                             value: "+\(result.xp_ganho) XP",        color: .tempoOrange)
                        SRow(icon: "flame.fill", label: "Streak",
                             value: "\(result.streak_atual) dias",    color: .orange)
                        ForEach(result.novos_recordes, id: \.distancia) { pr in
                            SRow(icon: "trophy.fill", label: "PR \(pr.distancia)",
                                 value: pr.tempo_novo.formattedDuration, color: .yellow)
                        }
                    }
                    divider()
                }

                Button(action: { workoutManager.resetWorkout() }) {
                    Text("Nova corrida")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.black).frame(maxWidth: .infinity)
                        .padding(.vertical, 8).background(Color.tempoOrange).cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 6)
        }
    }
}

@ViewBuilder
private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 4) {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.tempoOrange)
            .frame(maxWidth: .infinity, alignment: .leading)
        content()
    }
}

private func divider() -> some View {
    Divider().background(Color.gray.opacity(0.3))
}

private struct SRow: View {
    let icon: String; let label: String; let value: String; var color: Color = .white
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).foregroundColor(color).frame(width: 16).font(.system(size: 11))
            Text(label).font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white).monospacedDigit()
        }
    }
}
