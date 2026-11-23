import SwiftUI
import CultureCore

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var step: Step = .welcome
    @State private var locating = false

    enum Step: Int, CaseIterable { case welcome, interests, cities, level, placement, goal, privacy }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                    .padding()
                    .accessibilityLabel(settings.t("onboarding.progress", step.rawValue + 1, Step.allCases.count))
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) { content }
                        .padding()
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                }
                if step != .placement {
                    Button(action: next) {
                        Text(settings.t(step == .privacy ? "onboarding.finish" : "common.continue")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .disabled(step == .interests && settings.interests.isEmpty)
                    .accessibilityIdentifier("onboarding.continue")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Français") { settings.setLanguage(.fr) }
                        Button("English") { settings.setLanguage(.en) }
                    } label: { Label(settings.language.rawValue.uppercased(), systemImage: "globe") }
                    .accessibilityLabel(settings.t("settings.language"))
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            Text("Culture").font(.system(size: 48, weight: .bold, design: .serif))
            Text(settings.t("onboarding.welcome.title")).font(.title2.weight(.semibold))
            Text(settings.t("onboarding.welcome.body")).foregroundStyle(.secondary)
        case .interests:
            Text(settings.t("onboarding.interests.title")).font(.title2.bold())
            FlowLayout {
                ForEach(Topic.feedTopics) { topic in
                    Chip(title: settings.t(topic.localizationKey), systemImage: topic.symbolName, isOn: settings.interests.contains(topic)) {
                        if settings.interests.contains(topic) { settings.interests.remove(topic) } else { settings.interests.insert(topic) }
                    }
                    .accessibilityIdentifier("interest.\(topic.rawValue)")
                }
            }
        case .cities:
            Text(settings.t("onboarding.cities.title")).font(.title2.bold())
            Text(settings.t("onboarding.cities.body")).foregroundStyle(.secondary)
            FlowLayout {
                ForEach(model.content.cities) { city in
                    Chip(title: city.name[settings.language], systemImage: "mappin", isOn: settings.cityIDs.contains(city.id)) {
                        if settings.cityIDs.contains(city.id) { if settings.cityIDs.count > 1 { settings.cityIDs.remove(city.id) } }
                        else { settings.cityIDs.insert(city.id) }
                    }
                }
            }
            Button {
                locating = true
                Task {
                    if let city = await LocationService().nearestCity(in: model.content.cities) { settings.cityIDs = [city.id] }
                    locating = false
                }
            } label: {
                Label(settings.t("onboarding.cities.useLocation"), systemImage: "location")
            }
            .disabled(locating)
            Text(settings.t("onboarding.cities.locationNote")).font(.footnote).foregroundStyle(.secondary)
        case .level:
            Text(settings.t("onboarding.level.title")).font(.title2.bold())
            ForEach(1...4, id: \.self) { level in
                Button { settings.frenchSelfAssessment = level } label: {
                    HStack {
                        Text(settings.t("onboarding.level.\(level)")).multilineTextAlignment(.leading)
                        Spacer()
                        if settings.frenchSelfAssessment == level { Image(systemName: "checkmark.circle.fill") }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(settings.frenchSelfAssessment == level ? .isSelected : [])
            }
        case .placement:
            PlacementQuizView(questions: Array(model.content.placementQuiz.prefix(10))) { next() }
        case .goal:
            Text(settings.t("onboarding.goal.title")).font(.title2.bold())
            Picker(settings.t("onboarding.goal.title"), selection: Binding(get: { settings.dailyGoalMinutes }, set: { settings.dailyGoalMinutes = $0 })) {
                ForEach([5, 10, 20], id: \.self) { Text(settings.t("onboarding.goal.minutes", $0)).tag($0) }
            }
            .pickerStyle(.segmented)
        case .privacy:
            Text(settings.t("onboarding.privacy.title")).font(.title2.bold())
            Text(settings.t("onboarding.privacy.body")).foregroundStyle(.secondary)
            Toggle(settings.t("settings.analytics"), isOn: Binding(get: { settings.analyticsConsent ?? false }, set: { settings.analyticsConsent = $0 }))
            Text(settings.t("onboarding.privacy.attendance")).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func next() {
        if step == .privacy {
            if settings.analyticsConsent == nil { settings.analyticsConsent = false }
            settings.hasCompletedOnboarding = true
            return
        }
        withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .privacy }
    }
}

/// 10-question placement quiz. Results seed topic mastery so the feed adapts immediately.
struct PlacementQuizView: View {
    @Environment(AppSettings.self) private var settings
    let questions: [PlacementQuestion]
    let onFinish: () -> Void
    @State private var index = 0
    @State private var answered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(settings.t("onboarding.placement.title")).font(.title2.bold())
            if questions.isEmpty {
                Button(settings.t("common.continue"), action: onFinish).buttonStyle(.borderedProminent)
            } else if index < questions.count {
                Text(settings.t("onboarding.placement.counter", index + 1, questions.count)).font(.subheadline).foregroundStyle(.secondary)
                QuizCardView(quiz: questions[index].quiz, topic: questions[index].topic, itemID: questions[index].id) { _ in answered = true }
                    .id(questions[index].id)
                HStack {
                    Button(settings.t("onboarding.placement.skip")) { onFinish() }
                    Spacer()
                    Button(settings.t("quiz.next")) {
                        answered = false
                        if index + 1 < questions.count { index += 1 } else { onFinish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!answered)
                    .accessibilityIdentifier("placement.next")
                }
            }
        }
    }
}
