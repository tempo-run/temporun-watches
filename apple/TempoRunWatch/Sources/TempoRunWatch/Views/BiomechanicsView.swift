import SwiftUI

// MARK: - Biomecânica tab (idle — dados da última corrida)

struct BiomechanicsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    private var m: LiveMetrics { workoutManager.lastMetrics }

    private var hasData: Bool { m.cadence > 0 }

    // Normalized 0–100 scores
    private var cadenceScore: Double {
        min(100, max(0, (m.cadence - 130) / 70 * 100))
    }
    private var strideScore: Double {
        min(100, max(0, m.strideLength / 1.5 * 100))
    }
    private var gctScore: Double {
        min(100, max(0, (350 - m.groundContactTime) / 200 * 100))
    }
    private var vo2Score: Double {
        min(100, max(0, m.vo2Max / 60 * 100))
    }
    private var formScore: Int {
        Int((cadenceScore + strideScore + gctScore + vo2Score) / 4)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                Text("BIOMECHANICS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.tempoCyan)
                    .kerning(1.5)

                Text("Forma de corrida")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if hasData {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 6)
                            .frame(width: 70, height: 70)

                        Circle()
                            .trim(from: 0, to: CGFloat(formScore) / 100)
                            .stroke(
                                LinearGradient.tempoPurpleCyan,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 70, height: 70)

                        VStack(spacing: 0) {
                            Text("\(formScore)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("score")
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }

                    // Metric bars
                    VStack(spacing: 6) {
                        BiomecBar(label: "Cadência", score: cadenceScore,
                                  display: "\(m.cadence, default: "%.0f")")
                        BiomecBar(label: "Passada",  score: strideScore,
                                  display: "\(m.strideLength, default: "%.2f")m")
                        BiomecBar(label: "GCT",      score: gctScore,
                                  display: "\(m.groundContactTime, default: "%.0f")ms")
                        BiomecBar(label: "VO₂",      score: vo2Score,
                                  display: "\(m.vo2Max, default: "%.0f")")
                    }
                    .padding(.horizontal, 4)
                } else {
                    // No data state
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 32)).foregroundColor(.gray)
                        Text("Inicie uma corrida")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Os dados de forma aparecem\naqui após o treino.")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Metric bar

private struct BiomecBar: View {
    let label: String; let score: Double; let display: String

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient.tempoPurpleCyan)
                        .frame(width: geo.size.width * max(0, min(1, score / 100)))
                }
            }
            .frame(height: 6)

            Text(display)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 38, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
