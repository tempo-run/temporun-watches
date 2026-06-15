import SwiftUI

struct SettingsView: View {
    @StateObject private var prefs = MetricPreferences.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 3) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(.tempoCyan)
                    Text("Métricas")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Escolha \(MetricPreferences.maxSlots) para exibir durante a corrida")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10)

                // Slots selecionados
                VStack(spacing: 4) {
                    ForEach(0..<MetricPreferences.maxSlots, id: \.self) { i in
                        let metric = i < prefs.selected.count ? prefs.selected[i] : nil
                        SlotRow(index: i, metric: metric)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)

                Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 8)

                // Lista completa de métricas
                Text("DISPONÍVEIS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                VStack(spacing: 3) {
                    ForEach(WatchMetric.allCases) { metric in
                        let isSelected = prefs.selected.contains(metric)
                        Button(action: { toggle(metric) }) {
                            HStack(spacing: 8) {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? metric.accentColor : .white.opacity(0.3))
                                    .frame(width: 18)
                                Text(metric.displayName)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.tempoCyan)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected
                                ? Color(red: 0.05, green: 0.09, blue: 0.19)
                                : Color.clear)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func toggle(_ metric: WatchMetric) {
        if let idx = prefs.selected.firstIndex(of: metric) {
            prefs.selected.remove(at: idx)
        } else if prefs.selected.count < MetricPreferences.maxSlots {
            prefs.selected.append(metric)
        }
    }
}

private struct SlotRow: View {
    let index: Int
    let metric: WatchMetric?

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 14)

            if let metric {
                Image(systemName: metric.icon)
                    .font(.system(size: 11))
                    .foregroundColor(metric.accentColor)
                    .frame(width: 16)
                Text(metric.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("— vazio —")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.2))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    metric != nil
                        ? Color(red: 0.48, green: 0.18, blue: 1.0).opacity(0.4)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}
