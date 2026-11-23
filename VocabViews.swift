import SwiftUI
import CultureCore

struct VocabHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    @State private var reviewing = false
    /// Frozen when the session starts so grading does not reshuffle the running session.
    @State private var sessionQueue: [VocabEntry] = []

    var body: some View {
        let queue = store.reviewQueue(from: model.content.vocab)
        List {
            if let word = model.wordOfTheDay {
                Section(settings.t("vocab.wordOfDay")) {
                    VocabCardView(entry: word, revealed: true)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Button {
                    sessionQueue = queue
                    reviewing = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack.badge.play").font(.title2)
                        VStack(alignment: .leading) {
                            Text(settings.t("vocab.startReview")).font(.headline)
                            Text(settings.t("vocab.dueCount", queue.count)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(queue.isEmpty)
                .accessibilityIdentifier("vocab.startReview")
            }
            Section(settings.t("vocab.sets")) {
                ForEach(model.content.vocabSets) { set in
                    NavigationLink {
                        VocabSetView(set: set)
                    } label: {
                        HStack {
                            Text(set.title[settings.language])
                            Spacer()
                            Text("\(model.content.vocab.filter { $0.sets.contains(set.id) }.count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(settings.t("tab.vocabulary"))
        .fullScreenCover(isPresented: $reviewing) { ReviewSessionView(queue: sessionQueue) }
        .sheet(item: Binding(get: { model.presentedVocabID.map(IdentifiedString.init) }, set: { model.presentedVocabID = $0?.id })) { item in
            if let entry = model.vocab(item.id) { ScrollView { VocabCardView(entry: entry, revealed: true).padding() } }
        }
    }
}

struct VocabSetView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    let set: VocabSet

    var body: some View {
        let entries = model.content.vocab.filter { $0.sets.contains(set.id) }
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                ForEach(entries) { VocabCardView(entry: $0, revealed: true) }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(set.title[settings.language])
    }
}

/// "Le mot juste" card: French first, English gloss on demand.
struct VocabCardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let entry: VocabEntry
    var revealed: Bool
    @State private var showGloss = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.term).font(.title.weight(.bold)).fontDesign(.serif)
                Text(entry.partOfSpeech).font(.subheadline.italic()).foregroundStyle(.secondary)
                Spacer()
                RegisterTag(register: entry.register)
            }
            if revealed {
                Text(entry.definition).font(.body)
                if showGloss {
                    Text("EN — \(entry.gloss)").font(.callout).foregroundStyle(.secondary)
                } else {
                    Button(settings.t("vocab.showGloss")) { showGloss = true }.font(.footnote)
                }
                Text("« \(entry.example) »").font(.callout.italic()).fontDesign(.serif)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Topic.vocabulary.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                if !entry.nuances.isEmpty {
                    Text(settings.t("vocab.nuances")).font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                    ForEach(entry.nuances, id: \.word) { nuance in
                        (Text(nuance.word).bold() + Text(" — ") + Text(nuance.note[settings.language])).font(.callout)
                    }
                }
                if !entry.pitfalls.isEmpty {
                    Text(settings.t("vocab.pitfalls")).font(.caption.weight(.heavy)).textCase(.uppercase).foregroundStyle(.secondary)
                    ForEach(entry.pitfalls, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.callout) }
                }
                if let etymology = entry.etymology {
                    Text(settings.t("vocab.etymology") + " : " + etymology).font(.footnote).foregroundStyle(.secondary)
                }
                HStack {
                    if entry.editorial.status != .published { InReviewBanner() }
                    Spacer()
                    if let due = store.reviewState(for: entry.id)?.due {
                        Text(settings.t("vocab.nextReview", due.formatted(.dateTime.day().month().locale(settings.language.locale))))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

struct RegisterTag: View {
    @Environment(AppSettings.self) private var settings
    let register: Register
    var body: some View {
        Label(settings.t(register.localizationKey), systemImage: register.isWarning ? "exclamationmark.triangle.fill" : "textformat")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background((register.isWarning ? Color.red : Topic.vocabulary.tint).opacity(0.14), in: Capsule())
            .foregroundStyle(register.isWarning ? .red : Topic.vocabulary.tint)
    }
}

/// Flashcard review session with the three self-assessments and an optional production exercise.
struct ReviewSessionView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let queue: [VocabEntry]
    @State private var index = 0
    @State private var revealed = false
    @State private var lastScheduled: Date?
    @State private var answer = ""
    @State private var exerciseChecked = false

    var body: some View {
        NavigationStack {
            Group {
                if index < queue.count {
                    let entry = queue[index]
                    ScrollView {
                        VStack(spacing: 20) {
                            ProgressView(value: Double(index), total: Double(queue.count))
                                .accessibilityLabel(settings.t("vocab.progress", index + 1, queue.count))
                            VocabCardView(entry: entry, revealed: revealed)
                            if let exercise = entry.exercise, revealed { exerciseView(exercise) }
                            if revealed {
                                gradeButtons(entry)
                            } else {
                                Button(settings.t("vocab.reveal")) { withAnimation { revealed = true } }
                                    .buttonStyle(.borderedProminent).controlSize(.large)
                                    .keyboardShortcut(.space, modifiers: [])
                                    .accessibilityIdentifier("vocab.reveal")
                            }
                        }
                        .padding()
                        .frame(maxWidth: 700)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ContentUnavailableView {
                        Label(settings.t("vocab.sessionDone"), systemImage: "checkmark.seal.fill")
                    } description: {
                        Text(settings.t("vocab.sessionDoneMessage", queue.count))
                    } actions: {
                        Button(settings.t("common.close")) { dismiss() }.buttonStyle(.borderedProminent)
                    }
                    .onAppear { if !queue.isEmpty { store.record(.reviewSessionCompleted) } }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(settings.t("vocab.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(settings.t("common.close")) { dismiss() } } }
        }
    }

    private func gradeButtons(_ entry: VocabEntry) -> some View {
        HStack(spacing: 10) {
            gradeButton(.hard, entry: entry, tint: .red, key: "1")
            gradeButton(.review, entry: entry, tint: .orange, key: "2")
            gradeButton(.known, entry: entry, tint: .green, key: "3")
        }
    }

    private func gradeButton(_ grade: ReviewGrade, entry: VocabEntry, tint: Color, key: Character) -> some View {
        Button {
            let state = store.grade(entry.id, grade)
            lastScheduled = state.due
            UIAccessibility.post(notification: .announcement,
                                 argument: settings.t("vocab.nextReview", state.due.formatted(.dateTime.day().month().locale(settings.language.locale))))
            Haptics.selection()
            withAnimation {
                index += 1
                revealed = false
                answer = ""
                exerciseChecked = false
            }
        } label: {
            Text(settings.t(grade.localizationKey)).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .keyboardShortcut(KeyEquivalent(key), modifiers: [])
        .accessibilityIdentifier("grade.\(grade.rawValue)")
    }

    @ViewBuilder
    private func exerciseView(_ exercise: ProductionExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(settings.t(exercise.kind == .complete ? "exercise.complete" : "exercise.rewrite")).font(.headline)
            Text(exercise.prompt).font(.callout.italic())
            TextField(settings.t("exercise.placeholder"), text: $answer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Button(settings.t("exercise.check")) { exerciseChecked = true }.disabled(answer.isEmpty)
            if exerciseChecked {
                let ok = exercise.kind == .complete && exercise.answers.contains { normalize($0) == normalize(answer) }
                if exercise.kind == .complete {
                    Label(settings.t(ok ? "quiz.correct" : "quiz.incorrect"), systemImage: ok ? "checkmark" : "xmark")
                        .foregroundStyle(ok ? .green : .orange)
                }
                Text(settings.t("exercise.modelAnswer") + " " + (exercise.answers.first ?? "")).font(.callout)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr"))
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
