import SwiftUI

struct StartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundColor(Color.tempoOrange)

            Text("TempoRun")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Button(action: { workoutManager.startWorkout() }) {
                Text("Iniciar")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.tempoOrange)
                    .cornerRadius(24)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
