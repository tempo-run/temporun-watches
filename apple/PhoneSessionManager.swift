// PhoneSessionManager.swift
// Adicionar ao target iOS do temporun-app (ios/App/App/)
// Recebe dados do Watch e converte para o formato da tabela `corridas` do Supabase

import Foundation
import WatchConnectivity

// MARK: - Delegate para o app iOS reagir aos dados recebidos

protocol PhoneSessionDelegate: AnyObject {
    func didReceiveWorkout(_ corrida: CorridaFromWatch)
    func didReceiveLiveUpdate(_ update: LiveUpdate)
}

// Estrutura mapeada para o schema da tabela `corridas` do Supabase
struct CorridaFromWatch {
    let distancia_km: Double
    let duracao_seg: Int
    let pace_medio: Double             // seg/km
    let pace_melhor: Double            // seg/km
    let velocidade_media: Double       // m/s
    let step_count: Int
    let cadencia: Double               // spm
    let stride_length: Double          // m
    let running_power: Double          // W
    let ground_contact_time: Double    // ms
    let vertical_oscillation: Double   // cm
    let vertical_ratio: Double         // %
    let physical_effort: Double        // METs
    let frequencia_cardiaca_media: Double
    let frequencia_cardiaca_min: Double
    let frequencia_cardiaca_max: Double
    let hrv_sdnn: Double               // ms
    let fc_repouso: Double
    let vo2_estimado: Double
    let spo2: Double                   // %
    let frequencia_respiratoria: Double
    let tempo_zona1: Double            // seg
    let tempo_zona2: Double
    let tempo_zona3: Double
    let tempo_zona4: Double
    let tempo_zona5: Double
    let calorias_ativas: Double
    let calorias_basais: Double
    let calorias_total: Double
    let ganho_elevacao: Double         // m
    let perda_elevacao: Double         // m
    let altitude_max: Double           // m
    let altitude_min: Double           // m
    let splits: [[String: Any]]        // array JSON — mesmo formato gravado pelo app
    let data_inicio: Date
    let data_fim: Date
    let source: String                 // "apple_watch"

    init(from payload: WorkoutPayload) {
        distancia_km              = payload.distanceKm
        duracao_seg               = Int(payload.elapsedTime)
        pace_medio                = payload.averagePace
        pace_melhor               = payload.bestPace
        velocidade_media          = payload.currentSpeed
        step_count                = Int(payload.stepCount)
        cadencia                  = payload.cadence
        stride_length             = payload.strideLength
        running_power             = payload.runningPower
        ground_contact_time       = payload.groundContactTime
        vertical_oscillation      = payload.verticalOscillation
        vertical_ratio            = payload.verticalRatio
        physical_effort           = payload.physicalEffort
        frequencia_cardiaca_media = payload.averageHeartRate
        frequencia_cardiaca_min   = payload.minHeartRate
        frequencia_cardiaca_max   = payload.maxHeartRate
        hrv_sdnn                  = payload.heartRateVariability
        fc_repouso                = payload.restingHeartRate
        vo2_estimado              = payload.vo2Max
        spo2                      = payload.oxygenSaturation
        frequencia_respiratoria   = payload.respiratoryRate
        tempo_zona1               = payload.timeInZone.count > 1 ? payload.timeInZone[1] : 0
        tempo_zona2               = payload.timeInZone.count > 2 ? payload.timeInZone[2] : 0
        tempo_zona3               = payload.timeInZone.count > 3 ? payload.timeInZone[3] : 0
        tempo_zona4               = payload.timeInZone.count > 4 ? payload.timeInZone[4] : 0
        tempo_zona5               = payload.timeInZone.count > 5 ? payload.timeInZone[5] : 0
        calorias_ativas           = payload.activeEnergyBurned
        calorias_basais           = payload.basalEnergyBurned
        calorias_total            = payload.activeEnergyBurned + payload.basalEnergyBurned
        ganho_elevacao            = payload.elevationGain
        perda_elevacao            = payload.elevationLoss
        altitude_max              = payload.maxAltitude
        altitude_min              = payload.minAltitude
        splits                    = payload.splits.map { s in
            ["km": s.km, "duracao": s.duration, "pace": s.pace,
             "fc_media": s.avgHeartRate, "ganho_elevacao": s.elevationGain]
        }
        data_inicio               = payload.startDate
        data_fim                  = payload.endDate
        source                    = "apple_watch"
    }

