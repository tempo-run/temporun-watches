import Foundation
import WatchConnectivity
import WatchKit

// MARK: - TrainingPlanManager
// Recebe o plano ativo do iPhone via WatchConnectivity e gerencia
// os alertas de zona/pace durante a corrida.

@MainActor
final class TrainingPlanManager: NSObject, ObservableObject {
    static let shared = TrainingPlanManager()

    @Published var plan: TrainingPlan?
    @Published var todayWorkout: DailyWorkout?
    @Published var weekWorkouts: [DailyWorkout] = []
    @Published var paceAlert: PaceAlert?
    @Published var isLoadingPlan = false

    // Chave usada no App Group / applicationContext
    static let planContextKey = "trainingPlan"
    static let appGroupID     = "group.com.temporun.run"

    private override init() {
        super.init()
        loadFromCache()
    }

    // MARK: - Receber plano do iPhone

    func handleReceivedContext(_ context: [String: Any]) {
        guard let data = context[Self.planContextKey] as? Data,
              let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data)
        else { return }
        apply(plan)
        saveToCache(data)
    }

    func handleReceivedUserInfo(_ userInfo: [String: Any]) {
        guard let data = userInfo[Self.planContextKey] as? Data,
              let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data)
        else { return }
        apply(plan)
        saveToCache(data)
    }

    private func apply(_ p: TrainingPlan) {
        plan = p
        todayWorkout = p.todayWorkout()
        weekWorkouts = p.currentWeek?.dias ?? []
    }

    // MARK: - Cache local (UserDefaults do App Group)

    private func saveToCache(_ data: Data) {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        defaults.set(data, forKey: Self.planContextKey)
    }

    private func loadFromCache() {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: Self.planContextKey),
              let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data)
        else { return }
        apply(plan)
    }

    // MARK: - Alertas de pace durante corrida

    func checkPaceAlert(currentPaceSec: Double, elapsedTime: TimeInterval) {
        guard let workout = todayWorkout,
              !workout.workoutType.isRest,
              elapsedTime > 60  // aguarda 1 min antes de alertar
        else { return }

        let status = workout.isPaceOnTarget(currentPaceSec)

        switch status {
        case .ok:
            if paceAlert != nil {
                paceAlert = nil  // limpa alerta anterior
            }
        case .tooFast:
            let newAlert = PaceAlert(status: .tooFast, workout: workout)
            if paceAlert?.status != .tooFast {
                paceAlert = newAlert
                triggerHaptic(for: .tooFast)
            }
        case .tooSlow:
            let newAlert = PaceAlert(status: .tooSlow, workout: workout)
            if paceAlert?.status != .tooSlow {
                paceAlert = newAlert
                triggerHaptic(for: .tooSlow)
            }
        }
    }

    private func triggerHaptic(for status: PaceStatus) {
        switch status {
        case .tooFast: WKInterfaceDevice.current().play(.directionUp)
        case .tooSlow: WKInterfaceDevice.current().play(.directionDown)
        case .ok:      break
        }
    }

    // MARK: - Solicitar plano ao iPhone

    func requestPlanFromPhone() {
        guard WCSession.default.activationState == .activated else { return }
        isLoadingPlan = true
        WCSession.default.sendMessage(["request": "trainingPlan"], replyHandler: { reply in
            Task { @MainActor in
                self.isLoadingPlan = false
                guard let data = reply[Self.planContextKey] as? Data,
                      let plan = try? JSONDecoder().decode(TrainingPlan.self, from: data)
                else { return }
                self.apply(plan)
                self.saveToCache(data)
            }
        }, errorHandler: { _ in
            Task { @MainActor in self.isLoadingPlan = false }
        })
    }
}

// MARK: - PaceAlert

struct PaceAlert: Equatable {
    let status: PaceStatus
    let workout: DailyWorkout
    let timestamp: Date = Date()

    var message: String {
        guard let range = workout.paceRangeSec else { return "" }
        switch status {
        case .tooFast: return "Muito rápido\nAlvo: \(workout.pace_alvo)"
        case .tooSlow: return "Muito lento\nAlvo: \(workout.pace_alvo)"
        case .ok:      return ""
        }
    }

    var sfSymbol: String {
        switch status {
        case .tooFast: return "arrow.up.circle.fill"
        case .tooSlow: return "arrow.down.circle.fill"
        case .ok:      return "checkmark.circle.fill"
        }
    }

    static func == (lhs: PaceAlert, rhs: PaceAlert) -> Bool {
        lhs.status == rhs.status
    }
}

// MARK: - Extensão no WatchSessionManager para receber plano

extension WatchSessionManager {
    func handlePlanContext(_ context: [String: Any]) {
        Task { @MainActor in
            TrainingPlanManager.shared.handleReceivedContext(context)
        }
    }

    func handlePlanUserInfo(_ userInfo: [String: Any]) {
        Task { @MainActor in
            TrainingPlanManager.shared.handleReceivedUserInfo(userInfo)
        }
    }
}
