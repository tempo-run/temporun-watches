import WidgetKit
import SwiftUI

private extension Color {
    static let tempoOrange = Color(red: 1.0, green: 0.42, blue: 0.21)
}

// MARK: - Smart Stack Widget (watchOS 10+)

@main
struct TempoRunWidgetBundle: WidgetBundle {
    var body: some Widget {
        TempoRunSmartStackWidget()
    }
}

// MARK: - Entry

struct TempoRunWidgetEntry: TimelineEntry {
    let date: Date
    let data: ComplicationData
}

// MARK: - Provider

struct TempoRunWidgetProvider: TimelineProvider {
    typealias Entry = TempoRunWidgetEntry

    func placeholder(in context: Context) -> Entry {
        var placeholder = ComplicationData()
        placeholder.weeklyKm = 32
        placeholder.weeklyGoalKm = 60
        placeholder.streakDays = 7
        placeholder.nextWorkoutType = "Tempo Run"
        placeholder.nextWorkoutKm = 8
        placeholder.nextWorkoutDay = "Hoje"
        return Entry(date: Date(), data: placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), data: ComplicationData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let data = ComplicationData.load()
        let entry = Entry(date: Date(), data: data)
        // Atualiza a cada 30 minutos
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
}

// MARK: - Smart Stack Widget

struct TempoRunSmartStackWidget: Widget {
    let kind = "TempoRunSmartStack"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoRunWidgetProvider()) { entry in
            SmartStackView(entry: entry)
        }
        .configurationDisplayName("TempoRun")
        .description("Progresso semanal, streak e próximo treino.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Views por família

struct SmartStackView: View {
    @Environment(\.widgetFamily) var family
    let entry: TempoRunWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: RectangularView(data: entry.data)
        case .accessoryCircular:    CircularView(data: entry.data)
        case .accessoryCorner:      CornerView(data: entry.data)
        case .accessoryInline:      InlineView(data: entry.data)
        default:                    RectangularView(data: entry.data)
        }
    }
}

// ── Rectangular (Smart Stack principal) ───────────────────────────────────────

private struct RectangularView: View {
    let data: ComplicationData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Linha 1: Progresso semanal
            HStack(spacing: 4) {
                Image(systemName: "figure.run")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tempoOrange)
                Text("\(Int(data.weeklyKm)) / \(Int(data.weeklyGoalKm)) km")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("🔥\(data.streakDays)d")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }

            // Barra de progresso
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.tempoOrange)
                        .frame(width: geo.size.width * data.weeklyProgress, height: 5)
                }
            }
            .frame(height: 5)

            // Linha 2: Próximo treino
            if !data.nextWorkoutDay.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                    Text("\(data.nextWorkoutDay): \(data.nextWorkoutType)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.gray)
                    if data.nextWorkoutKm > 0 {
                        Text("· \(String(format: "%.0f", data.nextWorkoutKm)) km")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(.black, for: .widget)
    }
}

// ── Circular (watch face / complicação pequena) ────────────────────────────────

private struct CircularView: View {
    let data: ComplicationData

    var body: some View {
        ZStack {
            // Anel de progresso
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: data.weeklyProgress)
                .stroke(Color.tempoOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(data.weeklyKm))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("km")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

// ── Corner ─────────────────────────────────────────────────────────────────────

private struct CornerView: View {
    let data: ComplicationData

    var body: some View {
        ZStack {
            ProgressView(value: data.weeklyProgress)
                .progressViewStyle(.circular)
                .tint(.tempoOrange)
            Image(systemName: "figure.run")
                .foregroundColor(.tempoOrange)
                .font(.system(size: 14, weight: .bold))
        }
        .containerBackground(.black, for: .widget)
    }
}

// ── Inline (watch face texto) ──────────────────────────────────────────────────

private struct InlineView: View {
    let data: ComplicationData

    var body: some View {
        if !data.nextWorkoutDay.isEmpty {
            Label("\(data.nextWorkoutDay): \(data.nextWorkoutType) \(String(format: "%.0f", data.nextWorkoutKm))km",
                  systemImage: "figure.run")
        } else {
            Label("\(Int(data.weeklyKm)) km · 🔥\(data.streakDays)d",
                  systemImage: "figure.run")
        }
    }
}
