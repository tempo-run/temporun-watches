import Foundation
import HealthKit
import CoreLocation
import WatchKit

enum WorkoutState {
    case idle, running, paused, ended
}

// MARK: - Modelo de métricas ao vivo

struct LiveMetrics {
    // Corrida
    var distanceKm: Double = 0
    var stepCount: Double = 0
    var strideLength: Double = 0          // metros
    var runningPower: Double = 0          // watts
    var groundContactTime: Double = 0     // ms
    var verticalOscillation: Double = 0   // cm
    var currentPace: Double = 0           // seg/km
    var averagePace: Double = 0           // seg/km
    var cadence: Double = 0               // passos/min (stepCount / min)

    // Energia
    var activeEnergyBurned: Double = 0    // kcal
    var basalEnergyBurned: Double = 0     // kcal

    // Cardio
    var heartRate: Double = 0             // bpm
    var averageHeartRate: Double = 0      // bpm
    var heartRateVariability: Double = 0  // ms (SDNN)
    var restingHeartRate: Double = 0      // bpm
    var vo2Max: Double = 0                // mL/kg/min

    // Respiração / SpO2
    var oxygenSaturation: Double = 0      // %
    var respiratoryRate: Double = 0       // resp/min

    // Altitude
    var flightsClimbed: Double = 0
    var elevationGain: Double = 0         // metros (calculado via GPS)

    var totalEnergyBurned: Double { activeEnergyBurned + basalEnergyBurned }
}

// MARK: - WorkoutManager

@MainActor
class WorkoutManager: NSObject, ObservableObject {

    @Published var state: WorkoutState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var metrics = LiveMetrics()

    // Atalhos convenientes usados pelas views
    var distanceKm: Double { metrics.distanceKm }
    var currentPace: Double { metrics.currentPace }
    var averagePace: Double { metrics.averagePace }
    var heartRate: Double { metrics.heartRate }
    var averageHeartRate: Double { metrics.averageHeartRate }

    // MARK: - HealthKit
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?

    // MARK: - GPS
    private let locationManager = CLLocationManager()
    private var locations: [CLLocation] = []
    private var lastLocation: CLLocation?

    // MARK: - Splits / haptics
    private var lastSplitKm: Int = 0

    // MARK: - Timer
    private var timer: Timer?
    private var startDate: Date?

    // MARK: - Tipos de dado

