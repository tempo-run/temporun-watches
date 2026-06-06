import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        switch workoutManager.state {
        case .idle:
            StartView()
        case .running, .paused:
            LiveMetricsView()
        case .ended:
            SummaryView()
        }
    }
}