    // Converte para dicionário pronto para inserir via Supabase JS client
    func toSupabaseDict() -> [String: Any] {
        [
            "distancia_km": distancia_km,
            "duracao_seg": duracao_seg,
            "pace_medio": pace_medio,
            "pace_melhor": pace_melhor,
            "velocidade_media": velocidade_media,
            "step_count": step_count,
            "cadencia": cadencia,
            "stride_length": stride_length,
            "running_power": running_power,
            "ground_contact_time": ground_contact_time,
            "vertical_oscillation": vertical_oscillation,
            "vertical_ratio": vertical_ratio,
            "physical_effort": physical_effort,
            "frequencia_cardiaca_media": frequencia_cardiaca_media,
            "frequencia_cardiaca_min": frequencia_cardiaca_min,
            "frequencia_cardiaca_max": frequencia_cardiaca_max,
            "hrv_sdnn": hrv_sdnn,
            "fc_repouso": fc_repouso,
            "vo2_estimado": vo2_estimado,
            "spo2": spo2,
            "frequencia_respiratoria": frequencia_respiratoria,
            "tempo_zona1": tempo_zona1,
            "tempo_zona2": tempo_zona2,
            "tempo_zona3": tempo_zona3,
            "tempo_zona4": tempo_zona4,
            "tempo_zona5": tempo_zona5,
            "calorias_ativas": calorias_ativas,
            "calorias_basais": calorias_basais,
            "calorias_total": calorias_total,
            "ganho_elevacao": ganho_elevacao,
            "perda_elevacao": perda_elevacao,
            "altitude_max": altitude_max,
            "altitude_min": altitude_min,
            "splits": splits,
            "data_inicio": ISO8601DateFormatter().string(from: data_inicio),
            "data_fim": ISO8601DateFormatter().string(from: data_fim),
            "source": source
        ]
    }
}

struct LiveUpdate {
    let distanceKm: Double
    let pace: Double
    let heartRate: Double
    let elapsedTime: TimeInterval
}

// MARK: - PhoneSessionManager

final class PhoneSessionManager: NSObject {
    static let shared = PhoneSessionManager()
    weak var delegate: PhoneSessionDelegate?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// MARK: - WCSessionDelegate (iOS)

extension PhoneSessionManager: WCSessionDelegate {

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    // iOS exclusivo
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // Recebe corrida completa enviada em tempo real
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        guard let payload = try? JSONDecoder().decode(WorkoutPayload.self, from: messageData) else { return }
        let corrida = CorridaFromWatch(from: payload)
        DispatchQueue.main.async { self.delegate?.didReceiveWorkout(corrida) }
    }

    // Recebe corrida enfileirada (iPhone estava offline)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["workoutPayload"] as? Data,
              let payload = try? JSONDecoder().decode(WorkoutPayload.self, from: data) else { return }
        let corrida = CorridaFromWatch(from: payload)
        DispatchQueue.main.async { self.delegate?.didReceiveWorkout(corrida) }
    }

    // Recebe atualizações ao vivo (pace, FC, distância)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let type = applicationContext["type"] as? String, type == "liveUpdate" else { return }
        let update = LiveUpdate(
            distanceKm:  applicationContext["distanceKm"]  as? Double ?? 0,
            pace:        applicationContext["pace"]         as? Double ?? 0,
            heartRate:   applicationContext["heartRate"]    as? Double ?? 0,
            elapsedTime: applicationContext["elapsedTime"]  as? TimeInterval ?? 0
        )
        DispatchQueue.main.async { self.delegate?.didReceiveLiveUpdate(update) }
    }
}