    private let workoutTypes: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.oxygenSaturation),
        HKQuantityType(.respiratoryRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.stepCount),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.flightsClimbed),
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
        HKQuantityType(.stepCount),
        HKQuantityType(.runningStrideLength),
        HKQuantityType(.runningPower),
        HKQuantityType(.runningGroundContactTime),
        HKQuantityType(.runningVerticalOscillation),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.flightsClimbed),
        HKCategoryType(.sleepAnalysis),
        HKSeriesType.workoutRoute()
    ]

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5
    }

    // MARK: - Autorização

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(toShare: workoutTypes, read: readTypes)
        await fetchRestingMetrics()
    }

    /// Lê métricas de base (repouso/sono) que não chegam via LiveWorkoutBuilder
    private func fetchRestingMetrics() async {
        metrics.restingHeartRate = await fetchLatestQuantity(.restingHeartRate,
                                                              unit: .count().unitDivided(by: .minute()))
        metrics.vo2Max = await fetchLatestQuantity(.vo2Max,
                                                    unit: HKUnit(from: "ml/kg/min"))
        metrics.heartRateVariability = await fetchLatestQuantity(.heartRateVariabilitySDNN,
                                                                  unit: .secondUnit(with: .milli))
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier,
                                     unit: HKUnit) async -> Double {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil,
                                      limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Controle de sessão

    func startWorkout() {
        Task {
            await requestAuthorization()

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
                session.startActivity(with: startDate!)
                try await builder.beginCollection(at: startDate!)

                state = .running
                startTimer()
                locationManager.startUpdatingLocation()
            } catch {
                print("Erro ao iniciar sessão HealthKit: \(error)")
            }
        }
    }

    func togglePause() {
        guard let session = workoutSession else { return }
        if state == .running {
            session.pause()
            state = .paused
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
        } else if state == .paused {
            session.resume()
            state = .running
            startTimer()
            locationManager.startUpdatingLocation()
        }
    }

    func endWorkout() {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        session.end()
        Task {
            try? await builder.endCollection(at: Date())
            let workout = try? await builder.finishWorkout()
            if let workout {
                try? await routeBuilder?.finishRoute(with: workout, metadata: nil)
            }
            timer?.invalidate()
            locationManager.stopUpdatingLocation()
            metrics.averagePace = metrics.distanceKm > 0 ? elapsedTime / metrics.distanceKm : 0
            state = .ended
        }
    }

    func resetWorkout() {
        workoutSession = nil
        workoutBuilder = nil
        routeBuilder = nil
        locations = []
        lastLocation = nil
        elapsedTime = 0
        metrics = LiveMetrics()
        lastSplitKm = 0
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
            }
        }
    }

    // MARK: - Splits e haptics

    private func checkSplit() {
        let currentKm = Int(metrics.distanceKm)
        guard currentKm > lastSplitKm, metrics.distanceKm >= 1 else { return }
        lastSplitKm = currentKm
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Atualização de métricas via LiveWorkoutBuilder

    private func update(from stats: HKStatistics?, type: HKQuantityTypeIdentifier) {
        guard let stats else { return }

        switch type {

        // Cardio
        case .heartRate:
            let unit = HKUnit.count().unitDivided(by: .minute())
            metrics.heartRate = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? metrics.heartRate
            metrics.averageHeartRate = stats.averageQuantity()?.doubleValue(for: unit) ?? metrics.averageHeartRate

        case .heartRateVariabilitySDNN:
            metrics.heartRateVariability = stats.mostRecentQuantity()?
                .doubleValue(for: .secondUnit(with: .milli)) ?? metrics.heartRateVariability

        case .restingHeartRate:
            metrics.restingHeartRate = stats.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute())) ?? metrics.restingHeartRate

        case .vo2Max:
            metrics.vo2Max = stats.mostRecentQuantity()?
                .doubleValue(for: HKUnit(from: "ml/kg/min")) ?? metrics.vo2Max

        case .oxygenSaturation:
            metrics.oxygenSaturation = (stats.mostRecentQuantity()?
                .doubleValue(for: .percent()) ?? metrics.oxygenSaturation) * 100

        case .respiratoryRate:
            metrics.respiratoryRate = stats.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute())) ?? metrics.respiratoryRate

        // Corrida
        case .distanceWalkingRunning:
            let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            metrics.distanceKm = meters / 1000
            checkSplit()

        case .stepCount:
            metrics.stepCount = stats.sumQuantity()?.doubleValue(for: .count()) ?? metrics.stepCount
            // cadência: passos por minuto
            if elapsedTime > 0 {
                metrics.cadence = (metrics.stepCount / elapsedTime) * 60
            }

        case .runningStrideLength:
            metrics.strideLength = stats.mostRecentQuantity()?.doubleValue(for: .meter()) ?? metrics.strideLength

        case .runningPower:
            metrics.runningPower = stats.mostRecentQuantity()?
                .doubleValue(for: HKUnit.watt()) ?? metrics.runningPower

        case .runningGroundContactTime:
            metrics.groundContactTime = stats.mostRecentQuantity()?
                .doubleValue(for: .secondUnit(with: .milli)) ?? metrics.groundContactTime

        case .runningVerticalOscillation:
            metrics.verticalOscillation = (stats.mostRecentQuantity()?
                .doubleValue(for: .meter()) ?? metrics.verticalOscillation / 100) * 100 // → cm

        // Energia
        case .activeEnergyBurned:
            metrics.activeEnergyBurned = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? metrics.activeEnergyBurned

        case .basalEnergyBurned:
            metrics.basalEnergyBurned = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? metrics.basalEnergyBurned

        // Altitude
        case .flightsClimbed:
            metrics.flightsClimbed = stats.sumQuantity()?.doubleValue(for: .count()) ?? metrics.flightsClimbed

        default:
            break
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
                self.update(from: workoutBuilder.statistics(for: qty),
                            type: qty.identifier)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WorkoutManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations newLocations: [CLLocation]) {
        let filtered = newLocations.filter { $0.horizontalAccuracy < 20 }
        guard !filtered.isEmpty else { return }
        Task { @MainActor in
            // Ganho de elevação acumulado
            if let last = self.lastLocation {
                let gain = filtered.reduce(0.0) { acc, loc in
                    let diff = loc.altitude - last.altitude
                    return acc + (diff > 0 ? diff : 0)
                }
                self.metrics.elevationGain += gain
            }
            self.lastLocation = filtered.last
            self.locations.append(contentsOf: filtered)
            try? await self.routeBuilder?.insertRouteData(filtered)
        }
    }
}
