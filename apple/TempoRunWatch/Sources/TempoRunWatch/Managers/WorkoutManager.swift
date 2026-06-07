import Foundation
import HealthKit
import CoreLocation
import WatchKit
import WatchConnectivity

enum WorkoutState {
    case idle, running, paused, ended
}

// MARK: - Zonas de FC (modelo 5 zonas padrão)

struct HeartRateZones {
    let z1: ClosedRange<Double>  // Recuperação
    let z2: ClosedRange<Double>  // Aeróbico base
    let z3: ClosedRange<Double>  // Tempo
    let z4: ClosedRange<Double>  // Limiar
    let z5: ClosedRange<Double>  // VO₂ máx

    init(maxHR: Double) {
        z1 = (maxHR * 0.50)...(maxHR * 0.60)
        z2 = (maxHR * 0.60)...(maxHR * 0.70)
        z3 = (maxHR * 0.70)...(maxHR * 0.80)
        z4 = (maxHR * 0.80)...(maxHR * 0.90)
        z5 = (maxHR * 0.90)...(maxHR * 1.00)
    }

    func zone(for hr: Double) -> Int {
        switch hr {
        case z1: return 1
        case z2: return 2
        case z3: return 3
        case z4: return 4
        case z5: return 5
        default: return hr < z1.lowerBound ? 0 : 5
        }
    }
}

// MARK: - Split de km

struct KmSplit {
    let km: Int
    let duration: TimeInterval
    let pace: Double           // seg/km
    let avgHeartRate: Double
    let elevationGain: Double
}

// MARK: - Preditor de provas (Daniels)

struct RacePredictions {
    let km5: TimeInterval
    let km10: TimeInterval
    let halfMarathon: TimeInterval
    let marathon: TimeInterval

    // Fórmula de Daniels: velocity (m/min) a partir do VO₂ máx
    init(vo2Max: Double) {
        func predict(distanceM: Double) -> TimeInterval {
            guard vo2Max > 0 else { return 0 }
            // percentual do VO₂ máx sustentável por distância (Daniels & Gilbert)
            let pct: Double
            switch distanceM {
            case ..<5001:  pct = 0.9757
            case ..<10001: pct = 0.9442
            case ..<21098: pct = 0.8942
            default:       pct = 0.8397
            }
            let targetVO2 = vo2Max * pct
            // velocity (m/min) = (targetVO2 + 3.5) / 0.2
            let velocity = (targetVO2 + 3.5) / 0.2
            return (distanceM / velocity) * 60
        }
        km5          = predict(distanceM: 5000)
        km10         = predict(distanceM: 10000)
        halfMarathon = predict(distanceM: 21097.5)
        marathon     = predict(distanceM: 42195)
    }
}

// MARK: - Modelo de métricas ao vivo

struct LiveMetrics {

    // ── Corrida ──────────────────────────────────────────────────────────────
    var distanceKm: Double = 0
    var currentPace: Double = 0            // seg/km (instantâneo)
    var averagePace: Double = 0            // seg/km
    var bestPace: Double = 0               // seg/km (menor valor = mais rápido)
    var currentSpeed: Double = 0           // m/s (runningSpeed nativo)
    var stepCount: Double = 0
    var cadence: Double = 0                // passos/min

    // ── Biomecânica (Running Dynamics) ───────────────────────────────────────
    var strideLength: Double = 0           // m
    var runningPower: Double = 0           // W
    var groundContactTime: Double = 0      // ms
    var verticalOscillation: Double = 0    // cm
    var verticalRatio: Double = 0          // % = (verticalOscillation / strideLength) * 100
    var physicalEffort: Double = 0         // 1–10 (METs normalizados, watchOS 10+)

    // ── Energia ──────────────────────────────────────────────────────────────
    var activeEnergyBurned: Double = 0     // kcal
    var basalEnergyBurned: Double = 0      // kcal
    var totalEnergyBurned: Double { activeEnergyBurned + basalEnergyBurned }

    // ── Cardio ───────────────────────────────────────────────────────────────
    var heartRate: Double = 0              // bpm
    var averageHeartRate: Double = 0       // bpm
    var minHeartRate: Double = 999         // bpm
    var maxHeartRate: Double = 0           // bpm
    var heartRateVariability: Double = 0   // ms (SDNN)
    var restingHeartRate: Double = 0       // bpm
    var vo2Max: Double = 0                 // mL/kg/min

