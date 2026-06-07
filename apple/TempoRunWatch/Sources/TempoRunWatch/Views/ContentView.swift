import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager
    @State private var showPaceAlert = false

    var body: some View {
        ZStack {
            mainContent

            if let alert = planManager.paceAlert, showPaceAlert,
               workoutManager.state == .running {
                PaceAlertOverlay(alert: alert, visible: $showPaceAlert)
                    .padding(6)
            }
        }
        .onChange(of: planManager.paceAlert) { alert in
            if alert != nil {
                withAnimation { showPaceAlert = true }
            }
        }
        .onChange(of: workoutManager.metrics.currentPace) { pace in
            planManager.checkPaceAlert(
                currentPaceSec: pace,
                elapsedTime: workoutManager.elapsedTime
            )
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch workoutManager.state {
        case .idle:
            TabView {
                TodayWorkoutView()
                    .tabItem { Label("Home", systemImage: "house.fill") }

                PlanoView()
                    .tabItem { Label("Plano", systemImage: "list.bullet.clipboard.fill") }

                WidgetsView()
                    .tabItem { Label("Widgets", systemImage: "rectangle.3.group.fill") }

                BiomechanicsView()
                    .tabItem { Label("Forma", systemImage: "figure.run") }

                StandaloneStatusView()
                    .tabItem { Label("Status", systemImage: "antenna.radiowaves.left.and.right") }
            }

        case .running, .paused:
            LiveMetricsView()

        case .ended:
            SummaryView()
        }
    }
}
