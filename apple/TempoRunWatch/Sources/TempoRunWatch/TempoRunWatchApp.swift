import SwiftUI

@main
struct TempoRunWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var planManager = TrainingPlanManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(planManager)
        }
    }
}
