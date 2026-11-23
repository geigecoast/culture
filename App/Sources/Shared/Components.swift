import SwiftUI
import SafariServices
import CultureCore

extension Topic {
    /// Muted jewel tones that sit on near-black.
    var tint: Color {
        switch self {
        case .art: Color(red: 0.66, green: 0.29, blue: 0.31)          // oxblood rose
        case .music: Color(red: 0.55, green: 0.42, blue: 0.62)        // amethyst
        case .history: Color(red: 0.76, green: 0.60, blue: 0.36)      // aged gold
        case .politics: Color(red: 0.45, green: 0.55, blue: 0.66)     // slate blue
        case .geopolitics: Color(red: 0.38, green: 0.58, blue: 0.53)  // verdigris
        case .vocabulary: Color(red: 0.72, green: 0.55, blue: 0.42)   // bronze
        }
    }

    /// Dark, vignetted backdrop for cards without an image.
    var gradient: LinearGradient {
        LinearGradient(colors: [tint.opacity(0.28), Color.black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
    }
}

struct TopicBadge: View {
    @Environment(AppSettings.self) private var settings
    let topic: Topic

    var body: some View {
        Label(settings.t(topic.localizationKey), systemImage: topic.symbolName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay(Capsule().strokeBorder(topic.tint.opacity(0.6), lineWidth: 0.75))
            .foregroundStyle(topic.tint)
    }
}

/// FR/EN switch shown on every card. Changes only that card's content language.
struct LanguageToggle: View {
    @Environment(AppSettings.self) private var settings
    @Binding var language: AppLanguage

    var body: some View {
        Picker(settings.t("card.language"), selection: $language) {
            Text("FR").tag(AppLanguage.fr)
            Text("EN").tag(AppLanguage.en)
        }
        .pickerStyle(.segmented)
        .frame(width: 110)
        .accessibilityLabel(settings.t("card.language"))
    }
}

/// Every card shows its sources and its last-reviewed date.
struct SourcesSection: View {
    @Environment(AppSettings.self) private var settings
    let editorial: EditorialInfo
    var factsAsOf: String?
    @State private var browserURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("card.sources"))
            ForEach(editorial.sources, id: \.self) { source in
                if let url = source.url {
                    Button { browserURL = url } label: { sourceLabel(source) }
                        .buttonStyle(.plain)
                        .accessibilityHint(settings.t("a11y.opensBrowser"))
                } else {
                    sourceLabel(source)
                }
            }
            if let factsAsOf {
                Label(settings.t("card.factsAsOf", Self.format(factsAsOf, settings.language)), systemImage: "calendar.badge.clock")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Label(editorial.lastReviewed.map { settings.t("card.lastReviewed", Self.format($0, settings.language)) }
                  ?? settings.t("card.notYetReviewed"), systemImage: "checkmark.seal")
                .font(.footnote)
                .foregroundStyle(editorial.lastReviewed == nil ? .orange : .secondary)
        }
        .sheet(item: $browserURL) { SafariView(url: $0).ignoresSafeArea() }
    }

    private func sourceLabel(_ source: SourceReference) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: source.url == nil ? "book" : "link")
            VStack(alignment: .leading) {
                Text(source.title).font(.subheadline)
                if let publisher = source.publisher { Text(publisher).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    static func format(_ isoDay: String, _ language: AppLanguage) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: isoDay) else { return isoDay }
        var style = Date.FormatStyle(date: .long, time: .omitted)
        style.timeZone = TimeZone(identifier: "UTC")!
        style.locale = language.locale
        return date.formatted(style)
    }
}

/// Shown on content that has not passed human review (only visible in internal builds).
struct InReviewBanner: View {
    @Environment(AppSettings.self) private var settings
    var body: some View {
        Label(settings.t("card.inReview"), systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.orange.opacity(0.12), in: Capsule())
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// In-app browser for official ticket pages and sources (UIKit: SwiftUI has no equivalent).
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Simple wrapping layout for filter chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if rows[rows.count - 1].width + size.width > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

struct Chip: View {
    let title: String
    var systemImage: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isOn ? Theme.gold.opacity(0.18) : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Theme.gold : Theme.hairline, lineWidth: 0.75))
            .foregroundStyle(isOn ? Theme.gold : Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Placeholder used when a card has no licensed image yet.
struct TopicArtwork: View {
    let topic: Topic
    var body: some View {
        ZStack {
            Theme.background
            topic.gradient
            VStack(spacing: 14) {
                Image(systemName: "laurel.leading").font(.system(size: 22, weight: .ultraLight)).foregroundStyle(Theme.gold.opacity(0.7))
                Image(systemName: topic.symbolName)
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(Theme.gold)
                Rectangle().fill(Theme.gold.opacity(0.5)).frame(width: 40, height: 0.5)
            }
            .accessibilityHidden(true)
        }
    }
}
