import SwiftUI

// Navegação via TabView paginado — padrão watchOS para múltiplas telas ao vivo
struct LiveMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        TabView {
            PrimaryMetricsPage()
            BiomechanicsPage()
            EnergyPage()
            CardioPage()
            ControlsPage()
        }
        .tabViewStyle(.page)
        .environmentObject(workoutManager)
    }
}

// MARK: - Página 1: Métricas primárias (distância, pace, FC, tempo)

private struct PrimaryMetricsPage: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 4) {
            Text(workoutManager.elapsedTime.formattedDuration)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Divider().background(Color.gray.opacity(0.3))

            HStack(spacing: 0) {
                MetricCell(value: workoutManager.metrics.distanceKm.formattedDistance,
                           unit: "km",
                           color: .tempoOrange)
                Divider().background(Color.gray.opacity(0.3)).frame(height: 34)
                MetricCell(value: workoutManager.metrics.currentPace.formattedPace,
                           unit: "/km",
                           color: .white)
            }

            Divider().background(Color.gray.opacity(0.3))

            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundColor(.red).font(.system(size: 13))
                Text("\(workoutManager.metrics.heartRate, specifier: "%.0f") bpm")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            // Indicador de página
            pageIndicator(current: 0, total: 4)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Página 2: Biomecânica (cadência, passada, potência, contato, oscilação)

private struct BiomechanicsPage: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                pageTitle("Biomecânica")

                BiometricRow(icon: "figure.run",
                             label: "Cadência",
                             value: "\(m.cadence, specifier: "%.0f") spm")

                BiometricRow(icon: "arrow.left.and.right",
                             label: "Passada",
                             value: "\(m.strideLength, specifier: "%.2f") m")

                BiometricRow(icon: "bolt.fill",
                             label: "Potência",
                             value: "\(m.runningPower, specifier: "%.0f") W",
                             color: .tempoOrange)

                BiometricRow(icon: "timer",
                             label: "Contato solo",
                             value: "\(m.groundContactTime, specifier: "%.0f") ms")

                BiometricRow(icon: "arrow.up.and.down",
                             label: "Oscilação",
                             value: "\(m.verticalOscillation, specifier: "%.1f") cm")

                BiometricRow(icon: "mountain.2.fill",
                             label: "Ganho elev.",
                             value: "\(m.elevationGain, specifier: "%.0f") m")

                BiometricRow(icon: "stairs",
                             label: "Lances",
                             value: "\(m.flightsClimbed, specifier: "%.0f")")
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Página 3: Energia

private struct EnergyPage: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }

    var body: some View {
        VStack(spacing: 8) {
            pageTitle("Energia")

            VStack(spacing: 6) {
                EnergyBar(label: "Ativa",
                          value: m.activeEnergyBurned,
                          color: .tempoOrange)

                EnergyBar(label: "Basal",
                          value: m.basalEnergyBurned,
                          color: .yellow.opacity(0.8))

                Divider().background(Color.gray.opacity(0.3))

                HStack {
                    Text("Total")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(m.totalEnergyBurned, specifier: "%.0f") kcal")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                BiometricRow(icon: "shoeprints.fill",
                             label: "Passos",
                             value: "\(m.stepCount, specifier: "%.0f")")
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Página 4: Cardio + SpO2 + HRV

private struct CardioPage: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                pageTitle("Cardio & Saúde")

                BiometricRow(icon: "heart.fill",
                             label: "FC atual",
                             value: "\(m.heartRate, specifier: "%.0f") bpm",
                             color: .red)

                BiometricRow(icon: "heart.circle",
                             label: "FC média",
                             value: "\(m.averageHeartRate, specifier: "%.0f") bpm")

                BiometricRow(icon: "heart.text.square",
                             label: "FC repouso",
                             value: "\(m.restingHeartRate, specifier: "%.0f") bpm")

                BiometricRow(icon: "waveform.path.ecg",
                             label: "HRV (SDNN)",
                             value: "\(m.heartRateVariability, specifier: "%.1f") ms",
                             color: .tempoOrange)

                BiometricRow(icon: "lungs.fill",
                             label: "SpO₂",
                             value: "\(m.oxygenSaturation, specifier: "%.0f")%",
                             color: .blue)

                BiometricRow(icon: "wind",
                             label: "Respiração",
                             value: "\(m.respiratoryRate, specifier: "%.0f") r/min")

                BiometricRow(icon: "chart.bar.fill",
                             label: "VO₂ máx",
                             value: "\(m.vo2Max, specifier: "%.1f")",
                             color: .green)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Página 5: Controles

private struct ControlsPage: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 14) {
            Button(action: { workoutManager.togglePause() }) {
                Label(
                    workoutManager.state == .paused ? "Continuar" : "Pausar",
                    systemImage: workoutManager.state == .paused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.35))
                .cornerRadius(24)
            }
            .buttonStyle(.plain)

            Button(action: { workoutManager.endWorkout() }) {
                Label("Encerrar", systemImage: "stop.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.75))
                    .cornerRadius(24)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Subviews reutilizáveis

private struct MetricCell: View {
    let value: String
    let unit: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BiometricRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 18)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }
}

private struct EnergyBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.gray)
            Spacer()
            Text("\(value, specifier: "%.0f") kcal")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

private func pageTitle(_ title: String) -> some View {
    Text(title)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundColor(.tempoOrange)
        .padding(.bottom, 2)
}

private func pageIndicator(current: Int, total: Int) -> some View {
    HStack(spacing: 4) {
        ForEach(0..<total, id: \.self) { i in
            Circle()
                .fill(i == current ? Color.tempoOrange : Color.gray.opacity(0.4))
                .frame(width: 5, height: 5)
        }
    }
    .padding(.top, 2)
}
