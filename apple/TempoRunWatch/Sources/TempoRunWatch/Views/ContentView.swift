import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager
    @State private var showPaceAlert = false

    var body: some View {
        ZStack {
            mainContent

            // Overlay de alerta de pace (aparece durante corrida)
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
            // Verifica alerta de pace a cada atualização de pace
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
            // Tabs: treino do dia | semana | iniciar livre
            TabView {
                TodayWorkoutView()
                    .tabItem { Label("Hoje", systemImage: "calendar") }

                WeekPlanView()
                    .tabItem { Label("Semana", systemImage: "list.bullet") }

                StartView()
                    .tabItem { Label("Livre", systemImage: "play.fill") }
            }

        case .running, .paused:
            LiveMetricsView()

        case .ended:
            SummaryView()
        }
    }
}
