import SwiftUI
import CultureCore

/// One question, instant feedback, one-line explanation.
struct QuizCardView: View {
    enum Style { case inline, fullScreen }
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let quiz: MicroQuiz
    let topic: Topic
    let itemID: String
    var style: Style = .inline
    var onAnswered: ((Bool) -> Void)?
    @State private var selected: Int?
    @FocusState private var focused: Bool
    @State private var highlighted = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TopicBadge(topic: topic)
            Text(quiz.question[settings.language])
                .font(style == .fullScreen ? .title2.weight(.bold) : .headline)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(quiz.options.enumerated()), id: \.offset) { index, option in
                Button { answer(index) } label: {
                    HStack {
                        Text(option[settings.language]).multilineTextAlignment(.leading)
                        Spacer()
                        if let selected, index == quiz.answerIndex { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        else if selected == index { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(for: index), in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(highlighted == index && focused ? Color.accentColor : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(selected != nil)
                .accessibilityIdentifier("quiz.option.\(index)")
                .accessibilityValue(accessibilityValue(for: index))
            }
            if let selected {
                let correct = quiz.isCorrect(selected)
                Label(settings.t(correct ? "quiz.correct" : "quiz.incorrect"), systemImage: correct ? "hand.thumbsup.fill" : "lightbulb")
                    .font(.headline)
                    .foregroundStyle(correct ? .green : .orange)
                    .accessibilityIdentifier("quiz.feedback")
                Text(quiz.explanation[settings.language]).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        // Hardware keyboard: arrows move, Return answers.
        .focusable()
        .focused($focused)
        .onKeyPress(.downArrow) { highlighted = min(highlighted + 1, quiz.options.count - 1); return .handled }
        .onKeyPress(.upArrow) { highlighted = max(highlighted - 1, 0); return .handled }
        .onKeyPress(.return) { answer(highlighted); return .handled }
    }

    private func answer(_ index: Int) {
        guard selected == nil else { return }
        selected = index
        let correct = quiz.isCorrect(index)
        correct ? Haptics.success() : Haptics.error()
        store.recordQuiz(topic: topic, itemID: itemID, correct: correct)
        UIAccessibility.post(notification: .announcement, argument: settings.t(correct ? "quiz.correct" : "quiz.incorrect"))
        onAnswered?(correct)
    }

    private func background(for index: Int) -> Color {
        guard let selected else { return Color.secondary.opacity(0.1) }
        if index == quiz.answerIndex { return .green.opacity(0.2) }
        if index == selected { return .red.opacity(0.2) }
        return Color.secondary.opacity(0.06)
    }

    private func accessibilityValue(for index: Int) -> String {
        guard selected != nil else { return "" }
        if index == quiz.answerIndex { return settings.t("quiz.a11y.correctAnswer") }
        if index == selected { return settings.t("quiz.a11y.yourAnswer") }
        return ""
    }
}

/// Full-screen vertical quiz feed. Swipe up (or press ↓ / Space) for the next question.
struct QuizFeedView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let cards: [ContentCard]
    @State private var position: String?
    @State private var score = 0
    @State private var answered = 0

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(settings.t("quiz.empty"), systemImage: "questionmark.circle")
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(cards) { card in
                                if let quiz = card.quiz {
                                    VStack {
                                        Spacer()
                                        QuizCardView(quiz: quiz, topic: card.topic, itemID: card.id, style: .fullScreen) { correct in
                                            answered += 1
                                            if correct { score += 1 }
                                        }
                                        .frame(maxWidth: 600)
                                        Spacer()
                                        Label(settings.t("quiz.swipeHint"), systemImage: "chevron.up")
                                            .font(.footnote).foregroundStyle(.secondary)
                                            .accessibilityHidden(true)
                                    }
                                    .padding()
                                    .containerRelativeFrame(.vertical)
                                    .id(card.id)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $position)
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                }
            }
            .background(Theme.background)
            .navigationTitle(settings.t("quiz.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.close")) { dismiss() }.accessibilityIdentifier("quiz.close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(settings.t("quiz.score", score, answered)).font(.subheadline.monospacedDigit())
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button { move(1) } label: { Label(settings.t("quiz.next"), systemImage: "arrow.down") }
                        .accessibilityIdentifier("quiz.next")
                }
            }
        }
    }

    private func move(_ delta: Int) {
        let ids = cards.filter { $0.quiz != nil }.map(\.id)
        let current = position.flatMap { ids.firstIndex(of: $0) } ?? 0
        let next = min(max(current + delta, 0), ids.count - 1)
        withAnimation { position = ids[next] }
    }
}
