import SwiftUI
import CultureCore

struct ContentCardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let card: ContentCard
    var compact = false
    @State private var cardLanguage: AppLanguage?
    @State private var likeBounce = false

    private var language: AppLanguage { cardLanguage ?? settings.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                ImageCarousel(images: card.images, aspectRatio: compact ? 4.0 / 5.0 : 1, language: language) {
                    TopicArtwork(topic: card.topic)
                }
                HStack {
                    TopicBadge(topic: card.topic).background(.thinMaterial, in: Capsule())
                    Spacer()
                    if card.editorial.status != .published { InReviewBanner().background(.thinMaterial, in: Capsule()) }
                }
                .padding(12)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.cornerRadius, topTrailingRadius: Theme.cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(card.title[language]).font(.title3.weight(.semibold)).fontDesign(.serif)
                        .foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    LanguageToggle(language: Binding(get: { language }, set: { cardLanguage = $0 }))
                }
                if let book = card.book {
                    BookHeader(book: book)
                }
                Text(card.body[language])
                    .font(.body)
                    .foregroundStyle(Theme.ink.opacity(0.88))
                    .lineLimit(compact ? 4 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                if let book = card.book, let quote = book.quote, !compact {
                    BookQuote(book: book, quote: quote, language: language)
                }
                TakeawayView(text: card.takeaway[language])
                if card.kind == .timeline, let timeline = card.timeline, !compact {
                    CardTimeline(items: timeline, language: language)
                }
                if !compact {
                    ForEach(Array(card.images.enumerated()), id: \.offset) { _, image in
                        Text("\(image.credit) · \(image.license)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                actionBar
            }
            .padding(14)
        }
        .themedSurface()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .contain)
    }

    private var actionBar: some View {
        HStack(spacing: 22) {
            let liked = store.isLiked(card.id)
            Button {
                store.toggleLike(card.id)
                Haptics.like()
                likeBounce.toggle()
            } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .foregroundStyle(liked ? Theme.oxblood : Theme.ink)
                    .symbolEffect(.bounce, value: likeBounce)
            }
            .accessibilityLabel(settings.t(liked ? "action.unlike" : "action.like"))

            let saved = store.isSaved(card.id, kind: .card)
            Button { store.toggleSave(card.id, kind: .card) } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
            }
            .accessibilityLabel(settings.t(saved ? "action.unsave" : "action.save"))

            ShareLink(item: URL(string: "https://\(BuildConfiguration.universalLinkHost)/card/\(card.id)")!,
                      subject: Text(card.title[language]),
                      message: Text("\(card.title[language]) — \(card.takeaway[language])")) {
                Image(systemName: "paperplane")
            }
            .accessibilityLabel(settings.t("action.share"))
            Spacer()
            if card.quiz != nil {
                Label(settings.t("card.quizCTA"), systemImage: "questionmark.circle").font(.footnote.weight(.semibold))
                    .foregroundStyle(card.topic.tint)
            }
        }
        .font(.system(size: 19, weight: .light))
        .foregroundStyle(Theme.ink)
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

struct TakeawayView: View {
    @Environment(AppSettings.self) private var settings
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: settings.t("card.takeaway"))
            Text(text).font(.callout.italic()).fontDesign(.serif).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.gold).frame(width: 1.5) }
        .accessibilityElement(children: .combine)
    }
}

struct CardTimeline: View {
    let items: [TimelineItem]
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(Color.accentColor).frame(width: 10, height: 10)
                        if index < items.count - 1 { Rectangle().fill(Color.accentColor.opacity(0.3)).frame(width: 2) }
                    }
                    .frame(width: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.date).font(.caption.weight(.bold).monospacedDigit())
                        Text(item.label[language]).font(.subheadline)
                    }
                    .padding(.bottom, 12)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Niccolò Machiavelli · 1513 · Il Principe"
struct BookHeader: View {
    let book: BookInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(book.author).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.gold)
            Text("\(book.originalTitle) · \(book.year)").font(.caption.italic()).fontDesign(.serif).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Quotation in the original language, with its translation underneath.
struct BookQuote: View {
    @Environment(AppSettings.self) private var settings
    let book: BookInfo
    let quote: String
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: settings.t("book.quote"))
            Text("« \(quote) »").font(.title3.italic()).fontDesign(.serif).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let translation = book.quoteTranslation, translation[language] != quote {
                Text(translation[language]).font(.callout).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let source = book.quoteSource {
                Text("— \(book.author), \(source)").font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
