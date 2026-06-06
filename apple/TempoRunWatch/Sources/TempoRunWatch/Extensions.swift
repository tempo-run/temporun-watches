import SwiftUI

extension Color {
    static let tempoOrange = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35
}

extension String.StringInterpolation {
    /// Formata um Double usando o especificador printf informado em `default`.
    /// Ex.: "\(value, default: "%.0f")"
    mutating func appendInterpolation(_ value: Double, default spec: String) {
        appendLiteral(String(format: spec, value))
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

extension Int {
    var formattedDuration: String {
        TimeInterval(self).formattedDuration
    }
}

extension Double {
    // self = segundos/km
    var formattedPace: String {
        guard self > 0, self < 3600 else { return "--:--" }
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f", self)
    }

    // self = segundos/km
    var formattedPaceVerbose: String {
        guard self > 0, self < 3600 else { return "--:--/km" }
        let m = Int(self) / 60
        let s = Int(self) % 60
        return String(format: "%d:%02d/km", m, s)
    }

    // Para tempos de prova (hh:mm:ss)
    var formattedRaceTime: String {
        guard self > 0 else { return "--:--:--" }
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
