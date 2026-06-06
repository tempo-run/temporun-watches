import SwiftUI

struct LiveMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        TabView {
            PrimaryPage()
            BiomechanicsPage()
            EnergyPage()
            CardioPage()
            AltitudePage()
            SplitsPage()
            PredictionsPage()
            ControlsPage()
        }
        .tabViewStyle(.page)
        .environmentObject(workoutManager)
    }
}

// MARK: - Página 1: Primárias

private struct PrimaryPage: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        VStack(spacing: 3) {
            // Tempo
            Text(wm.elapsedTime.formattedDuration)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white).monospacedDigit()

            divider()

            // Distância | Pace
            HStack(spacing: 0) {
                MetricCell(value: wm.metrics.distanceKm.formattedDistance, unit: "km", color: .tempoOrange)
                Divider().background(Color.gray.opacity(0.3)).frame(height: 32)
                MetricCell(value: wm.metrics.currentPace.formattedPace, unit: "/km")
            }

            divider()

            // FC + zona
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").foregroundColor(zoneColor(wm.metrics.currentZone)).font(.system(size: 12))
                Text("\(wm.metrics.heartRate, specifier: "%.0f")")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white).monospacedDigit()
                Text("bpm")
                    .font(.system(size: 11)).foregroundColor(.gray)
                ZoneBadge(zone: wm.metrics.currentZone)
            }

            divider()

            // Pace médio | Passos
            HStack(spacing: 0) {
                MetricCell(value: wm.metrics.averagePace.formattedPace, unit: "médio")
                Divider().background(Color.gray.opacity(0.3)).frame(height: 28)
                MetricCell(value: "\(wm.metrics.cadence, specifier: "%.0f")", unit: "spm")
            }
        }
        .padding(.horizontal, 6)
    }
}

// MARK: - Página 2: Biomecânica

