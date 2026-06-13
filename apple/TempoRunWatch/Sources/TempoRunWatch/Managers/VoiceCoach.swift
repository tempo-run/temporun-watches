import Foundation
import AVFoundation

// MARK: - VoiceCoach
// Treinador de voz em pt-BR. Fala instruções de pace durante a corrida
// ("Reduza o ritmo" / "Aumente o ritmo") e anúncios de quilômetro.
// A voz sai pelo áudio ativo (AirPods conectados ou alto-falante do relógio).

@MainActor
final class VoiceCoach {
    static let shared = VoiceCoach()

    private let synth = AVSpeechSynthesizer()

    /// Liga/desliga via Ajustes. Default: ligado.
    var enabled: Bool {
        UserDefaults.standard.object(forKey: "voiceCoaching") as? Bool ?? true
    }

    private init() {}

    // MARK: - Fala genérica

    func speak(_ text: String) {
        // AVSpeechSynthesizer causa SIGABRT no watchOS neste contexto.
        // Desabilitado até ser investigado em ambiente com depurador.
        return
    }

    // MARK: - Sinais de pace

    func paceCue(_ status: PaceStatus) {
        switch status {
        case .tooFast: speak("Reduza o ritmo")
        case .tooSlow: speak("Aumente o ritmo")
        case .ok:      break
        }
    }

    func onTargetCue() {
        speak("Pace no alvo")
    }

    // MARK: - Anúncios de corrida

    /// Anuncia um quilômetro completado: "1 quilômetro, ritmo 5 e 52".
    func announceKm(_ km: Int, paceSeconds: Double) {
        guard paceSeconds > 0 else {
            speak("\(km) \(km == 1 ? "quilômetro" : "quilômetros")")
            return
        }
        let m = Int(paceSeconds) / 60
        let s = Int(paceSeconds) % 60
        speak("\(km) \(km == 1 ? "quilômetro" : "quilômetros"), ritmo \(m) e \(String(format: "%02d", s))")
    }

    func announceStart() {
        speak("Corrida iniciada. Bom treino!")
    }

    func announceFinish() {
        speak("Corrida finalizada. Mandou bem!")
    }

    // MARK: - Sessão de áudio

    private func activateSession() {
        // watchOS AVAudioSession é limitado; deixa o sintetizador gerenciar sozinho.
        // Chamadas manuais podem lançar NSException em certos modelos/versões.
    }
}
