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
            Color.black.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 6) {
                // Título + botão Limpar sempre visíveis sem precisar rolar
                HStack {
                    Text("⚠️ Diag")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                    Spacer()
                    Button(action: onDismiss) {
                        Text("Limpar")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(LinearGradient.tempoPurpleCyan)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                // Último breadcrumb — onde o app parou
                let allCrumbs = CrashReporter.breadcrumbsText()
                let lastCrumb = allCrumbs.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }.last ?? "—"
                VStack(alignment: .leading, spacing: 2) {
                    Text("Último passo:")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.tempoCyan)
                    Text(lastCrumb)
                        .font(.system(size: 8, design: .monospaced)).foregroundColor(.yellow)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.2))

                // Resto do log (rolar para ver)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if !allCrumbs.isEmpty {
                            Text(allCrumbs)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                            Divider().background(Color.white.opacity(0.15))
                        }
                        if let report {
                            Text(report)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Sem exceção. Provável watchdog/memória.")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}
