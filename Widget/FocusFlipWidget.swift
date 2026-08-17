import SwiftUI
import WidgetKit
import ActivityKit

/// Lock screen widget showing today's focus stats.
/// Requires iOS 16+ for WidgetKit families.
@available(iOS 16.0, *)
struct FocusFlipWidget: Widget {

    let kind = "FocusFlipWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusStatsProvider()) { entry in
            FocusStatsWidgetView(entry: entry)
        }
        .configurationDisplayName("今日专注")
        .description("显示今日专注时间和番茄数")
        .supportedFamilies(supportedFamilies())
    }

    private func supportedFamilies() -> [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium]
        if #available(iOS 16.0, *) {
            families.append(contentsOf: [.accessoryRectangular, .accessoryCircular])
        }
        return families
    }
}

// MARK: - Timeline provider

@available(iOS 16.0, *)
struct FocusStatsProvider: TimelineProvider {

    func placeholder(in context: Context) -> FocusStatsEntry {
        FocusStatsEntry(date: Date(), focusMinutes: 100, pomodoroCount: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatsEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> FocusStatsEntry {
        let sessions = PersistenceController.shared.fetchSessions(for: Date())
        let focusSeconds = sessions.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
        let count = sessions.filter { $0.sessionType == .focus }.count
        return FocusStatsEntry(date: Date(), focusMinutes: focusSeconds / 60, pomodoroCount: count)
    }
}

// MARK: - Entry

struct FocusStatsEntry: TimelineEntry {
    let date: Date
    let focusMinutes: Int
    let pomodoroCount: Int
}

// MARK: - Widget view

@available(iOS 16.0, *)
struct FocusStatsWidgetView: View {
    let entry: FocusStatsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text("\(entry.pomodoroCount)")
                    .font(.system(size: 20, weight: .bold))
                Text("🍅")
                    .font(.system(size: 10))
            }
            
        case .accessoryRectangular:
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日专注")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(entry.focusMinutes) 分钟")
                        .font(.headline)
                    Text("\(entry.pomodoroCount) 个番茄")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            
        default:
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日专注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(entry.focusMinutes)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("分钟 · \(entry.pomodoroCount) 个番茄")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red.opacity(0.3))
            }
            .padding()
                    }
    }
}
