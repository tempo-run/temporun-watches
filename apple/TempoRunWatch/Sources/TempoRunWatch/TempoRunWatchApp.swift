import SwiftUI

@main
struct TempoRunWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var planManager   = TrainingPlanManager.shared
    @StateObject private var offlineQueue  = OfflineQueue.shared

    // Inicia NetworkMonitor na inicialização do app
    private let networkMonitor = NetworkMonitor.shared

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
