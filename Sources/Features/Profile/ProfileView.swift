import SwiftUI
import CultureCore

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store

    var body: some View {
        let streak = store.streak
        ScrollView {
            VStack(spacing: 20) {
                ProgressCard(streak: streak.length, level: store.level, xp: store.totalXP, words: store.learnedWordCount,
                             events: store.attendingEventIDs.count)
                ShareLink(item: Image(uiImage: renderProgressCard(streak: streak.length)),
                          preview: SharePreview(settings.t("profile.shareTitle"), image: Image(uiImage: renderProgressCard(streak: streak.length)))) {
                    Label(settings.t("profile.share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)

                if streak.forgivenessAvailableThisWeek {
                    Label(settings.t("profile.jokerAvailable"), systemImage: "shield.lefthalf.filled").font(.footnote).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(settings.t("profile.mastery")).font(.headline)
                    let scores = store.masteryScores()
                    ForEach(Topic.feedTopics) { topic in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(settings.t(topic.localizationKey), systemImage: topic.symbolName)
                                Spacer()
                                Text(settings.t(store.masteryLevel(for: topic).localizationKey)).font(.caption.weight(.semibold))
                            }
                            ProgressView(value: scores[topic] ?? 0).tint(topic.tint)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                let liked = model.content.cards.filter { store.isLiked($0.id) }
                if !liked.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(settings.t("profile.liked"), systemImage: "heart.fill").font(.headline)
                        PhotoGrid(cards: liked).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                NavigationLink { SettingsView() } label: {
                    Label(settings.t("settings.title"), systemImage: "gearshape").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("profile.settings")
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(settings.t("tab.profile"))
    }

    @MainActor
    private func renderProgressCard(streak: Int) -> UIImage {
        let renderer = ImageRenderer(content:
            ProgressCard(streak: streak, level: store.level, xp: store.totalXP, words: store.learnedWordCount, events: store.attendingEventIDs.count)
                .environment(settings)
                .frame(width: 360)
                .padding()
                .background(Color(.systemBackground)))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

struct ProgressCard: View {
    @Environment(AppSettings.self) private var settings
    let streak: Int, level: Int, xp: Int, words: Int, events: Int

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill").font(.system(size: 64)).foregroundStyle(.secondary).accessibilityHidden(true)
            HStack(spacing: 0) {
                stat(value: "\(streak)", label: settings.t("profile.streak"), symbol: "flame.fill", tint: .orange)
                stat(value: "\(level)", label: settings.t("profile.level"), symbol: "star.fill", tint: .yellow)
                stat(value: "\(words)", label: settings.t("profile.words"), symbol: "text.book.closed.fill", tint: .indigo)
                stat(value: "\(events)", label: settings.t("profile.events"), symbol: "ticket.fill", tint: .pink)
            }
            Text(settings.t("profile.xp", xp)).font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func stat(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
