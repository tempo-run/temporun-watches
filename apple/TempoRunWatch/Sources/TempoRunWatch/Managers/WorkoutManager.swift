import Foundation
import HealthKit
import CoreLocation
import WatchKit

enum WorkoutState {
    case idle, running, paused, ended
}

@MainActor
class WorkoutManager: NSObject, ObservableObject {

    // MARK: - Estado publicado
    @Published var state: WorkoutState = .idle
    @Published var elapsedTime: TimeInterval = 0
    @Published var distanceKm: Double = 0
    @Published var currentPace: Double = 0   // segundos por km
    @Published var averagePace: Double = 0
    @Published var heartRate: Double = 0
    @Published var averageHeartRate: Double = 0

    // MARK: - HealthKit
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // MARK: - GPS / rota
    private var routeBuilder: HKWorkoutRouteBuilder?
    private let locationManager = CLLocationManager()
    private var locations: [CLLocation] = []

    // MARK: - Splits
    private var lastSplitDistance: Double = 0
    private var splitCount: Int = 0

    // MARK: - Timer
    private var timer: Timer?
    private var startDate: Date?

    // MARK: - Tipos de dado solicitados ao HealthKit
    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.runningSpeed),
        HKSeriesType.workoutRoute(),
        .workoutType()
    ]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.distanceWalkingRunning),
        HKSeriesType.workoutRoute()
    ]

    // MARK: - Setup

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
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
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
                session.delegate = self
                builder.delegate = self

                self.workoutSession = session
                self.workoutBuilder = builder
                self.routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)

                startDate = Date()
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
            if let workout, let route = routeBuilder {
                try? await route.finishRoute(with: workout, metadata: nil)
            }
            await MainActor.run {
                state = .ended
                timer?.invalidate()
                locationManager.stopUpdatingLocation()
                computeFinalAverages()
            }
        }
    }

    func resetWorkout() {
        workoutSession = nil
        workoutBuilder = nil
        routeBuilder = nil
        locations = []
        elapsedTime = 0
        distanceKm = 0
        currentPace = 0
        averagePace = 0
        heartRate = 0
        averageHeartRate = 0
        lastSplitDistance = 0
        splitCount = 0
        state = .idle
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    // MARK: - Splits e haptics

    private func checkSplit() {
        let newKm = floor(distanceKm)
        let lastKm = floor(lastSplitDistance)
        guard newKm > lastKm, distanceKm >= 1 else { return }
        splitCount += 1
        lastSplitDistance = distanceKm
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Médias finais

    private func computeFinalAverages() {
        averagePace = distanceKm > 0 ? elapsedTime / distanceKm : 0
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
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let stats = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor in
                switch quantityType {
                case HKQuantityType(.heartRate):
                    let bpm = stats?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    self.heartRate = bpm
                    let avgBpm = stats?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0
                    self.averageHeartRate = avgBpm

                case HKQuantityType(.distanceWalkingRunning):
                    let meters = stats?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    self.distanceKm = meters / 1000
                    self.checkSplit()
                    if self.elapsedTime > 0 {
                        self.currentPace = self.distanceKm > 0 ? self.elapsedTime / self.distanceKm : 0
                    }

                default:
                    break
                }
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
            self.locations.append(contentsOf: filtered)
            try? await self.routeBuilder?.insertRouteData(filtered)
        }
    }
}
