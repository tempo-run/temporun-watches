import Foundation
import Network

// Monitora conectividade celular/WiFi do relógio
// Dispara sync automático da fila quando a rede volta

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .none

    enum ConnectionType { case wifi, cellular, none }

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "com.temporun.network", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.usesInterfaceType(.wifi)     ? .wifi
                                     : path.usesInterfaceType(.cellular) ? .cellular
                                     : .none

                // Rede voltou: tenta sincronizar fila pendente
                if !wasConnected, self?.isConnected == true {
                    await OfflineQueue.shared.syncAll()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
