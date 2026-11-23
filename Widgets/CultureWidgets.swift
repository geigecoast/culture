import WidgetKit
import SwiftUI

// Phase 2 deliverable, scaffolded now: Mot du jour, streak and next event.
// Data comes from the JSON snapshot the app writes into the App Group (WidgetSnapshot.swift).

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: WidgetSnapshot(
            word: .init(term: "ostensiblement", definition: "De façon visible, sans chercher à le cacher.", register: "soutenu"),
            streak: 7, nextEvent: nil, language: "fr"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

private func label(_ fr: String, _ en: String, _ snapshot: WidgetSnapshot?) -> String {
    snapshot?.language == "en" ? en : fr
}

struct WordOfDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        if let word = entry.snapshot?.word {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading) {
                    Text(word.term).font(.headline)
                    Text(word.definition).font(.caption).lineLimit(2)
                }
            case .accessoryInline:
                Text(word.term)
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text(label("Mot du jour", "Word of the day", entry.snapshot)).font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                    Text(word.term).font(.title2.bold()).fontDesign(.serif).minimumScaleFactor(0.6)
                    Text(word.definition).font(.footnote).lineLimit(family == .systemSmall ? 3 : 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Culture").font(.headline)
        }
    }
}

struct StreakWidgetView: View {
    let entry: SnapshotEntry
    var body: some View {
        VStack {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("\(entry.snapshot?.streak ?? 0)").font(.title.bold().monospacedDigit())
            Text(label("jours", "days", entry.snapshot)).font(.caption2)
        }
    }
}

struct NextEventWidgetView: View {
    let entry: SnapshotEntry
    var body: some View {
        if let event = entry.snapshot?.nextEvent {
            VStack(alignment: .leading, spacing: 4) {
                if event.cancelled {
                    Text(label("ANNULÉ", "CANCELLED", entry.snapshot)).font(.caption2.weight(.heavy)).foregroundStyle(.red)
                }
                Text(event.title).font(.headline).lineLimit(2)
                Text(event.venue).font(.caption).foregroundStyle(.secondary)
                Text(formatted(event)).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(label("Aucun événement prévu", "No upcoming event", entry.snapshot)).font(.footnote)
        }
    }

    private func formatted(_ event: WidgetSnapshot.NextEvent) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style.timeZone = TimeZone(identifier: event.timeZoneID) ?? .current
        style.locale = Locale(identifier: entry.snapshot?.language ?? "fr")
        return event.start.formatted(style)
    }
}

struct WordOfDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfDay", provider: SnapshotProvider()) { entry in
            WordOfDayWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Mot du jour")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular, .accessoryInline])
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Streak", provider: SnapshotProvider()) { entry in
            StreakWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Série")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct NextEventWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextEvent", provider: SnapshotProvider()) { entry in
            NextEventWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prochain événement")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct CultureWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordOfDayWidget()
        StreakWidget()
        NextEventWidget()
    }
}
