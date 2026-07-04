import SwiftUI

// Mostra status de conectividade e fila offline
// Exibida na aba de configurações / perfil do Watch

struct StandaloneStatusView: View {
    @EnvironmentObject var offlineQueue: OfflineQueue
    @ObservedObject var network = NetworkMonitor.shared
    @State private var showConfirmClear = false
    @AppStorage("voiceCoaching") private var voiceCoaching = true

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                pageTitle("Treinador de voz")

                Toggle(isOn: $voiceCoaching) {
                    HStack(spacing: 6) {
                        Image(systemName: voiceCoaching ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(voiceCoaching ? .tempoCyan : .gray)
                            .font(.system(size: 13))
                        Text("Voz durante o treino")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .tint(.tempoPurple)

                Text("Avisos falados de pace e quilômetros. Use AirPods para ouvir melhor.")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.gray.opacity(0.3))
                pageTitle("Conexão")

                // Status de rede
                NetworkStatusRow(network: network)

                // Credenciais Supabase
                HStack(spacing: 6) {
                    Image(systemName: SupabaseConfig.isConfigured
                          ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundColor(SupabaseConfig.isConfigured ? .green : .red)
                        .font(.system(size: 13))
                    Text(SupabaseConfig.isConfigured ? "Conta sincronizada" : "Abra o app no iPhone")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(SupabaseConfig.isConfigured ? .white : .yellow)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.gray.opacity(0.3))
                pageTitle("Fila offline")

                if offlineQueue.pendingCount == 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Nenhuma corrida pendente")
                            .font(.system(size: 11, design: .rounded)).foregroundColor(.gray)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.tempoOrange).font(.system(size: 13))
                        Text("\(offlineQueue.pendingCount) corrida(s) na fila")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // Status do último sync
                    syncStatusView

                    Button(action: {
                        Task { await offlineQueue.syncAll() }
                    }) {
                        Label(offlineQueue.isSyncing ? "Sincronizando..." : "Sincronizar agora",
                              systemImage: offlineQueue.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.up.circle")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(offlineQueue.isSyncing ? Color.gray : Color.tempoOrange)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .disabled(offlineQueue.isSyncing || !network.isConnected)

                    Button(action: { showConfirmClear = true }) {
                        Text("Limpar fila")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Limpar fila offline?",
                                        isPresented: $showConfirmClear,
                                        titleVisibility: .visible) {
                        Button("Limpar", role: .destructive) { offlineQueue.clear() }
                        Button("Cancelar", role: .cancel) {}
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch offlineQueue.lastSyncStatus {
        case .idle:
            EmptyView()
        case .syncing:
            HStack(spacing: 4) {
                ProgressView().scaleEffect(0.7).tint(.tempoOrange)
                Text("Sincronizando...").font(.system(size: 10)).foregroundColor(.gray)
            }
        case .success(let n):
            Label("\(n) corrida(s) sincronizada(s)", systemImage: "checkmark.circle")
                .font(.system(size: 10)).foregroundColor(.green)
        case .failed(let msg):
            Label("Erro: \(msg)", systemImage: "xmark.circle")
                .font(.system(size: 10)).foregroundColor(.red)
        }
    }
}

private struct NetworkStatusRow: View {
    @ObservedObject var network: NetworkMonitor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 13))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: String {
        switch network.connectionType {
        case .wifi:     return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .none:     return "wifi.slash"
        }
    }

    private var color: Color {
        network.isConnected ? .green : .red
    }

    private var label: String {
        switch network.connectionType {
        case .wifi:     return "Wi-Fi"
        case .cellular: return "Celular (LTE)"
        case .none:     return "Sem conexão"
        }
    }
}

private func pageTitle(_ t: String) -> some View {
    Text(t)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundColor(.tempoOrange)
        .frame(maxWidth: .infinity, alignment: .leading)
}
