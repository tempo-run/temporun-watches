import SwiftUI

// MARK: - Métricas personalizáveis

enum WatchMetric: String, CaseIterable, Identifiable {
    // Biomecânica
    case cadence            = "cadence"
    case power              = "power"
    case groundContactTime  = "groundContactTime"
    case strideLength       = "strideLength"
    case verticalOscillation = "verticalOscillation"
    // Cardíaco
    case heartRate          = "heartRate"
    case heartRateZone      = "heartRateZone"
    case avgHeartRate       = "avgHeartRate"
    case maxHeartRate       = "maxHeartRate"
    case hrv                = "hrv"
    // Energia / Altitude
    case activeKcal         = "activeKcal"
    case altitude           = "altitude"
    case elevationGain      = "elevationGain"
    // VO₂ / Forma
    case vo2Max             = "vo2Max"
    case physicalEffort     = "physicalEffort"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cadence:              return "Cadência"
        case .power:                return "Potência"
        case .groundContactTime:    return "Contato solo"
        case .strideLength:         return "Passada"
        case .verticalOscillation:  return "Oscilação vert."
        case .heartRate:            return "FC atual"
        case .heartRateZone:        return "Zona FC"
        case .avgHeartRate:         return "FC média"
        case .maxHeartRate:         return "FC máxima"
        case .hrv:                  return "HRV"
        case .activeKcal:           return "Kcal ativas"
        case .altitude:             return "Altitude"
        case .elevationGain:        return "Ganho de alt."
        case .vo2Max:               return "VO₂ máx"
        case .physicalEffort:       return "Esforço"
        }
    }

    var icon: String {
        switch self {
        case .cadence:              return "shoeprints.fill"
        case .power:                return "bolt.fill"
        case .groundContactTime:    return "timer"
        case .strideLength:         return "arrow.left.and.right"
        case .verticalOscillation:  return "arrow.up.and.down"
        case .heartRate:            return "heart.fill"
        case .heartRateZone:        return "heart.circle.fill"
        case .avgHeartRate:         return "heart.circle"
        case .maxHeartRate:         return "arrow.up.heart"
        case .hrv:                  return "waveform.path.ecg"
        case .activeKcal:           return "flame.fill"
        case .altitude:             return "location.fill"
        case .elevationGain:        return "arrow.up.right"
        case .vo2Max:               return "chart.bar.fill"
        case .physicalEffort:       return "gauge.medium"
        }
    }

    var accentColor: Color {
        switch self {
        case .cadence, .strideLength:   return .white
        case .power:                    return .tempoOrange
        case .groundContactTime:        return .white
        case .verticalOscillation:      return .white
        case .heartRate, .maxHeartRate: return .red
        case .heartRateZone:            return .yellow
        case .avgHeartRate:             return .red
        case .hrv:                      return .tempoOrange
        case .activeKcal:               return .tempoOrange
        case .altitude, .elevationGain: return .green
        case .vo2Max:                   return .tempoCyan
        case .physicalEffort:           return .white
        }
    }

    func value(from m: LiveMetrics) -> String {
        switch self {
        case .cadence:              return m.cadence > 0          ? "\(Int(m.cadence)) spm"          : "--"
        case .power:                return m.runningPower > 0     ? "\(Int(m.runningPower)) W"        : "--"
        case .groundContactTime:    return m.groundContactTime > 0 ? "\(Int(m.groundContactTime)) ms" : "--"
        case .strideLength:         return m.strideLength > 0     ? String(format: "%.2f m", m.strideLength) : "--"
        case .verticalOscillation:  return m.verticalOscillation > 0 ? String(format: "%.1f cm", m.verticalOscillation) : "--"
        case .heartRate:            return m.heartRate > 0        ? "\(Int(m.heartRate)) bpm"        : "--"
        case .heartRateZone:        return m.currentZone > 0      ? "Zona \(m.currentZone)"          : "--"
        case .avgHeartRate:         return m.averageHeartRate > 0 ? "\(Int(m.averageHeartRate)) bpm" : "--"
        case .maxHeartRate:         return m.maxHeartRate > 0     ? "\(Int(m.maxHeartRate)) bpm"     : "--"
        case .hrv:                  return m.heartRateVariability > 0 ? String(format: "%.1f ms", m.heartRateVariability) : "--"
        case .activeKcal:           return m.activeEnergyBurned > 0 ? "\(Int(m.activeEnergyBurned)) kcal" : "--"
        case .altitude:             return String(format: "%.0f m", m.currentAltitude)
        case .elevationGain:        return String(format: "+%.0f m", m.elevationGain)
        case .vo2Max:               return m.vo2Max > 0           ? String(format: "%.1f", m.vo2Max) : "--"
        case .physicalEffort:       return m.physicalEffort > 0   ? String(format: "%.1f MET", m.physicalEffort) : "--"
        }
    }
}

