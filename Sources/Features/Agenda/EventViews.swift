import SwiftUI
import MapKit
import CultureCore

struct EventRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let event: CulturalEvent

    var body: some View {
        let venue = model.content.venue(event.venueID)
        let schedule = EventSchedule()
        HStack(alignment: .top, spacing: 12) {
            CachedImage(url: event.image?.url, maxPixelSize: 300) {
                ZStack { Color.accentColor.opacity(0.15); Image(systemName: event.category.symbol).font(.title2) }
            }
            .frame(width: 76, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if event.status != .scheduled { StatusBanner(event: event) }
                Text(settings.t(event.category.localizationKey)).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                Text(event.title).font(.headline).strikethrough(event.isCancelled).lineLimit(2)
                Text(schedule.formattedStart(event, language: settings.language)).font(.subheadline)
                Text(venue?.name ?? "").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Text(PriceFormatter.string(for: event.price, language: settings.language, freeLabel: settings.t("category.free")))
                        .font(.footnote.weight(.medium))
                    Spacer()
                    RSVPMenu(event: event, compact: true)
                    ShareLink(item: DeepLink.shareURL(forEvent: event.id), message: Text(shareText(event))) {
                        Image(systemName: "paperplane")
                    }
                    .accessibilityLabel(settings.t("action.share"))
                }
                .buttonStyle(.borderless)
                if event.isSample == true { Text(settings.t("agenda.sample")).font(.caption2).foregroundStyle(.orange) }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(venue: venue))
    }

    private func shareText(_ event: CulturalEvent) -> String {
        "\(event.title) — \(EventSchedule().formattedStart(event, language: settings.language))"
    }

    /// VoiceOver announces date, time, venue and price (and status).
    private func accessibilitySummary(venue: Venue?) -> String {
        var parts = [event.title, settings.t(event.category.localizationKey),
                     EventSchedule().formattedStart(event, language: settings.language, dateStyle: .complete),
                     venue?.name ?? "",
                     PriceFormatter.string(for: event.price, language: settings.language, freeLabel: settings.t("category.free"))]
        if event.status != .scheduled { parts.insert(settings.t("status.\(event.status.rawValue)"), at: 0) }
        if let rsvp = store.rsvp(for: event.id) { parts.append(settings.t(rsvp.localizationKey)) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct StatusBanner: View {
    @Environment(AppSettings.self) private var settings
    let event: CulturalEvent
    var body: some View {
        Text(settings.t("status.\(event.status.rawValue)").uppercased())
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(event.isCancelled ? Color.red : .orange, in: Capsule())
            .foregroundStyle(.white)
            .accessibilityIdentifier("event.status")
    }
}

/// "Je participe" with three states: Intéressé, Je participe, Peut-être.
struct RSVPMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let event: CulturalEvent
    var compact = false

    var body: some View {
        let current = store.rsvp(for: event.id)
        Menu {
            ForEach([RSVPState.going, .interested, .maybe], id: \.self) { state in
                Button {
                    model.setRSVP(current == state ? nil : state, for: event)
                } label: {
                    if current == state { Label(settings.t(state.localizationKey), systemImage: "checkmark") }
                    else { Text(settings.t(state.localizationKey)) }
                }
                .accessibilityIdentifier("rsvp.\(state.rawValue)")
            }
            if current != nil {
                Button(settings.t("rsvp.remove"), role: .destructive) { model.setRSVP(nil, for: event) }
            }
        } label: {
            Label(settings.t(current?.localizationKey ?? "rsvp.cta"), systemImage: current == nil ? "hand.raised" : "checkmark.circle.fill")
                .font(compact ? .footnote.weight(.semibold) : .body.weight(.semibold))
        }
        .disabled(event.isCancelled)
        .accessibilityIdentifier("rsvp.menu")
    }
}

struct EventDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let event: CulturalEvent
    @State private var browserURL: URL?
    @State private var reminderSet = false
    @State private var descriptionLanguage: AppLanguage?

    var body: some View {
        let venue = model.content.venue(event.venueID)
        let city = model.content.city(event.cityID)
        let schedule = EventSchedule()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ImageCarousel(images: event.image.map { [$0] } ?? [], aspectRatio: 16.0 / 10.0, language: settings.language) {
                    ZStack { Color.accentColor.opacity(0.15); Image(systemName: event.category.symbol).font(.system(size: 48)) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                if let image = event.image {
                    Text("\(image.credit) · \(image.license)").font(.caption2).foregroundStyle(.secondary)
                }

                if event.status != .scheduled {
                    VStack(alignment: .leading, spacing: 4) {
                        StatusBanner(event: event)
                        if let note = event.statusNote { Text(note[settings.language]).font(.callout) }
                    }
                }
                if event.isSample == true {
                    Label(settings.t("agenda.sampleLong"), systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                }
                Text(settings.t(event.category.localizationKey)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
                Text(event.title).font(.largeTitle.bold()).strikethrough(event.isCancelled)

                VStack(alignment: .leading, spacing: 6) {
                    Label(schedule.formattedStart(event, language: settings.language, dateStyle: .complete), systemImage: "clock")
                    if let end = event.end {
                        Label(settings.t("event.until", schedule.formattedTime(end, in: event.timeZone, language: settings.language)), systemImage: "clock.badge.checkmark")
                    }
                    if let venue { Label("\(venue.name)\n\(venue.address)", systemImage: "mappin.and.ellipse") }
                    Label(PriceFormatter.string(for: event.price, language: settings.language, freeLabel: settings.t("category.free")), systemImage: "eurosign.circle")
                    if TimeZone.current.identifier != event.timeZoneID, let city {
                        Text(settings.t("event.localTimeNote", city.name[settings.language])).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .font(.body)

                HStack {
                    RSVPMenu(event: event).buttonStyle(.borderedProminent)
                    ShareLink(item: DeepLink.shareURL(forEvent: event.id),
                              message: Text("\(event.title) — \(schedule.formattedStart(event, language: settings.language))")) {
                        Label(settings.t("action.share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                if let description = event.description {
                    HStack {
                        Text(settings.t("event.about")).font(.headline)
                        Spacer()
                        LanguageToggle(language: Binding(get: { descriptionLanguage ?? settings.language }, set: { descriptionLanguage = $0 }))
                    }
                    Text(description[descriptionLanguage ?? settings.language])
                }
                if let note = venue?.note {
                    Label(note[settings.language], systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    Button { openDirections(venue) } label: { Label(settings.t("event.directions"), systemImage: "map").frame(maxWidth: .infinity) }
                        .disabled(venue == nil)
                    Button { browserURL = event.officialURL } label: { Label(settings.t("event.officialSite"), systemImage: "ticket").frame(maxWidth: .infinity) }
                        .accessibilityHint(settings.t("a11y.opensBrowser"))
                    Button {
                        Task { reminderSet = await model.notifications.scheduleReminder(for: event, venueName: venue?.name ?? "", settings: settings) }
                    } label: {
                        Label(settings.t(reminderSet ? "event.reminderSet" : "event.reminder"), systemImage: reminderSet ? "bell.fill" : "bell")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(event.isCancelled || reminderSet)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Text(settings.t("event.source", event.sourceName,
                                event.lastChecked.formatted(.dateTime.day().month().hour().minute().locale(settings.language.locale))))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $browserURL) { SafariView(url: $0).ignoresSafeArea() }
    }

    private func openDirections(_ venue: Venue?) {
        guard let venue else { return }
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: venue.latitude, longitude: venue.longitude)))
        item.name = venue.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }
}

extension EventCategory {
    var symbol: String {
        switch self {
        case .operaBallet: "theatermasks"
        case .classical: "music.quarternote.3"
        case .jazzWorld: "music.mic"
        case .theatreDance: "figure.dance"
        case .exhibitions: "photo.artframe"
        case .science: "atom"
        case .literatureCinema: "film"
        }
    }
}