    // Zonas de FC: segundos acumulados por zona [Z0, Z1, Z2, Z3, Z4, Z5]
    var timeInZone: [Double] = [0, 0, 0, 0, 0, 0]
    var currentZone: Int = 0

    // ── Respiração / SpO₂ ────────────────────────────────────────────────────
    var oxygenSaturation: Double = 0       // %
    var respiratoryRate: Double = 0        // resp/min

    // ── Altitude / GPS ────────────────────────────────────────────────────────
    var flightsClimbed: Double = 0
    var elevationGain: Double = 0          // m acumulado
    var elevationLoss: Double = 0          // m acumulado
    var currentAltitude: Double = 0        // m (nível do mar)
    var maxAltitude: Double = 0            // m
    var minAltitude: Double = 9999         // m

    // ── Predições ─────────────────────────────────────────────────────────────
    var racePredictions: RacePredictions = RacePredictions(vo2Max: 0)

    // ── Splits ────────────────────────────────────────────────────────────────
    var splits: [KmSplit] = []
}

// MARK: - WorkoutManager

@MainActor
class WorkoutManager: NSObject, ObservableObject {

    @Published var state: WorkoutState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var metrics = LiveMetrics()
    @Published var lastMetrics = LiveMetrics()
    @Published var saveResult: WatchSaveResult?

    // GPS / localização
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var gpsAcquired: Bool = false   // true após o 1º fix preciso

    // Atalhos para as views
    var distanceKm: Double    { metrics.distanceKm }
    var currentPace: Double   { metrics.currentPace }
    var averagePace: Double   { metrics.averagePace }
    var heartRate: Double     { metrics.heartRate }
    var averageHeartRate: Double { metrics.averageHeartRate }

    // MARK: - HealthKit / GPS
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let locationManager = CLLocationManager()
    private var locations: [CLLocation] = []
    private var lastLocation: CLLocation?

    // MARK: - Zonas / splits / FC min-max
    private var hrZones: HeartRateZones = HeartRateZones(maxHR: 190)
    private var lastZoneTimestamp: Date = Date()
    private var lastSplitKm: Int = 0
    private var splitStartTime: TimeInterval = 0
    private var splitStartHRSum: Double = 0
    private var splitHRSamples: Int = 0
    private var splitStartElevation: Double = 0

    // MARK: - Timer
    private var timer: Timer?
    private var startDate: Date?

    // MARK: - Tipos HK

