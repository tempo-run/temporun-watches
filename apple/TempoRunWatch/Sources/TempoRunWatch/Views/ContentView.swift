import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var planManager: TrainingPlanManager
    @State private var showPaceAlert = false
    @State private var showDiagnostics: Bool = CrashReporter.shouldShowDiagnostics()

    var body: some View {
        ZStack {
            mainContent

            if let alert = planManager.paceAlert, showPaceAlert,
               workoutManager.state == .running {
                PaceAlertOverlay(alert: alert, visible: $showPaceAlert)
                    .padding(6)
            }

            // Mostra diagnóstico do último crash / kill (TestFlight sem Mac).
            // Só sobre a tela inicial — nunca durante a corrida.
            if showDiagnostics, workoutManager.state == .idle {
                CrashReportOverlay(report: CrashReporter.pendingReport()) {
                    CrashReporter.clear()
                    showDiagnostics = false
                }
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

// MARK: - Crash report overlay (diagnóstico)

private struct CrashReportOverlay: View {
    let report: String?
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnóstico")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.red)

                    // Breadcrumbs = último passo executado antes do crash.
                    // É a pista mais útil (o backtrace vem sem símbolos no TestFlight).
                    let crumbs = CrashReporter.breadcrumbsText()
                    if !crumbs.isEmpty {
                        Text("Últimos passos:")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.tempoCyan)
                        Text(crumbs)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider().background(Color.white.opacity(0.2))
                    }

                    if let report {
                        Text(report)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("App encerrou durante o início da corrida (sem exceção capturada — provável watchdog/memória). Veja o último passo acima.")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onDismiss) {
                        Text("Limpar")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(LinearGradient.tempoPurpleCyan)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(8)
            }
        }
    }
}
