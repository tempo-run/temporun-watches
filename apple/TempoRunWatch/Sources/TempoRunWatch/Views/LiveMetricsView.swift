import SwiftUI

struct LiveMetricsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 4) {
            // Duração
            Text(workoutManager.elapsedTime.formattedDuration)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Divider().background(Color.gray.opacity(0.4))

            // Distância e Pace
            HStack(spacing: 0) {
                MetricCell(
                    value: workoutManager.distanceKm.formattedDistance,
                    unit: "km",
                    color: Color.tempoOrange
                )
                Divider().background(Color.gray.opacity(0.4)).frame(height: 36)
                MetricCell(
                    value: workoutManager.currentPace.formattedPace,
                    unit: "/km",
                    color: .white
                )
            }

            Divider().background(Color.gray.opacity(0.4))

            // FC
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
                Text("\(workoutManager.heartRate, specifier: "%.0f")")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("bpm")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Divider().background(Color.gray.opacity(0.4))

            // Controles
            HStack(spacing: 12) {
                Button(action: { workoutManager.togglePause() }) {
                    Image(systemName: workoutManager.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: { workoutManager.endWorkout() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct MetricCell: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