    private let shareTypes: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.stepCount),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.physicalEffort),
        HKSeriesType.workoutRoute(),
        .workoutType()
    ]

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.runningSpeed),
        HKQuantityType(.stepCount),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.flightsClimbed),
        HKQuantityType(.physicalEffort),
        HKCategoryType(.sleepAnalysis),
        HKSeriesType.workoutRoute()
    ]

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5
        locationStatus = locationManager.authorizationStatus
    }

    // MARK: - Autorização

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        await fetchRestingMetrics()
    }

    /// Pede autorização de localização. Chamar cedo (no launch) para o usuário
    /// liberar o GPS antes de iniciar a corrida.
    func requestLocationAuthorization() {
        locationStatus = locationManager.authorizationStatus
        if locationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func fetchRestingMetrics() async {
        let rhr = await fetchLatest(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        let hrv = await fetchLatest(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        let vo2 = await fetchLatest(.vo2Max, unit: HKUnit(from: "ml/kg/min"))

        metrics.restingHeartRate = rhr
        metrics.heartRateVariability = hrv
        metrics.vo2Max = vo2
        metrics.racePredictions = RacePredictions(vo2Max: vo2)

        // FC máx estimada = 220 - idade (sem dados de perfil, usa 190 como fallback)
        let estimatedMaxHR: Double = rhr > 0 ? min(220, rhr * 4.5) : 190
        hrZones = HeartRateZones(maxHR: estimatedMaxHR)
    }

    private func fetchLatest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let type = HKQuantityType(id)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, s, _ in
                cont.resume(returning: (s?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(q)
        }
    }

    // MARK: - Controle de sessão

    func startWorkout() {
        gpsAcquired = false
        requestLocationAuthorization()
        Task {
            await requestAuthorization()
            VoiceCoach.shared.announceStart()
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor

            do {
                let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                              workoutConfiguration: config)
                session.delegate = self
                builder.delegate = self
                workoutSession = session
                workoutBuilder = builder
                routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

                startDate = Date()
                lastZoneTimestamp = startDate!
                session.startActivity(with: startDate!)
                try await builder.beginCollection(at: startDate!)

                state = .running
                startTimer()
                locationManager.startUpdatingLocation()
            } catch {
                print("Erro ao iniciar sessão: \(error)")
            }
        }
    }

    func togglePause() {
        guard let session = workoutSession else { return }
        if state == .running {
            session.pause(); state = .paused
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
            flushZoneTime()
        } else if state == .paused {
            session.resume(); state = .running
            lastZoneTimestamp = Date()
            startTimer()
            locationManager.startUpdatingLocation()
        }
    }

    func endWorkout() {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        flushZoneTime()
        VoiceCoach.shared.announceFinish()
        session.end()
        Task {
            try? await builder.endCollection(at: Date())
            let workout = try? await builder.finishWorkout()
            if let workout { try? await routeBuilder?.finishRoute(with: workout, metadata: nil) }
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
            metrics.averagePace = metrics.distanceKm > 0 ? elapsedTime / metrics.distanceKm : 0

            guard let start = startDate else { state = .ended; return }
            let payload = WorkoutPayload(metrics: metrics, elapsedTime: elapsedTime, startDate: start)

            let iPhoneReachable = WCSession.default.activationState == .activated
                                  && WCSession.default.isReachable

            if iPhoneReachable {
                // Caminho A/B: envia ao iPhone (iPhone grava no Supabase)
                WatchSessionManager.shared.sendWorkout(payload)
            } else {
                // Caminho standalone: grava direto no Supabase ou enfileira
                await saveStandalone(payload: payload)
            }

            lastMetrics = metrics
            state = .ended
        }
    }

    // MARK: - Standalone save

    private func saveStandalone(payload: WorkoutPayload) async {
        // Monta o dicionário no formato da tabela corridas
        let dict: [String: Any] = [
            "distancia_km":              payload.distanceKm,
            "duracao_seg":               Int(payload.elapsedTime),
            "pace_medio":                payload.averagePace,
            "pace_melhor":               payload.bestPace,
            "velocidade_media":          payload.currentSpeed,
            "step_count":                Int(payload.stepCount),
            "cadencia":                  payload.cadence,
            "stride_length":             payload.strideLength,
            "running_power":             payload.runningPower,
            "ground_contact_time":       payload.groundContactTime,
            "vertical_oscillation":      payload.verticalOscillation,
            "vertical_ratio":            payload.verticalRatio,
            "physical_effort":           payload.physicalEffort,
            "frequencia_cardiaca_media": payload.averageHeartRate,
            "frequencia_cardiaca_min":   payload.minHeartRate,
            "frequencia_cardiaca_max":   payload.maxHeartRate,
            "hrv_sdnn":                  payload.heartRateVariability,
            "fc_repouso":                payload.restingHeartRate,
            "vo2_estimado":              payload.vo2Max,
            "spo2":                      payload.oxygenSaturation,
            "frequencia_respiratoria":   payload.respiratoryRate,
            "tempo_zona1":               payload.timeInZone.count > 1 ? payload.timeInZone[1] : 0,
            "tempo_zona2":               payload.timeInZone.count > 2 ? payload.timeInZone[2] : 0,
            "tempo_zona3":               payload.timeInZone.count > 3 ? payload.timeInZone[3] : 0,
            "tempo_zona4":               payload.timeInZone.count > 4 ? payload.timeInZone[4] : 0,
            "tempo_zona5":               payload.timeInZone.count > 5 ? payload.timeInZone[5] : 0,
            "calorias_ativas":           payload.activeEnergyBurned,
            "calorias_basais":           payload.basalEnergyBurned,
            "calorias_total":            payload.activeEnergyBurned + payload.basalEnergyBurned,
            "ganho_elevacao":            payload.elevationGain,
            "perda_elevacao":            payload.elevationLoss,
            "altitude_max":              payload.maxAltitude,
            "altitude_min":              payload.minAltitude,
            "splits":                    payload.splits.map {
                                            ["km": $0.km, "duracao": $0.duration,
                                             "pace": $0.pace, "fc_media": $0.avgHeartRate,
                                             "ganho_elevacao": $0.elevationGain]
                                         },
            "data_inicio":               ISO8601DateFormatter().string(from: payload.startDate),
            "data_fim":                  ISO8601DateFormatter().string(from: payload.endDate),
            "source":                    "apple_watch_standalone"
        ]

        if NetworkMonitor.shared.isConnected && SupabaseConfig.isConfigured {
            do {
                let result = try await SupabaseClient.shared.insertCorrida(dict)
                saveResult = result
            } catch {
                OfflineQueue.shared.enqueue(dict)
            }
        } else {
            await OfflineQueue.shared.enqueue(dict)
        }
    }

    func resetWorkout() {
        workoutSession = nil; workoutBuilder = nil; routeBuilder = nil
        locations = []; lastLocation = nil
        elapsedTime = 0; metrics = LiveMetrics()
        lastSplitKm = 0; splitStartTime = 0
        splitStartHRSum = 0; splitHRSamples = 0; splitStartElevation = 0
        gpsAcquired = false
        state = .idle
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
                self.elapsedTime = Date().timeIntervalSince(start)
                if self.metrics.distanceKm > 0 {
                    self.metrics.currentPace = self.elapsedTime / self.metrics.distanceKm
                }
                self.accumulateZoneSecond()

                // Atualização ao vivo para o iPhone a cada 5 segundos
                if Int(self.elapsedTime) % 5 == 0 {
                    WatchSessionManager.shared.sendLiveUpdate(
                        distanceKm:  self.metrics.distanceKm,
                        pace:        self.metrics.currentPace,
                        heartRate:   self.metrics.heartRate,
                        elapsedTime: self.elapsedTime
                    )
                }
            }
        }
    }

    // MARK: - Zonas de FC

    private func accumulateZoneSecond() {
        guard metrics.heartRate > 0 else { return }
        let zone = hrZones.zone(for: metrics.heartRate)
        metrics.currentZone = zone
        metrics.timeInZone[zone] += 1
    }

    private func flushZoneTime() {
        // garante que o tempo decorrido desde último tick é contabilizado
        let now = Date()
        let delta = now.timeIntervalSince(lastZoneTimestamp)
        if metrics.heartRate > 0 {
            let zone = hrZones.zone(for: metrics.heartRate)
            metrics.timeInZone[zone] += delta
        }
        lastZoneTimestamp = now
    }

    // MARK: - Splits

    private func checkSplit() {
        let currentKm = Int(metrics.distanceKm)
        guard currentKm > lastSplitKm, metrics.distanceKm >= 1 else { return }

        let splitDuration = elapsedTime - splitStartTime
        let splitPace = splitDuration  // 1 km exato, então pace = duration
        let avgHR = splitHRSamples > 0 ? splitStartHRSum / Double(splitHRSamples) : 0
        let elevGain = metrics.elevationGain - splitStartElevation

        metrics.splits.append(KmSplit(
            km: currentKm,
            duration: splitDuration,
            pace: splitPace,
            avgHeartRate: avgHR,
            elevationGain: elevGain
        ))

        // Reset contadores do split
        splitStartTime = elapsedTime
        splitStartHRSum = 0
        splitHRSamples = 0
        splitStartElevation = metrics.elevationGain
        lastSplitKm = currentKm

        WKInterfaceDevice.current().play(.success)
        VoiceCoach.shared.announceKm(currentKm, paceSeconds: splitPace)
    }

    // MARK: - Atualização de métricas

    private func update(from stats: HKStatistics?, type: HKQuantityTypeIdentifier) {
        guard let stats else { return }

        switch type {

        case .heartRate:
            let unit = HKUnit.count().unitDivided(by: .minute())
            let current = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
            if current > 0 {
                metrics.heartRate = current
                metrics.minHeartRate = min(metrics.minHeartRate, current)
                metrics.maxHeartRate = max(metrics.maxHeartRate, current)
                splitStartHRSum += current
                splitHRSamples += 1
            }
            metrics.averageHeartRate = stats.averageQuantity()?.doubleValue(for: unit) ?? metrics.averageHeartRate

        case .heartRateVariabilitySDNN:
            metrics.heartRateVariability = stats.mostRecentQuantity()?
                .doubleValue(for: .secondUnit(with: .milli)) ?? metrics.heartRateVariability

        case .restingHeartRate:
            metrics.restingHeartRate = stats.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute())) ?? metrics.restingHeartRate

        case .vo2Max:
            let v = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "ml/kg/min")) ?? 0
            if v > 0 {
                metrics.vo2Max = v
                metrics.racePredictions = RacePredictions(vo2Max: v)
            }

        case .oxygenSaturation:
            let raw = stats.mostRecentQuantity()?.doubleValue(for: .percent()) ?? 0
            metrics.oxygenSaturation = raw > 1 ? raw : raw * 100

        case .respiratoryRate:
            metrics.respiratoryRate = stats.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute())) ?? metrics.respiratoryRate

        case .runningSpeed:
            let mps = stats.mostRecentQuantity()?.doubleValue(for: .meter().unitDivided(by: .second())) ?? 0
            metrics.currentSpeed = mps
            // pace em seg/km a partir da velocidade instantânea
            if mps > 0 { metrics.currentPace = 1000 / mps / 60 * 60 }

        case .distanceWalkingRunning:
            let km = (stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0) / 1000
            metrics.distanceKm = km
            if elapsedTime > 0 { metrics.averagePace = elapsedTime / max(km, 0.001) }
            checkSplit()

        case .stepCount:
            metrics.stepCount = stats.sumQuantity()?.doubleValue(for: .count()) ?? metrics.stepCount
            if elapsedTime > 0 { metrics.cadence = (metrics.stepCount / elapsedTime) * 60 }

        case .runningStrideLength:
            let sl = stats.mostRecentQuantity()?.doubleValue(for: .meter()) ?? 0
            metrics.strideLength = sl
            // Vertical Ratio: oscilação vertical / comprimento de passada * 100
            if sl > 0 { metrics.verticalRatio = (metrics.verticalOscillation / 100) / sl * 100 }

        case .runningPower:
            metrics.runningPower = stats.mostRecentQuantity()?
                .doubleValue(for: HKUnit.watt()) ?? metrics.runningPower

        case .runningGroundContactTime:
            metrics.groundContactTime = stats.mostRecentQuantity()?
                .doubleValue(for: .secondUnit(with: .milli)) ?? metrics.groundContactTime

        case .runningVerticalOscillation:
            let osc = (stats.mostRecentQuantity()?.doubleValue(for: .meter()) ?? 0) * 100 // → cm
            metrics.verticalOscillation = osc
            if metrics.strideLength > 0 { metrics.verticalRatio = (osc / 100) / metrics.strideLength * 100 }

        case .activeEnergyBurned:
            metrics.activeEnergyBurned = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? metrics.activeEnergyBurned

        case .basalEnergyBurned:
            metrics.basalEnergyBurned = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? metrics.basalEnergyBurned

        case .flightsClimbed:
            metrics.flightsClimbed = stats.sumQuantity()?.doubleValue(for: .count()) ?? metrics.flightsClimbed

        case .physicalEffort:
            // METs normalizados (1–10)
            metrics.physicalEffort = stats.mostRecentQuantity()?
                .doubleValue(for: HKUnit(from: "MET")) ?? metrics.physicalEffort

        default:
            break
        }

        // Best pace (menor seg/km = mais rápido)
        if metrics.currentPace > 0 {
            metrics.bestPace = metrics.bestPace == 0
                ? metrics.currentPace
                : min(metrics.bestPace, metrics.currentPace)
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("Sessão falhou: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let qty = type as? HKQuantityType else { continue }
                self.update(from: workoutBuilder.statistics(for: qty), type: HKQuantityTypeIdentifier(rawValue: qty.identifier))
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.locationStatus = status }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations newLocations: [CLLocation]) {
        let filtered = newLocations.filter { $0.horizontalAccuracy < 20 }
        guard !filtered.isEmpty else { return }
        Task { @MainActor in
            if !self.gpsAcquired { self.gpsAcquired = true }
            for loc in filtered {
                // Altitude
                metrics.currentAltitude = loc.altitude
                metrics.maxAltitude = max(metrics.maxAltitude, loc.altitude)
                metrics.minAltitude = min(metrics.minAltitude, loc.altitude)

                // Ganho/perda de elevação acumulado
                if let last = lastLocation {
                    let diff = loc.altitude - last.altitude
                    if diff > 0 { metrics.elevationGain += diff }
                    else        { metrics.elevationLoss += abs(diff) }
                }
                lastLocation = loc
            }
            locations.append(contentsOf: filtered)
            try? await routeBuilder?.insertRouteData(filtered)
        }
    }
}
