import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.tempoOrange)
                    Text("Corrida salva!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Sincronizando com o Health...")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                Divider().background(Color.gray.opacity(0.3))

                // Métricas principais
                Group {
                    SummaryRow(icon: "figure.run",     label: "Distância",
                               value: m.distanceKm.formattedDistance + " km",   color: .tempoOrange)
                    SummaryRow(icon: "clock",           label: "Tempo",
                               value: workoutManager.elapsedTime.formattedDuration)
                    SummaryRow(icon: "speedometer",     label: "Pace médio",
                               value: m.averagePace.formattedPace + "/km")
                    SummaryRow(icon: "heart.fill",      label: "FC média",
                               value: "\(m.averageHeartRate, specifier: "%.0f") bpm", color: .red)
                }

                Divider().background(Color.gray.opacity(0.3))

                // Biomecânica
                Group {
                    SummaryRow(icon: "figure.run",      label: "Cadência",
                               value: "\(m.cadence, specifier: "%.0f") spm")
                    SummaryRow(icon: "bolt.fill",        label: "Potência",
                               value: "\(m.runningPower, specifier: "%.0f") W", color: .tempoOrange)
                    SummaryRow(icon: "arrow.up.and.down", label: "Oscilação",
                               value: "\(m.verticalOscillation, specifier: "%.1f") cm")
                    SummaryRow(icon: "timer",            label: "Contato solo",
                               value: "\(m.groundContactTime, specifier: "%.0f") ms")
                    SummaryRow(icon: "arrow.left.and.right", label: "Passada",
                               value: "\(m.strideLength, specifier: "%.2f") m")
                }

                Divider().background(Color.gray.opacity(0.3))

                // Energia e outros
                Group {
                    SummaryRow(icon: "flame.fill",      label: "Energia ativa",
                               value: "\(m.activeEnergyBurned, specifier: "%.0f") kcal", color: .orange)
                    SummaryRow(icon: "flame",           label: "Total calorias",
                               value: "\(m.totalEnergyBurned, specifier: "%.0f") kcal")
                    SummaryRow(icon: "shoeprints.fill", label: "Passos",
                               value: "\(m.stepCount, specifier: "%.0f")")
                    SummaryRow(icon: "mountain.2.fill", label: "Ganho elev.",
                               value: "\(m.elevationGain, specifier: "%.0f") m")
                    SummaryRow(icon: "waveform.path.ecg", label: "HRV",
                               value: "\(m.heartRateVariability, specifier: "%.1f") ms")
                    SummaryRow(icon: "lungs.fill",      label: "SpO₂",
                               value: "\(m.oxygenSaturation, specifier: "%.0f")%", color: .blue)
                    SummaryRow(icon: "chart.bar.fill",  label: "VO₂ máx",
                               value: "\(m.vo2Max, specifier: "%.1f")", color: .green)
                }

                Divider().background(Color.gray.opacity(0.3))

                Button(action: { workoutManager.resetWorkout() }) {
                    Text("Nova corrida")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.tempoOrange)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 18)
                .font(.system(size: 12))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
}
