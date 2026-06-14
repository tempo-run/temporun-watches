import SwiftUI

@main
struct TempoRunWatchApp: App {
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
        }
    }
}