private struct BiomechanicsPage: View {
    @EnvironmentObject var wm: WorkoutManager
    private var m: LiveMetrics { wm.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                pageTitle("Biomecânica")
                Row(icon: "bolt.fill",              label: "Potência",        value: "\(m.runningPower, specifier: "%.0f") W",  color: .tempoOrange)
                Row(icon: "arrow.left.and.right",   label: "Passada",         value: "\(m.strideLength, specifier: "%.2f") m")
                Row(icon: "timer",                  label: "Contato solo",    value: "\(m.groundContactTime, specifier: "%.0f") ms")
                Row(icon: "arrow.up.and.down",      label: "Oscilação vert.", value: "\(m.verticalOscillation, specifier: "%.1f") cm")
                Row(icon: "percent",                label: "Vert. Ratio",     value: "\(m.verticalRatio, specifier: "%.1f") %", color: .tempoOrange)
                Row(icon: "shoeprints.fill",        label: "Cadência",        value: "\(m.cadence, specifier: "%.0f") spm")
                Row(icon: "figure.run",             label: "Passos",          value: "\(m.stepCount, specifier: "%.0f")")
                Row(icon: "gauge.medium",           label: "Esforço",         value: "\(m.physicalEffort, specifier: "%.1f") MET")
                Row(icon: "speedometer",            label: "Velocidade",      value: "\(m.currentSpeed, specifier: "%.1f") m/s")
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Página 3: Energia

private struct EnergyPage: View {
    @EnvironmentObject var wm: WorkoutManager
    private var m: LiveMetrics { wm.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                pageTitle("Energia")
                Row(icon: "flame.fill",   label: "Ativa",    value: "\(m.activeEnergyBurned, specifier: "%.0f") kcal", color: .tempoOrange)
                Row(icon: "flame",        label: "Basal",    value: "\(m.basalEnergyBurned, specifier: "%.0f") kcal")
                Row(icon: "sum",          label: "Total",    value: "\(m.totalEnergyBurned, specifier: "%.0f") kcal",   color: .yellow)
                divider()
                // Zonas de FC — tempo acumulado
                pageTitle("Tempo em zonas")
                ForEach(1...5, id: \.self) { z in
                    ZoneTimeRow(zone: z, seconds: m.timeInZone[z])
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Página 4: Cardio & Saúde

private struct CardioPage: View {
    @EnvironmentObject var wm: WorkoutManager
    private var m: LiveMetrics { wm.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                pageTitle("Cardio & Saúde")
                Row(icon: "heart.fill",         label: "FC atual",    value: "\(m.heartRate, specifier: "%.0f") bpm",         color: zoneColor(m.currentZone))
                Row(icon: "heart.circle",       label: "FC média",    value: "\(m.averageHeartRate, specifier: "%.0f") bpm")
                Row(icon: "arrow.down.heart",   label: "FC mín",      value: "\(m.minHeartRate == 999 ? 0 : m.minHeartRate, specifier: "%.0f") bpm", color: .blue)
                Row(icon: "arrow.up.heart",     label: "FC máx",      value: "\(m.maxHeartRate, specifier: "%.0f") bpm",      color: .red)
                Row(icon: "heart.text.square",  label: "FC repouso",  value: "\(m.restingHeartRate, specifier: "%.0f") bpm")
                Row(icon: "waveform.path.ecg",  label: "HRV (SDNN)",  value: "\(m.heartRateVariability, specifier: "%.1f") ms", color: .tempoOrange)
                Row(icon: "lungs.fill",         label: "SpO₂",        value: "\(m.oxygenSaturation, specifier: "%.0f") %",   color: .blue)
                Row(icon: "wind",               label: "Respiração",   value: "\(m.respiratoryRate, specifier: "%.0f") r/min")
                Row(icon: "chart.bar.fill",     label: "VO₂ máx",     value: "\(m.vo2Max, specifier: "%.1f") ml/kg", color: .green)
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Página 5: Altitude / GPS

private struct AltitudePage: View {
    @EnvironmentObject var wm: WorkoutManager
    private var m: LiveMetrics { wm.metrics }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                pageTitle("Altitude & GPS")
                Row(icon: "location.fill",      label: "Altitude atual",  value: "\(m.currentAltitude, specifier: "%.0f") m",  color: .tempoOrange)
                Row(icon: "arrow.up.right",     label: "Ganho elev.",     value: "+ \(m.elevationGain, specifier: "%.0f") m",  color: .green)
                Row(icon: "arrow.down.right",   label: "Perda elev.",     value: "- \(m.elevationLoss, specifier: "%.0f") m",  color: .red)
                Row(icon: "mountain.2.fill",    label: "Altitude máx",    value: "\(m.maxAltitude, specifier: "%.0f") m")
                Row(icon: "arrow.down.to.line", label: "Altitude mín",    value: "\(m.minAltitude == 9999 ? 0 : m.minAltitude, specifier: "%.0f") m")
                Row(icon: "stairs",             label: "Lances subidos",  value: "\(m.flightsClimbed, specifier: "%.0f")")
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Página 6: Splits

private struct SplitsPage: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                pageTitle("Splits")

                if wm.metrics.splits.isEmpty {
                    Text("Primeiro split\naos 1 km")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                } else {
                    // Cabeçalho
                    HStack {
                        Text("km").frame(width: 24, alignment: .leading)
                        Text("pace").frame(maxWidth: .infinity, alignment: .center)
                        Text("FC").frame(width: 40, alignment: .trailing)
                    }
                    .font(.system(size: 10)).foregroundColor(.gray)

                    ForEach(wm.metrics.splits, id: \.km) { split in
                        SplitRow(split: split, bestPace: wm.metrics.bestPace)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct SplitRow: View {
    let split: KmSplit
    let bestPace: Double

    var body: some View {
        let isBest = split.pace == bestPace
        HStack {
            Text("\(split.km)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)
                .frame(width: 24, alignment: .leading)

            Text(split.pace.formattedPace)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isBest ? .tempoOrange : .white)
                .frame(maxWidth: .infinity, alignment: .center)
                .monospacedDigit()

            Text(split.avgHeartRate > 0 ? "\(split.avgHeartRate, specifier: "%.0f")" : "--")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.red)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Página 7: Predições de prova

private struct PredictionsPage: View {
    @EnvironmentObject var wm: WorkoutManager
    private var p: RacePredictions { wm.metrics.racePredictions }

    var body: some View {
        VStack(spacing: 6) {
            pageTitle("Predição de prova")

            if wm.metrics.vo2Max == 0 {
                Text("Disponível após\nleitura do VO₂ máx")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            } else {
                VStack(spacing: 5) {
                    PredRow(label: "5 km",        time: p.km5)
                    PredRow(label: "10 km",       time: p.km10)
                    PredRow(label: "Meia",        time: p.halfMarathon)
                    PredRow(label: "Maratona",    time: p.marathon)
                }
                Text("Baseado no VO₂ máx · Daniels")
                    .font(.system(size: 9)).foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct PredRow: View {
    let label: String
    let time: TimeInterval

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .rounded)).foregroundColor(.gray)
            Spacer()
            Text(time.formattedRaceTime)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.tempoOrange).monospacedDigit()
        }
    }
}

// MARK: - Página 8: Controles

private struct ControlsPage: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { wm.togglePause() }) {
                Label(wm.state == .paused ? "Continuar" : "Pausar",
                      systemImage: wm.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.gray.opacity(0.35)).cornerRadius(24)
            }.buttonStyle(.plain)

            Button(action: { wm.endWorkout() }) {
                Label("Encerrar", systemImage: "stop.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.red.opacity(0.75)).cornerRadius(24)
            }.buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Subviews reutilizáveis

private struct MetricCell: View {
    let value: String; let unit: String; var color: Color = .white
    var body: some View {
        VStack(spacing: 0) {
            Text(value).font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(color).monospacedDigit()
            Text(unit).font(.system(size: 10)).foregroundColor(.gray)
        }.frame(maxWidth: .infinity)
    }
}

private struct Row: View {
    let icon: String; let label: String; let value: String; var color: Color = .white
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(color).frame(width: 16).font(.system(size: 12))
            Text(label).font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white).monospacedDigit()
        }
    }
}

private struct ZoneBadge: View {
    let zone: Int
    var body: some View {
        Text("Z\(zone)")
            .font(.system(size: 10, weight: .bold)).foregroundColor(.black)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(zoneColor(zone)).cornerRadius(8)
    }
}

private struct ZoneTimeRow: View {
    let zone: Int; let seconds: Double
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(zoneColor(zone)).frame(width: 8, height: 8)
            Text("Z\(zone) · \(zoneName(zone))")
                .font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
            Spacer()
            Text(seconds.formattedDuration)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white).monospacedDigit()
        }
    }
}

// MARK: - Helpers

private func pageTitle(_ t: String) -> some View {
    Text(t).font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(.tempoOrange).padding(.bottom, 2)
}

private func divider() -> some View {
    Divider().background(Color.gray.opacity(0.3))
}

func zoneColor(_ zone: Int) -> Color {
    switch zone {
    case 1: return .blue
    case 2: return .green
    case 3: return .yellow
    case 4: return .tempoOrange
    case 5: return .red
    default: return .gray
    }
}

private func zoneName(_ zone: Int) -> String {
    ["—", "Recuperação", "Base aeróbica", "Tempo", "Limiar", "VO₂ máx"][zone]
}
