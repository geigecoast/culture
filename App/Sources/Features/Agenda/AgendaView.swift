import SwiftUI
import MapKit
import CultureCore

/// Shared agenda state: filter + derived events.
@Observable
@MainActor
final class AgendaState {
    enum Mode: String, CaseIterable { case list, week, map }
    var mode: Mode = .list
    var categories: Set<EventCategory> = []
    var freeOnly = false
    var days = EventFilter.defaultDays
    var selectedEventID: String?

    func filter(cityIDs: Set<String>) -> EventFilter {
        EventFilter(cityIDs: cityIDs, categories: categories, freeOnly: freeOnly, days: days)
    }
}

struct AgendaView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var state = AgendaState()

    var body: some View {
        AgendaContent(state: state) { event in
            NavigationLink(value: event.id) { EventRowView(event: event) }
        }
        .navigationTitle(settings.t("tab.agenda"))
        .navigationDestination(for: String.self) { id in
            if let event = model.event(id) { EventDetailView(event: event) }
        }
    }
}

/// iPad: event list on the left, details on the right.
struct AgendaSplitView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var state = AgendaState()

    var body: some View {
        HStack(spacing: 0) {
            NavigationStack {
                AgendaContent(state: state) { event in
                    Button { state.selectedEventID = event.id } label: { EventRowView(event: event) }
                        .buttonStyle(.plain)
                        .listRowBackground(state.selectedEventID == event.id ? Color.accentColor.opacity(0.12) : nil)
                }
                .navigationTitle(settings.t("tab.agenda"))
            }
            .frame(minWidth: 320, idealWidth: 420, maxWidth: 480)
            Divider()
            NavigationStack {
                if let id = state.selectedEventID, let event = model.event(id) {
                    EventDetailView(event: event).id(id)
                } else {
                    ContentUnavailableView(settings.t("agenda.selectEvent"), systemImage: "calendar")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct AgendaContent<Row: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Bindable var state: AgendaState
    @ViewBuilder var row: (CulturalEvent) -> Row
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private var events: [CulturalEvent] {
        state.filter(cityIDs: settings.cityIDs).apply(to: model.content.events, now: .now)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(settings.t("agenda.mode"), selection: $state.mode) {
                Text(settings.t("agenda.mode.list")).tag(AgendaState.Mode.list)
                Text(settings.t("agenda.mode.week")).tag(AgendaState.Mode.week)
                Text(settings.t("agenda.mode.map")).tag(AgendaState.Mode.map)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            FilterBar(state: state)

            if events.isEmpty {
                emptyState
            } else {
                switch state.mode {
                case .list: listView(events)
                case .week: weekView
                case .map: AgendaMapView(events: events, row: row)
                }
            }
        }
        .refreshable { await model.refreshContent() }
    }

    private func listView(_ events: [CulturalEvent]) -> some View {
        List {
            ForEach(EventSchedule().groupedByDay(events), id: \.dayKey) { group in
                Section(dayTitle(group.events[0])) {
                    ForEach(group.events) { row($0) }
                }
            }
        }
        .listStyle(.plain)
    }

    private var weekView: some View {
        let calendar = Calendar.current
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: .now)) }
        let dayEvents = events.filter { event in
            let c = EventSchedule().localDay(of: event)
            let d = calendar.dateComponents([.year, .month, .day], from: selectedDay)
            return c.year == d.year && c.month == d.month && c.day == d.day
        }
        return VStack(spacing: 0) {
            HStack {
                ForEach(days, id: \.self) { day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
                    Button { selectedDay = day } label: {
                        VStack(spacing: 2) {
                            Text(day.formatted(.dateTime.weekday(.abbreviated).locale(settings.language.locale))).font(.caption2)
                            Text(day.formatted(.dateTime.day())).font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(settings.language.locale)))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            if dayEvents.isEmpty {
                ContentUnavailableView(settings.t("agenda.noEventsThatDay"), systemImage: "calendar")
            } else {
                List(dayEvents) { row($0) }.listStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        let suggestions = state.filter(cityIDs: settings.cityIDs).wideningSuggestions(allCityIDs: Set(model.content.cities.map(\.id)))
        return ContentUnavailableView {
            Label(settings.t("agenda.empty.title"), systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text(settings.t("agenda.empty.message"))
        } actions: {
            ForEach(suggestions, id: \.self) { suggestion in
                switch suggestion {
                case .extendDays(let days):
                    Button(settings.t("agenda.empty.extend", days)) { state.days = days }
                case .clearCategories:
                    Button(settings.t("agenda.empty.clearFilters")) { state.categories = []; state.freeOnly = false }
                case .addCity:
                    Menu(settings.t("agenda.empty.addCity")) {
                        ForEach(model.content.cities.filter { !settings.cityIDs.contains($0.id) }) { city in
                            Button(city.name[settings.language]) { settings.cityIDs.insert(city.id) }
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func dayTitle(_ event: CulturalEvent) -> String {
        var style = Date.FormatStyle(date: .complete, time: .omitted)
        style.timeZone = event.timeZone
        style.locale = settings.language.locale
        return event.start.formatted(style).capitalized(with: settings.language.locale)
    }
}

private struct FilterBar: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Bindable var state: AgendaState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Cities: one tap to add or remove (at least one stays selected).
                ForEach(model.content.cities) { city in
                    Chip(title: city.name[settings.language], systemImage: "mappin", isOn: settings.cityIDs.contains(city.id)) {
                        if settings.cityIDs.contains(city.id) {
                            if settings.cityIDs.count > 1 { settings.cityIDs.remove(city.id) }
                        } else {
                            settings.cityIDs.insert(city.id)
                        }
                    }
                    .accessibilityIdentifier("city.\(city.id)")
                }
                Divider().frame(height: 24)
                Chip(title: settings.t("category.free"), systemImage: "eurosign.circle", isOn: state.freeOnly) { state.freeOnly.toggle() }
                ForEach(EventCategory.allCases) { category in
                    Chip(title: settings.t(category.localizationKey), isOn: state.categories.contains(category)) {
                        if state.categories.contains(category) { state.categories.remove(category) } else { state.categories.insert(category) }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct AgendaMapView<Row: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let events: [CulturalEvent]
    @ViewBuilder var row: (CulturalEvent) -> Row
    @State private var selectedVenue: Venue?

    var body: some View {
        let venues = Set(events.map(\.venueID)).compactMap(model.content.venue)
        Map {
            ForEach(venues) { venue in
                Annotation(venue.name, coordinate: CLLocationCoordinate2D(latitude: venue.latitude, longitude: venue.longitude)) {
                    Button { selectedVenue = venue } label: {
                        Image(systemName: "theatermasks.fill")
                            .padding(8)
                            .background(Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(venue.name)
                }
            }
        }
        .sheet(item: $selectedVenue) { venue in
            NavigationStack {
                List(events.filter { $0.venueID == venue.id }) { row($0) }
                    .navigationTitle(venue.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: String.self) { id in
                        if let event = model.event(id) { EventDetailView(event: event) }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
