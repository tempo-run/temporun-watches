import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.metrics }
    private var result: WatchSaveResult? { workoutManager.saveResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // ── Hero card ──────────────────────────────────────────────
                VStack(spacing: 6) {
                    // Lightning icon
                    ZStack {
                        Circle()
                            .fill(Color.tempoOrange.opacity(0.25))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.tempoOrange)
                    }

                    Text("RUN COMPLETE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.tempoCyan)
                        .kerning(1.5)

                    Text("Boa corrida!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if let result, !result.is_duplicate {
                        Text("Você manteve consistência e fechou dentro da zona.")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 4)

                // ── Primary stats row ──────────────────────────────────────
                HStack(spacing: 0) {
                    SummaryStatCell(
                        value: String(format: "%.1f", m.distanceKm),
                        label: "KM"
                    )
                    Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                    SummaryStatCell(
                        value: m.averagePace.formattedPace,
                        label: "PACE"
                    )
                    if let result {
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        SummaryStatCell(
                            value: "+\(result.xp_ganho)",
                            label: "XP",
                            color: .tempoOrange
                        )
                    }
                }
                .padding(.vertical, 6)
                .background(Color.tempoCard)
                .cornerRadius(12)

                // ── Streak pill ────────────────────────────────────────────
                if let result {
                    VStack(spacing: 3) {
                        Text("Streak \(result.streak_atual) dias")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.tempoCyan)
                            .padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Color.tempoCyan.opacity(0.15))
                            .cornerRadius(20)

                        if !result.novos_recordes.isEmpty {
                            Text("Novos recordes pessoais! 🏆")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.yellow)
                        }
                    }
                }

                divider()

                // ── Detailed metrics ───────────────────────────────────────
                group("Corrida") {
                    SRow(icon: "clock",       label: "Tempo",       value: workoutManager.elapsedTime.formattedDuration)
                    SRow(icon: "speedometer", label: "Pace médio",  value: m.averagePace.formattedPace + "/km")
                    SRow(icon: "speedometer", label: "Melhor pace", value: m.bestPace.formattedPace + "/km", color: .tempoCyan)
                }

                divider()

                group("Cardio") {
                    SRow(icon: "heart.fill",        label: "FC média",  value: "\(m.averageHeartRate, default: "%.0f") bpm", color: .red)
                    SRow(icon: "arrow.up.heart",    label: "FC máx",    value: "\(m.maxHeartRate, default: "%.0f") bpm")
                    SRow(icon: "chart.bar.fill",    label: "VO₂ máx",   value: "\(m.vo2Max, default: "%.1f") ml/kg", color: .tempoCyan)
                }

                divider()

                group("Biomecânica") {
                    SRow(icon: "bolt.fill",            label: "Potência",  value: "\(m.runningPower, default: "%.0f") W",  color: .tempoOrange)
                    SRow(icon: "shoeprints.fill",      label: "Cadência",  value: "\(m.cadence, default: "%.0f") spm")
                    SRow(icon: "timer",                label: "GCT",       value: "\(m.groundContactTime, default: "%.0f") ms")
                    SRow(icon: "arrow.left.and.right", label: "Passada",   value: "\(m.strideLength, default: "%.2f") m")
                }

                divider()

                group("Energia") {
                    SRow(icon: "flame.fill", label: "Kcal ativas", value: "\(m.activeEnergyBurned, default: "%.0f") kcal", color: .tempoOrange)
                }

                if m.vo2Max > 0 {
                    divider()
                    group("Predição · Daniels") {
                        SRow(icon: "flag.fill", label: "5 km",    value: m.racePredictions.km5.formattedRaceTime,          color: .tempoOrange)
                        SRow(icon: "flag.fill", label: "10 km",   value: m.racePredictions.km10.formattedRaceTime)
                        SRow(icon: "flag.fill", label: "Meia",    value: m.racePredictions.halfMarathon.formattedRaceTime)
                        SRow(icon: "flag.fill", label: "Maratona",value: m.racePredictions.marathon.formattedRaceTime)
                    }
                }

                if let result, !result.novos_recordes.isEmpty {
                    divider()
                    group("Recordes pessoais") {
                        ForEach(result.novos_recordes, id: \.distancia) { pr in
                            SRow(icon: "trophy.fill", label: "PR \(pr.distancia)",
                                 value: pr.tempo_novo.formattedDuration, color: .yellow)
                        }
                    }
                }

                divider()

                Button(action: { workoutManager.resetWorkout() }) {
                    Text("Nova corrida")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(LinearGradient.tempoPurpleCyan)
                        .cornerRadius(24)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Subviews

private struct SummaryStatCell: View {
    let value: String; let label: String; var color: Color = .white
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color).monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.gray).kerning(0.5)
        }
        .frame(maxWidth: .infinity)
    }
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

@ViewBuilder
private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 4) {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(.tempoCyan)
            .frame(maxWidth: .infinity, alignment: .leading)
        content()
    }
}

private func divider() -> some View {
    Divider().background(Color.white.opacity(0.08))
}
