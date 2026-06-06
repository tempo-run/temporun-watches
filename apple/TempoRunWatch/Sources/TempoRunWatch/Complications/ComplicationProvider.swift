import ClockKit
import SwiftUI

private extension Color {
    static let tempoOrange = Color(red: 1.0, green: 0.42, blue: 0.21)
}

// MARK: - Dados compartilhados para as complicações

struct ComplicationData: Codable {
    var weeklyKm: Double = 0           // km rodados na semana
    var weeklyGoalKm: Double = 0       // meta semanal
    var streakDays: Int = 0            // streak de dias consecutivos
    var xp: Int = 0                    // XP total
    var nextWorkoutType: String = ""   // tipo do próximo treino
    var nextWorkoutKm: Double = 0      // distância do próximo treino
    var nextWorkoutPace: String = ""   // pace-alvo do próximo treino
    var nextWorkoutDay: String = ""    // "Hoje", "Amanhã", "Quinta"

    static let appGroupID  = "group.com.temporun.run"
    static let cacheKey    = "complicationData"
    static let contextKey  = "complicationData"   // chave usada no userInfo do WCSession

    static func load() -> ComplicationData {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        guard let data = defaults.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(ComplicationData.self, from: data)
        else { return ComplicationData() }
        return decoded
    }

    func save() {
        let defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.cacheKey)
        }
    }

    var weeklyProgress: Double {
        guard weeklyGoalKm > 0 else { return 0 }
        return min(weeklyKm / weeklyGoalKm, 1.0)
    }
}

// MARK: - CLKComplicationDataSource

class ComplicationProvider: NSObject, CLKComplicationDataSource {

