import SwiftUI
import CultureCore

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Binding var topicFilter: Topic?
    @State private var feed: FeedTab = .forYou
    @State private var showQuiz = false
    @State private var quizTopic: Topic?
    @State private var showWord = false
    /// Frozen ranking: recomputed on load and pull-to-refresh only, so marking cards as seen,
    /// liking them or switching language never reorders the feed under the user's thumb.
    @State private var feedOrder: [String] = []

    enum FeedTab: Hashable { case forYou, following }

    private var cards: [ContentCard] {
        var list = feedOrder.compactMap(model.card)
        if feed == .following, !settings.interests.isEmpty { list = list.filter { settings.interests.contains($0.topic) } }
        if let topicFilter { list = list.filter { $0.topic == topicFilter } }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                QuizStoriesRow(onQuiz: { topic in quizTopic = topic; showQuiz = true }, onWord: { showWord = true })
                Picker("", selection: $feed) {
                    Text(settings.t("home.forYou")).tag(FeedTab.forYou)
                    Text(settings.t("home.following")).tag(FeedTab.following)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if cards.isEmpty {
                    ContentUnavailableView(settings.t("home.empty.title"), systemImage: "sparkles",
                                           description: Text(settings.t("home.empty.message")))
                } else if sizeClass == .regular {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 16)], spacing: 16) {
                        ForEach(cards) { card in feedItem(card) }
                    }
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(cards) { card in feedItem(card) }
                    }
                    .padding(.horizontal, 12)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await model.refreshContent()
            feedOrder = model.feedCards.map(\.id)
        }
        .task(id: model.content.version) {
            // New content version (first load or refresh): rank once.
            feedOrder = model.feedCards.map(\.id)
        }
        .navigationDestination(for: String.self) { id in
            if let card = model.card(id) { CardDetailView(card: card) }
        }
        .navigationTitle(topicFilter.map { settings.t($0.localizationKey) } ?? "Culture")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.isSearchPresented = true } label: { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(settings.t("menu.search"))
            }
        }
        .fullScreenCover(isPresented: $showQuiz) {
            QuizFeedView(cards: model.quizCards.filter { quizTopic == nil || $0.topic == quizTopic })
        }
        .sheet(isPresented: $showWord) {
            if let word = model.wordOfTheDay {
                NavigationStack { ScrollView { VocabCardView(entry: word, revealed: true).padding() }
                    .navigationTitle(settings.t("vocab.wordOfDay")) }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func feedItem(_ card: ContentCard) -> some View {
        NavigationLink(value: card.id) {
            ContentCardView(card: card, compact: true)
        }
        .buttonStyle(.plain)
        .onAppear {
            model.store.markSeen(card.id)
            prefetch(after: card)
        }
    }

    private func prefetch(after card: ContentCard) {
        guard let index = cards.firstIndex(of: card) else { return }
        let upcoming = cards.dropFirst(index + 1).prefix(4).compactMap { $0.image?.url }
        Task { await ImageCache.shared.prefetch(upcoming, maxPixelSize: 1200) }
    }
}

/// Instagram-style circular row. Phase 1: quick quizzes and Mot du jour.
/// Phase 2 will add real stories (4–6 slides + final quiz) to the same row.
struct QuizStoriesRow: View {
    @Environment(AppSettings.self) private var settings
    var onQuiz: (Topic?) -> Void
    var onWord: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                bubble(title: settings.t("home.quizAll"), symbol: "bolt.fill", tint: .yellow) { onQuiz(nil) }
                    .accessibilityIdentifier("quiz.all")
                bubble(title: settings.t("vocab.wordOfDay"), symbol: Topic.vocabulary.symbolName, tint: Topic.vocabulary.tint, action: onWord)
                ForEach(Topic.feedTopics) { topic in
                    bubble(title: settings.t(topic.localizationKey), symbol: topic.symbolName, tint: topic.tint) { onQuiz(topic) }
                }
            }
            .padding(.horizontal)
        }
    }

    private func bubble(title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(tint.gradient, in: Circle())
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.orange, .pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3).padding(-4))
                Text(title).font(.caption2).lineLimit(1).frame(width: 76)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
