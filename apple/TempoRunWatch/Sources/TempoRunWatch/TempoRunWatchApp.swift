import SwiftUI

@main
struct TempoRunWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var planManager   = TrainingPlanManager.shared
    @StateObject private var offlineQueue  = OfflineQueue.shared

    private let networkMonitor   = NetworkMonitor.shared
    // WatchSessionManager precisa ser iniciado no launch para receber
    // credenciais e plano enviados pelo iPhone via WatchConnectivity.
    private let sessionManager   = WatchSessionManager.shared

    init() {
        // Captura crashes para diagnóstico em TestFlight (sem Mac/Xcode).
        CrashReporter.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(planManager)
                .environmentObject(offlineQueue)
                .task {
                    workoutManager.requestLocationAuthorization()
                }
                // Toda vez que o app volta ao foreground, tenta esvaziar a fila
                // de corridas pendentes (complementa os gatilhos de "rede voltou"
                // e "credenciais recebidas do iPhone").
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await OfflineQueue.shared.syncAll() }
                    }
                }
        }
    }
}