    // MARK: - Posições suportadas

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "temporun.main",
                displayName: "TempoRun",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular,
                    .graphicBezel,
                    .graphicExtraLarge
                ]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Template por família

    func getCurrentTimelineEntry(for complication: CLKComplication,
                                  withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let data = ComplicationData.load()
        let template = buildTemplate(for: complication.family, data: data)
        let entry = template.map { CLKComplicationTimelineEntry(date: Date(), complicationTemplate: $0) }
        handler(entry)
    }

    func getTimelineEntries(for complication: CLKComplication,
                            after date: Date,
                            limit: Int,
                            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil) // sem timeline futura por enquanto
    }

    func getPrivacyBehavior(for complication: CLKComplication,
                             withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Builders por família

    private func buildTemplate(for family: CLKComplicationFamily,
                                data: ComplicationData) -> CLKComplicationTemplate? {
        switch family {

        // ── Circular pequeno ───────────────────────────────────────────────
        case .circularSmall:
            let t = CLKComplicationTemplateCircularSmallStackText()
            t.line1TextProvider = CLKSimpleTextProvider(text: "\(Int(data.weeklyKm))")
            t.line2TextProvider = CLKSimpleTextProvider(text: "km")
            t.tintColor = UIColor(Color.tempoOrange)
            return t

        // ── Utilitário pequeno ─────────────────────────────────────────────
        case .utilitarianSmall:
            let t = CLKComplicationTemplateUtilitarianSmallFlat()
            t.textProvider = CLKSimpleTextProvider(
                text: "\(Int(data.weeklyKm)) km",
                shortText: "\(Int(data.weeklyKm))"
            )
            t.tintColor = UIColor(Color.tempoOrange)
            return t

        // ── Utilitário grande ──────────────────────────────────────────────
        case .utilitarianLarge:
            let t = CLKComplicationTemplateUtilitarianLargeFlat()
            let next = data.nextWorkoutDay.isEmpty
                ? "\(Int(data.weeklyKm)) km · 🔥 \(data.streakDays)d"
                : "\(data.nextWorkoutDay): \(data.nextWorkoutType) \(String(format: "%.1f", data.nextWorkoutKm))km"
            t.textProvider = CLKSimpleTextProvider(text: next)
            t.tintColor = UIColor(Color.tempoOrange)
            return t

        // ── Modular pequeno ────────────────────────────────────────────────
        case .modularSmall:
            let t = CLKComplicationTemplateModularSmallStackText()
            t.line1TextProvider = CLKSimpleTextProvider(text: "\(Int(data.weeklyKm)) km")
            t.line2TextProvider = CLKSimpleTextProvider(text: "🔥\(data.streakDays)")
            t.tintColor = UIColor(Color.tempoOrange)
            return t

        // ── Modular grande ─────────────────────────────────────────────────
        case .modularLarge:
            let t = CLKComplicationTemplateModularLargeStandardBody()
            t.headerTextProvider = CLKSimpleTextProvider(text: "TempoRun")
            t.body1TextProvider = CLKSimpleTextProvider(
                text: "\(Int(data.weeklyKm)) / \(Int(data.weeklyGoalKm)) km · 🔥\(data.streakDays)d"
            )
            let next = data.nextWorkoutDay.isEmpty
                ? "Bom treino!"
                : "\(data.nextWorkoutDay): \(data.nextWorkoutType)"
            t.body2TextProvider = CLKSimpleTextProvider(text: next)
            t.tintColor = UIColor(Color.tempoOrange)
            return t

        // ── Graphic Corner ─────────────────────────────────────────────────
        case .graphicCorner:
            let t = CLKComplicationTemplateGraphicCornerGaugeText()
            t.outerTextProvider = CLKSimpleTextProvider(
                text: "\(Int(data.weeklyKm))km",
                shortText: "\(Int(data.weeklyKm))"
            )
            t.gaugeProvider = CLKSimpleGaugeProvider(
                style: .ring,
                gaugeColor: UIColor(Color.tempoOrange),
                fillFraction: Float(data.weeklyProgress)
            )
            return t

        // ── Graphic Circular ───────────────────────────────────────────────
        case .graphicCircular:
            let t = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
            t.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(data.weeklyKm))")
            t.leadingTextProvider = CLKSimpleTextProvider(text: "km")
            t.trailingTextProvider = CLKSimpleTextProvider(text: "🔥")
            t.gaugeProvider = CLKSimpleGaugeProvider(
                style: .ring,
                gaugeColor: UIColor(Color.tempoOrange),
                fillFraction: Float(data.weeklyProgress)
            )
            return t

        // ── Graphic Rectangular ────────────────────────────────────────────
        case .graphicRectangular:
            let t = CLKComplicationTemplateGraphicRectangularStandardBody()
            t.headerTextProvider = CLKSimpleTextProvider(text: "TempoRun · 🔥 \(data.streakDays) dias")
            t.body1TextProvider = CLKSimpleTextProvider(
                text: "\(Int(data.weeklyKm)) / \(Int(data.weeklyGoalKm)) km esta semana"
            )
            let next = data.nextWorkoutDay.isEmpty
                ? "Sem treino programado"
                : "\(data.nextWorkoutDay): \(data.nextWorkoutType) · \(String(format: "%.1f", data.nextWorkoutKm)) km"
            t.body2TextProvider = CLKSimpleTextProvider(text: next)
            return t

        // ── Graphic Bezel ──────────────────────────────────────────────────
        case .graphicBezel:
            let circle = CLKComplicationTemplateGraphicCircularOpenGaugeRangeText()
            circle.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(data.weeklyKm))")
            circle.leadingTextProvider = CLKSimpleTextProvider(text: "km")
            circle.trailingTextProvider = CLKSimpleTextProvider(text: "🔥")
            circle.gaugeProvider = CLKSimpleGaugeProvider(
                style: .ring,
                gaugeColor: UIColor(Color.tempoOrange),
                fillFraction: Float(data.weeklyProgress)
            )
            let t = CLKComplicationTemplateGraphicBezelCircularText()
            t.circularTemplate = circle
            t.textProvider = CLKSimpleTextProvider(
                text: "\(Int(data.weeklyKm))/\(Int(data.weeklyGoalKm)) km · streak \(data.streakDays)d"
            )
            return t

        // ── Graphic Extra Large ────────────────────────────────────────────
        case .graphicExtraLarge:
            let t = CLKComplicationTemplateGraphicExtraLargeCircularOpenGaugeRangeText()
            t.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(data.weeklyKm))")
            t.leadingTextProvider = CLKSimpleTextProvider(text: "km")
            t.trailingTextProvider = CLKSimpleTextProvider(text: "🔥\(data.streakDays)")
            t.gaugeProvider = CLKSimpleGaugeProvider(
                style: .ring,
                gaugeColor: UIColor(Color.tempoOrange),
                fillFraction: Float(data.weeklyProgress)
            )
            return t

        default:
            return nil
        }
    }

    // MARK: - Refresh

    func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Void) {
        // Atualiza a cada 30 minutos
        handler(Date(timeIntervalSinceNow: 30 * 60))
    }
}
