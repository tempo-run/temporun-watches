import SwiftUI

struct LiveMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            ControlsPage().tag(0)
            PrimaryPage().tag(1)
            BiomechanicsPage().tag(2)
            EnergyPage().tag(3)
            CardioPage().tag(4)
            AltitudePage().tag(5)
            SplitsPage().tag(6)
            PredictionsPage().tag(7)
        }
        .tabViewStyle(.page)
        .environmentObject(workoutManager)
        .environmentObject(planManager)
        .onAppear { CrashReporter.breadcrumb("render: LiveMetricsView apareceu") }
    }
}

// MARK: - Página 1: Live Run (redesenhada)

private struct PrimaryPage: View {
    @EnvironmentObject var wm: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager

    private var paceStatus: PaceStatus {
        guard let workout = planManager.todayWorkout,
              wm.metrics.currentPace > 0 else { return .ok }
        return workout.isPaceOnTarget(wm.metrics.currentPace)
    }

    private var statusLabel: String {
        switch paceStatus {
        case .ok:      return "Dentro do alvo"
        case .tooFast: return "Muito rápido"
        case .tooSlow: return "Muito lento"
        }
    }

    private var statusColor: Color {
        switch paceStatus {
        case .ok:      return .tempoCyan
        case .tooFast: return .yellow
        case .tooSlow: return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Top bar: elapsed + GPS
            HStack {
                Text(wm.elapsedTime.formattedDuration)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white).monospacedDigit()
                Spacer()
                HStack(spacing: 3) {
                    Circle()
                        .fill(wm.gpsAcquired ? Color.tempoCyan : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(wm.gpsAcquired ? "GPS" : "GPS...")
                        .font(.system(size: 10))
                        .foregroundColor(wm.gpsAcquired ? .tempoCyan : .orange)
                }
            }
            .padding(.horizontal, 10)

            // Live Run label
            Text("LIVE RUN")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.tempoCyan)
                .kerning(1.5)

            // Big distance
            Text(String(format: "%.2f", wm.metrics.distanceKm))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("KM")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.gray)
                .kerning(1)

            // 2×2 metric grid
            HStack(spacing: 6) {
                LiveCell(value: wm.metrics.currentPace.formattedPace, label: "PACE ATUAL",
                         color: .tempoPurple)
                Divider().background(Color.white.opacity(0.1)).frame(height: 32)
                LiveCell(value: "\(wm.metrics.heartRate, default: "%.0f")", label: "BPM")
            }
            .padding(.vertical, 4)
            .background(Color.tempoCard)
            .cornerRadius(10)
            .padding(.horizontal, 6)

            HStack(spacing: 6) {
                LiveCell(value: "\(wm.metrics.cadence, default: "%.0f")", label: "CADÊNCIA")
                Divider().background(Color.white.opacity(0.1)).frame(height: 32)
                LiveCell(value: wm.metrics.currentZone > 0 ? "Z\(wm.metrics.currentZone)" : "--",
                         label: "ZONA")
            }
            .padding(.vertical, 4)
            .background(Color.tempoCard)
            .cornerRadius(10)
            .padding(.horizontal, 6)

            // Status pill
            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(statusColor)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .cornerRadius(20)
        }
        .onAppear {
            CrashReporter.breadcrumb("render: PrimaryPage apareceu")
            // Chegamos à tela de corrida — tentativa bem-sucedida.
            CrashReporter.endAttempt()
        }
    }
}

private struct LiveCell: View {
    let value: String
    let label: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color).monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(.gray)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
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
                Row(icon: "bolt.fill",              label: "Potência",        value: "\(m.runningPower, default: "%.0f") W",  color: .tempoOrange)
                Row(icon: "arrow.left.and.right",   label: "Passada",         value: "\(m.strideLength, default: "%.2f") m")
                Row(icon: "timer",                  label: "Contato solo",    value: "\(m.groundContactTime, default: "%.0f") ms")
                Row(icon: "arrow.up.and.down",      label: "Oscilação vert.", value: "\(m.verticalOscillation, default: "%.1f") cm")
                Row(icon: "percent",                label: "Vert. Ratio",     value: "\(m.verticalRatio, default: "%.1f") %", color: .tempoOrange)
                Row(icon: "shoeprints.fill",        label: "Cadência",        value: "\(m.cadence, default: "%.0f") spm")
                Row(icon: "figure.run",             label: "Passos",          value: "\(m.stepCount, default: "%.0f")")
                Row(icon: "gauge.medium",           label: "Esforço",         value: "\(m.physicalEffort, default: "%.1f") MET")
                Row(icon: "speedometer",            label: "Velocidade",      value: "\(m.currentSpeed, default: "%.1f") m/s")
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
                Row(icon: "flame.fill",   label: "Ativa",    value: "\(m.activeEnergyBurned, default: "%.0f") kcal", color: .tempoOrange)
                Row(icon: "flame",        label: "Basal",    value: "\(m.basalEnergyBurned, default: "%.0f") kcal")
                Row(icon: "sum",          label: "Total",    value: "\(m.totalEnergyBurned, default: "%.0f") kcal",   color: .yellow)
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
                Row(icon: "heart.fill",         label: "FC atual",    value: "\(m.heartRate, default: "%.0f") bpm",         color: zoneColor(m.currentZone))
                Row(icon: "heart.circle",       label: "FC média",    value: "\(m.averageHeartRate, default: "%.0f") bpm")
                Row(icon: "arrow.down.heart",   label: "FC mín",      value: "\(m.minHeartRate == 999 ? 0 : m.minHeartRate, default: "%.0f") bpm", color: .blue)
                Row(icon: "arrow.up.heart",     label: "FC máx",      value: "\(m.maxHeartRate, default: "%.0f") bpm",      color: .red)
                Row(icon: "heart.text.square",  label: "FC repouso",  value: "\(m.restingHeartRate, default: "%.0f") bpm")
                Row(icon: "waveform.path.ecg",  label: "HRV (SDNN)",  value: "\(m.heartRateVariability, default: "%.1f") ms", color: .tempoOrange)
                Row(icon: "lungs.fill",         label: "SpO₂",        value: "\(m.oxygenSaturation, default: "%.0f") %",   color: .blue)
                Row(icon: "wind",               label: "Respiração",   value: "\(m.respiratoryRate, default: "%.0f") r/min")
                Row(icon: "chart.bar.fill",     label: "VO₂ máx",     value: "\(m.vo2Max, default: "%.1f") ml/kg", color: .green)
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
                Row(icon: "location.fill",      label: "Altitude atual",  value: "\(m.currentAltitude, default: "%.0f") m",  color: .tempoOrange)
                Row(icon: "arrow.up.right",     label: "Ganho elev.",     value: "+ \(m.elevationGain, default: "%.0f") m",  color: .green)
                Row(icon: "arrow.down.right",   label: "Perda elev.",     value: "- \(m.elevationLoss, default: "%.0f") m",  color: .red)
                Row(icon: "mountain.2.fill",    label: "Altitude máx",    value: "\(m.maxAltitude, default: "%.0f") m")
                Row(icon: "arrow.down.to.line", label: "Altitude mín",    value: "\(m.minAltitude == 9999 ? 0 : m.minAltitude, default: "%.0f") m")
                Row(icon: "stairs",             label: "Lances subidos",  value: "\(m.flightsClimbed, default: "%.0f")")
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

            Text(split.avgHeartRate > 0 ? "\(split.avgHeartRate, default: "%.0f")" : "--")
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
                    .background(LinearGradient.tempoPurpleCyan).cornerRadius(24)
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
