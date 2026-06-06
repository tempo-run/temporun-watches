import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.tempoOrange)

                Text("Corrida salva!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    SummaryRow(
                        icon: "figure.run",
                        label: "Distância",
                        value: workoutManager.distanceKm.formattedDistance + " km"
                    )
                    SummaryRow(
                        icon: "clock",
                        label: "Tempo",
                        value: workoutManager.elapsedTime.formattedDuration
                    )
                    SummaryRow(
                        icon: "speedometer",
                        label: "Pace médio",
                        value: workoutManager.averagePace.formattedPace + "/km"
                    )
                    SummaryRow(
                        icon: "heart.fill",
                        label: "FC média",
                        value: "\(workoutManager.averageHeartRate, specifier: "%.0f") bpm"
                    )
                }

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
            .padding()
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.tempoOrange)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