// MARK: - Preferências persistidas

final class MetricPreferences: ObservableObject {
    static let shared = MetricPreferences()
    private let key = "selectedWatchMetrics"
    static let defaultMetrics: [WatchMetric] = [.cadence, .heartRateZone, .power]
    static let maxSlots = 3

    @Published var selected: [WatchMetric] {
        didSet { save() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "selectedWatchMetrics") {
            let parsed = raw.components(separatedBy: ",").compactMap { WatchMetric(rawValue: $0) }
            selected = parsed.isEmpty ? Self.defaultMetrics : parsed
        } else {
            selected = Self.defaultMetrics
        }
    }

    private func save() {
        UserDefaults.standard.set(selected.map(\.rawValue).joined(separator: ","), forKey: key)
    }
}

// MARK: - LiveMetricsView

struct LiveMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager
    @StateObject private var prefs = MetricPreferences.shared

    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            ControlsPage()
                .tag(0)
            PrimaryPage()
                .tag(1)
        }
        .tabViewStyle(.page)
        .environmentObject(workoutManager)
        .environmentObject(planManager)
        .environmentObject(prefs)
        .onAppear { CrashReporter.breadcrumb("render: LiveMetricsView apareceu") }
    }
}

// MARK: - Página principal

private struct PrimaryPage: View {
    @EnvironmentObject var wm: WorkoutManager
    @EnvironmentObject var prefs: MetricPreferences

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Brand bar ──────────────────────────────
                HStack {
                    Text("tempo")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    + Text("run")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.tempoCyan)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(wm.gpsAcquired ? Color.tempoCyan : Color.orange)
                            .frame(width: 6, height: 6)
                            .shadow(color: wm.gpsAcquired ? .tempoCyan : .orange, radius: 4)
                        Text("GPS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(wm.gpsAcquired ? .tempoCyan : .orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

                // ── Big distance ───────────────────────────
                Text(String(format: "%.2f", wm.metrics.distanceKm))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("KM")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tempoCyan)
                    .kerning(3)
                    .padding(.bottom, 12)

                // ── PACE + TEMPO pills ─────────────────────
                HStack(spacing: 8) {
                    StatPill(value: wm.metrics.currentPace.formattedPace, label: "PACE")
                    StatPill(value: wm.elapsedTime.formattedDuration,     label: "TEMPO")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)

                // ── Métricas personalizáveis ───────────────
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.horizontal, 10)

                VStack(spacing: 6) {
                    Text("MÉTRICAS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .kerning(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    ForEach(prefs.selected) { metric in
                        MetricRow(metric: metric, metrics: wm.metrics)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            CrashReporter.breadcrumb("render: PrimaryPage apareceu")
            CrashReporter.endAttempt()
        }
    }
}

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.tempoCyan)
                .kerning(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(red: 0.48, green: 0.18, blue: 1.0).opacity(0.55), lineWidth: 1)
                )
        )
    }
}

private struct MetricRow: View {
    let metric: WatchMetric
    let metrics: LiveMetrics

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: metric.icon)
                .font(.system(size: 12))
                .foregroundColor(metric.accentColor)
                .frame(width: 18)
            Text(metric.displayName)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(metric.value(from: metrics))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(metric.accentColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(red: 0.05, green: 0.09, blue: 0.19))
        .cornerRadius(10)
        .padding(.horizontal, 10)
    }
}

// MARK: - Página de controles (swipe esquerda)

private struct ControlsPage: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        VStack(spacing: 14) {
            Text("CONTROLES")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
                .kerning(2)

            Button(action: { wm.togglePause() }) {
                Label(
                    wm.state == .paused ? "Continuar" : "Pausar",
                    systemImage: wm.state == .paused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.white.opacity(0.12))
                .cornerRadius(26)
            }
            .buttonStyle(.plain)

            Button(action: { wm.endWorkout() }) {
                Label("Encerrar", systemImage: "stop.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(LinearGradient.tempoPurpleCyan)
                    .cornerRadius(26)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Helpers

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
