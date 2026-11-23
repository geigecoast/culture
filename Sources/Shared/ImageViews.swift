import SwiftUI
import CultureCore

/// Instagram-style swipeable image carousel (4:5 by default). Tap opens the full-screen viewer.
struct ImageCarousel<Placeholder: View>: View {
    @Environment(AppSettings.self) private var settings
    let images: [LicensedImage]
    var aspectRatio: CGFloat = 4.0 / 5.0
    var language: AppLanguage
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var page = 0
    @State private var viewerStart: Int?

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if images.isEmpty {
                    placeholder()
                } else {
                    TabView(selection: $page) {
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            CachedImage(url: image.url, maxPixelSize: 1400) { placeholder() }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture { viewerStart = index }
                                .accessibilityElement()
                                .accessibilityLabel(image.altText[language])
                                .accessibilityHint(settings.t("a11y.openPhoto"))
                                .accessibilityAddTraits(.isImage)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .overlay(alignment: .bottom) {
                if images.count > 1 { PageDots(count: images.count, current: page).padding(.bottom, 10) }
            }
            .overlay(alignment: .topTrailing) {
                if images.count > 1 {
                    Text("\(page + 1)/\(images.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                        .accessibilityHidden(true)
                }
            }
            .clipped()
            .fullScreenCover(item: Binding(get: { viewerStart.map(IdentifiedInt.init) }, set: { viewerStart = $0?.id })) { start in
                PhotoViewer(images: images, start: start.id, language: language)
            }
    }
}

struct IdentifiedInt: Identifiable { let id: Int }

private struct PageDots: View {
    let count: Int
    let current: Int
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Circle().fill(i == current ? Color.white : Color.white.opacity(0.45)).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.black.opacity(0.35), in: Capsule())
        .accessibilityHidden(true)
    }
}

/// Full-screen, zoomable viewer. Credit and licence are always visible.
struct PhotoViewer: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let images: [LicensedImage]
    let start: Int
    let language: AppLanguage
    @State private var page = 0
    @State private var browserURL: URL?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZoomableImage(url: image.url)
                        .accessibilityLabel(image.altText[language])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
            .ignoresSafeArea()

            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(settings.t("common.close"))
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if images.indices.contains(page) {
                let image = images[page]
                VStack(alignment: .leading, spacing: 4) {
                    Text(image.altText[language]).font(.subheadline.weight(.semibold))
                    Text("\(image.credit) · \(image.license)").font(.caption)
                    if let source = image.sourcePage {
                        Button(settings.t("photo.source")) { browserURL = source }.font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                .padding(.bottom, images.count > 1 ? 24 : 0)
            }
        }
        .onAppear { page = start }
        .statusBarHidden()
        .sheet(item: $browserURL) { SafariView(url: $0).ignoresSafeArea() }
    }
}

/// Pinch to zoom, double-tap to toggle 2×.
private struct ZoomableImage: View {
    let url: URL
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        CachedImage(url: url, maxPixelSize: 2400) { ProgressView().tint(.white) }
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(MagnifyGesture()
                .onChanged { scale = max(1, min(5, lastScale * $0.magnification)) }
                .onEnded { _ in lastScale = scale; if scale == 1 { offset = .zero; lastOffset = .zero } })
            .simultaneousGesture(DragGesture()
                .onChanged { value in
                    // Only pan when zoomed; at 1× the swipe pages through the carousel.
                    guard scale > 1 else { return }
                    offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                }
                .onEnded { _ in lastOffset = offset })
            .onTapGesture(count: 2) {
                withAnimation(.spring) {
                    scale = scale > 1 ? 1 : 2
                    lastScale = scale
                    if scale == 1 { offset = .zero; lastOffset = .zero }
                }
            }
    }
}

/// Square thumbnail used in Instagram-style 3-column grids.
struct GridThumbnail: View {
    let card: ContentCard
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = card.image {
                    CachedImage(url: image.url, maxPixelSize: 500) { TopicArtwork(topic: card.topic) }
                } else {
                    TopicArtwork(topic: card.topic)
                }
            }
            .overlay(alignment: .topTrailing) {
                if card.images.count > 1 {
                    Image(systemName: "square.on.square.fill").font(.caption).foregroundStyle(.white).shadow(radius: 2).padding(6)
                }
            }
            .clipped()
            .accessibilityElement()
            .accessibilityLabel(card.title.fr)
    }
}
