import SwiftUI
import CultureCore

struct CollectionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    @State private var newName = ""
    @State private var showNew = false

    var body: some View {
        let savedCards = store.savedItems(kind: .card).filter { $0.collection == nil }.compactMap { model.card($0.itemID) }
        List {
            Section(settings.t("collections.saved")) {
                if savedCards.isEmpty {
                    Text(settings.t("collections.emptySaved")).foregroundStyle(.secondary)
                } else {
                    PhotoGrid(cards: savedCards)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section(settings.t("collections.boards")) {
                ForEach(store.collections()) { collection in
                    NavigationLink { CollectionDetailView(collection: collection) } label: {
                        HStack {
                            Text(collection.name)
                            Spacer()
                            Text("\(collection.items.count)").foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    let all = store.collections()
                    for offset in offsets { store.delete(all[offset]) }
                }
                Button { showNew = true } label: { Label(settings.t("collections.new"), systemImage: "plus") }
            }
        }
        .navigationTitle(settings.t("tab.collections"))
        .alert(settings.t("collections.new"), isPresented: $showNew) {
            TextField(settings.t("collections.namePlaceholder"), text: $newName)
            Button(settings.t("common.create")) {
                let trimmed = newName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { store.createCollection(named: trimmed) }
                newName = ""
            }
            Button(settings.t("common.cancel"), role: .cancel) { newName = "" }
        }
    }
}

/// Instagram-profile-style 3-column grid of card images.
struct PhotoGrid: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass
    let cards: [ContentCard]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: sizeClass == .regular ? 5 : 3), spacing: 2) {
            ForEach(cards) { card in
                NavigationLink { CardDetailView(card: card) } label: { GridThumbnail(card: card) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(card.title[settings.language])
            }
        }
    }
}

struct CollectionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(UserDataStore.self) private var store
    let collection: UserCollection
    @State private var adding = false

    var body: some View {
        let cards = collection.items.compactMap { model.card($0.itemID) }
        ScrollView { PhotoGrid(cards: cards) }
        .overlay { if cards.isEmpty { ContentUnavailableView(settings.t("collections.emptyBoard"), systemImage: "square.stack") } }
        .navigationTitle(collection.name)
        .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel(settings.t("collections.addCards")) }
        .sheet(isPresented: $adding) {
            NavigationStack {
                List(model.content.cards) { card in
                    let inBoard = collection.items.contains { $0.itemID == card.id }
                    Button {
                        if !inBoard { store.toggleSave(card.id, kind: .card, in: collection) }
                    } label: {
                        HStack { Text(card.title[settings.language]); Spacer(); if inBoard { Image(systemName: "checkmark") } }
                    }
                }
                .navigationTitle(settings.t("collections.addCards"))
                .toolbar { Button(settings.t("common.done")) { adding = false } }
            }
        }
    }
}
