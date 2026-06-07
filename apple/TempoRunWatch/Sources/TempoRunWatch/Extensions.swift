import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    static let tempoOrange  = Color(red: 1.0, green: 0.42, blue: 0.21)
    static let tempoPurple  = Color(hex: "7B2DFF")
    static let tempoMagenta = Color(hex: "C43BFF")
    static let tempoBlue    = Color(hex: "2F6BFF")
    static let tempoCyan    = Color(hex: "22D8FF")
    static let tempoCard    = Color(red: 0.05, green: 0.09, blue: 0.17)
}

extension LinearGradient {
    static let tempoGradient = LinearGradient(
        colors: [.tempoPurple, .tempoMagenta, .tempoBlue, .tempoCyan],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let tempoPurpleCyan = LinearGradient(
        colors: [.tempoPurple, .tempoCyan],
        startPoint: .leading, endPoint: .trailing
    )
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ value: Double, default spec: String) {
        appendLiteral(String(format: spec, value))
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        let s = Int(self) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

extension Int {
    var formattedDuration: String { TimeInterval(self).formattedDuration }
}

extension Double {
    var formattedPace: String {
        guard self > 0, self < 3600 else { return "--:--" }
        let m = Int(self) / 60; let s = Int(self) % 60
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String { String(format: "%.2f", self) }

    var formattedPaceVerbose: String {
        guard self > 0, self < 3600 else { return "--:--/km" }
        let m = Int(self) / 60; let s = Int(self) % 60
        return String(format: "%d:%02d/km", m, s)
    }

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
