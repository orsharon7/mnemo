import SwiftUI
import AppKit

enum StatsRange: String, CaseIterable, Identifiable {
    case week = "Last 7 Days"
    case month = "This Month"
    case allTime = "All Time"

    var id: String { rawValue }

    func startDate(now: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .week:
            return cal.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 24 * 3600)
        case .month:
            return cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now.addingTimeInterval(-30 * 24 * 3600)
        case .allTime:
            return nil
        }
    }

    func contains(_ d: Date, now: Date = Date()) -> Bool {
        guard let start = startDate(now: now) else { return true }
        return d >= start
    }
}

struct StatsView: View {
    @ObservedObject var store: HistoryStore
    @State private var range: StatsRange = .week

    @State private var now: Date = Date()

    private var filtered: [ClipEntry] {
        store.entries.filter { range.contains($0.lastUsedAt, now: now) }
    }

    private var topClips: [ClipEntry] {
        Array(filtered.sorted { $0.copyCount > $1.copyCount }.prefix(10))
    }

    private var captureRate: Double {
        let span: Double
        let capturedInRange: Int
        let cal = Calendar.current
        if range == .allTime {
            guard let oldest = store.entries.map({ $0.createdAt }).min() else { return 0 }
            let days = cal.dateComponents([.day], from: oldest, to: now).day ?? 0
            span = max(1, Double(days))
            capturedInRange = store.entries.count
        } else if range == .week {
            span = 7
            guard let rangeStart = range.startDate(now: now) else { return 0 }
            capturedInRange = store.entries.filter { $0.createdAt >= rangeStart }.count
        } else {
            guard let rangeStart = range.startDate(now: now) else { return 0 }
            let days = cal.dateComponents([.day], from: rangeStart, to: now).day ?? 0
            span = max(1, Double(days))
            capturedInRange = store.entries.filter { $0.createdAt >= rangeStart }.count
        }
        return Double(capturedInRange) / span
    }

    /// 24-bucket histogram of `lastUsedAt` hours within the selected range.
    private var hourHistogram: [Int] {
        var buckets = Array(repeating: 0, count: 24)
        let cal = Calendar.current
        for e in filtered {
            let h = cal.component(.hour, from: e.lastUsedAt)
            if h >= 0 && h < 24 { buckets[h] += 1 }
        }
        return buckets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Stats")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Picker("Time Range", selection: $range) {
                    ForEach(StatsRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summaryRow
                    heatmapSection
                    topClipsSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear { now = Date() }
        .onChange(of: range) { _, _ in now = Date() }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(label: "Clips", value: "\(filtered.count)")
            StatCard(label: "Capture rate", value: String(format: "%.1f / day", captureRate))
            StatCard(label: "Pinned", value: "\(filtered.filter { $0.isPinned }.count)")
        }
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clips last used by hour")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            let buckets = hourHistogram
            let peak = max(1, buckets.max() ?? 1)

            let peakHour = buckets.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let totalClips = buckets.reduce(0, +)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(buckets[h] == 0 ? 0.10 : 0.25 + 0.65 * Double(buckets[h]) / Double(peak)))
                            .frame(height: max(4, CGFloat(buckets[h]) / CGFloat(peak) * 80))
                            .cornerRadius(2)
                        if h % 3 == 0 {
                            Text("\(h)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(" ").font(.system(size: 9))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                }
            }
            .frame(height: 100)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Clips last used by hour chart")
            .accessibilityValue("Peak hour: \(peakHour):00, total clips: \(totalClips)")
        }
    }

    private var topClipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most used (lifetime copies)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            if topClips.isEmpty {
                Text("Nothing yet in this range.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topClips.enumerated()), id: \.element.id) { idx, entry in
                        TopClipRow(rank: idx + 1, entry: entry)
                        if idx < topClips.count - 1 { Divider() }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
            }
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

private struct TopClipRow: View {
    let rank: Int
    let entry: ClipEntry

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .trailing)
            Text(preview(entry.content))
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(entry.copyCount)×")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.15))
                )
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func preview(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(of: "\n", with: " ⏎ ")
        if collapsed.count <= 100 { return collapsed }
        return String(collapsed.prefix(100)) + "…"
    }
}
