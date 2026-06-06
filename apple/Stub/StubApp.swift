import SwiftUI

// App iOS "stub" mínimo. Ele existe apenas como contêiner exigido pela
// App Store para distribuir um app watchOS standalone. O usuário final usa
// o app no Apple Watch; este alvo iOS nunca é a experiência principal.
@main
struct TempoRunStubApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.system(size: 48))
                Text("TempoRun roda no seu Apple Watch.")
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
