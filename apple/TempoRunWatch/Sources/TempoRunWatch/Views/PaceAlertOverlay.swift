import SwiftUI

// Overlay que aparece sobre as páginas de métricas quando o pace sai da zona-alvo
struct PaceAlertOverlay: View {
    let alert: PaceAlert
    @Binding var visible: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: alert.sfSymbol)
                .font(.system(size: 26))
                .foregroundColor(alertColor)

            Text(alert.status == .tooFast ? "Muito rápido!" : "Muito lento!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Alvo: \(alert.workout.pace_alvo)")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.gray)

            Text(alert.workout.tipo)
                .font(.system(size: 10))
                .foregroundColor(alertColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(alertColor.opacity(0.6), lineWidth: 1.5)
                )
        )
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            // Auto-dismiss após 4 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation { visible = false }
            }
        }
    }

    private var alertColor: Color {
        alert.status == .tooFast ? .red : .blue
    }
}
