import Foundation
import WatchConnectivity

// Serializa LiveMetrics + elapsed para envio ao iPhone via WCSession
struct WorkoutPayload: Codable {
    // Corrida
    let distanceKm: Double
    let elapsedTime: TimeInterval
    let averagePace: Double
    let bestPace: Double
    let currentSpeed: Double
    let stepCount: Double
    let cadence: Double

    // Biomecânica
    let strideLength: Double
    let runningPower: Double
    let groundContactTime: Double
    let verticalOscillation: Double
    let verticalRatio: Double
    let physicalEffort: Double

    // Cardio
    let averageHeartRate: Double
    let minHeartRate: Double
    let maxHeartRate: Double
    let heartRateVariability: Double
    let restingHeartRate: Double
    let vo2Max: Double
    let oxygenSaturation: Double
    let respiratoryRate: Double
    let timeInZone: [Double]

    // Energia
    let activeEnergyBurned: Double
    let basalEnergyBurned: Double

    // Altitude
    let elevationGain: Double
    let elevationLoss: Double
    let maxAltitude: Double
    let minAltitude: Double

    // Splits
    let splits: [SplitPayload]

    // Timestamps
    let startDate: Date
    let endDate: Date

    init(metrics: LiveMetrics, elapsedTime: TimeInterval, startDate: Date) {
        self.distanceKm         = metrics.distanceKm
        self.elapsedTime        = elapsedTime
        self.averagePace        = metrics.averagePace
        self.bestPace           = metrics.bestPace
        self.currentSpeed       = metrics.currentSpeed
        self.stepCount          = metrics.stepCount
        self.cadence            = metrics.cadence
        self.strideLength       = metrics.strideLength
        self.runningPower       = metrics.runningPower
        self.groundContactTime  = metrics.groundContactTime
        self.verticalOscillation = metrics.verticalOscillation
        self.verticalRatio      = metrics.verticalRatio
        self.physicalEffort     = metrics.physicalEffort
        self.averageHeartRate   = metrics.averageHeartRate
        self.minHeartRate       = metrics.minHeartRate == 999 ? 0 : metrics.minHeartRate
        self.maxHeartRate       = metrics.maxHeartRate
        self.heartRateVariability = metrics.heartRateVariability
        self.restingHeartRate   = metrics.restingHeartRate
        self.vo2Max             = metrics.vo2Max
        self.oxygenSaturation   = metrics.oxygenSaturation
        self.respiratoryRate    = metrics.respiratoryRate
        self.timeInZone         = metrics.timeInZone
        self.activeEnergyBurned = metrics.activeEnergyBurned
        self.basalEnergyBurned  = metrics.basalEnergyBurned
        self.elevationGain      = metrics.elevationGain
        self.elevationLoss      = metrics.elevationLoss
        self.maxAltitude        = metrics.maxAltitude
        self.minAltitude        = metrics.minAltitude == 9999 ? 0 : metrics.minAltitude
        self.splits             = metrics.splits.map { SplitPayload(from: $0) }
        self.startDate          = startDate
        self.endDate            = Date()
    }
}

struct SplitPayload: Codable {
    let km: Int
    let duration: TimeInterval
    let pace: Double
    let avgHeartRate: Double
    let elevationGain: Double

    init(from split: KmSplit) {
        self.km           = split.km
        self.duration     = split.duration
        self.pace         = split.pace
        self.avgHeartRate = split.avgHeartRate
        self.elevationGain = split.elevationGain
    }
}

// MARK: - WatchSessionManager

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isReachable = false
    @Published var lastSendStatus: String = ""

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Chamado pelo WorkoutManager ao encerrar corrida
    func sendWorkout(_ payload: WorkoutPayload) {
        guard WCSession.default.activationState == .activated else {
            transferAsFile(payload)
            return
        }

        guard let data = try? JSONEncoder().encode(payload) else { return }

        if WCSession.default.isReachable {
            // iPhone por perto: envio imediato via sendMessageData
            WCSession.default.sendMessageData(data, replyHandler: { _ in
                DispatchQueue.main.async { self.lastSendStatus = "Enviado ✓" }
            }, errorHandler: { _ in
                // Fallback para transferência em background
                self.transferAsFile(payload)
            })
        } else {
            // iPhone offline: enfileira via transferUserInfo (garante entrega)
            transferAsFile(payload)
        }
    }

    // Envia métricas ao vivo (pace, FC, distância) durante a corrida
    // Usado para mostrar progresso no iPhone enquanto o usuário corre
    func sendLiveUpdate(distanceKm: Double, pace: Double, heartRate: Double, elapsedTime: TimeInterval) {
        guard WCSession.default.isReachable else { return }
        let context: [String: Any] = [
            "type": "liveUpdate",
            "distanceKm": distanceKm,
            "pace": pace,
            "heartRate": heartRate,
            "elapsedTime": elapsedTime
        ]
        try? WCSession.default.updateApplicationContext(context)
    }

    private func transferAsFile(_ payload: WorkoutPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        // transferUserInfo garante entrega mesmo com iPhone desconectado
        WCSession.default.transferUserInfo(["workoutPayload": data])
        DispatchQueue.main.async { self.lastSendStatus = "Na fila ✓" }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Dados de complicação com prioridade máxima
        if let data = userInfo[ComplicationData.contextKey] as? Data,
           let comp = try? JSONDecoder().decode(ComplicationDataTransfer.self, from: data) {
            applyComplicationData(comp)
            return
        }
        // Plano de treino enfileirado
        handlePlanUserInfo(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {}

    private func applyComplicationData(_ comp: ComplicationDataTransfer) {
        // Persiste no App Group para o ComplicationProvider ler
        var cd = ComplicationData()
        cd.weeklyKm        = comp.weeklyKm
        cd.weeklyGoalKm    = comp.weeklyGoalKm
        cd.streakDays      = comp.streakDays
        cd.xp              = comp.xp
        cd.nextWorkoutType = comp.nextWorkoutType
        cd.nextWorkoutKm   = comp.nextWorkoutKm
        cd.nextWorkoutPace = comp.nextWorkoutPace
        cd.nextWorkoutDay  = comp.nextWorkoutDay
        cd.save()
    }
}
