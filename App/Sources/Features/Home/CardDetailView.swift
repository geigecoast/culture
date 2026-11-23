import SwiftUI
import CultureCore

struct CardDetailView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    let card: ContentCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if sizeClass == .regular && settings.showBothLanguagesOnIPad {
                    HStack(alignment: .top, spacing: 16) {
                        LanguageColumn(card: card, language: .fr)
                        LanguageColumn(card: card, language: .en)
                    }
                } else {
                    ContentCardView(card: card)
                }
                if let quiz = card.quiz {
                    QuizCardView(quiz: quiz, topic: card.topic, itemID: card.id, style: .inline)
                }
                SourcesSection(editorial: card.editorial, factsAsOf: card.factsAsOf)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(card.title[settings.language])
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if sizeClass == .regular {
                Toggle(isOn: Binding(get: { settings.showBothLanguagesOnIPad }, set: { settings.showBothLanguagesOnIPad = $0 })) {
                    Label(settings.t("card.sideBySide"), systemImage: "rectangle.split.2x1")
                }
            }
        }
    }
}

private struct LanguageColumn: View {
    let card: ContentCard
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.rawValue.uppercased()).font(.caption.weight(.heavy)).foregroundStyle(.secondary)
            Text(card.title[language]).font(.title2.bold())
            Text(card.body[language])
            Text(card.takeaway[language]).font(.callout.weight(.semibold))
            if let timeline = card.timeline { CardTimeline(items: timeline, language: language) }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .environment(\.locale, language.locale)
    }
}
