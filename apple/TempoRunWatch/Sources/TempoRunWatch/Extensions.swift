import SwiftUI

extension Color {
    static let tempoOrange = Color(red: 1.0, green: 0.42, blue: 0.21) // #FF6B35
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
}
