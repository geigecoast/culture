import XCTest
@testable import CultureCore

final class FeedRankerTests: XCTestCase {
    func testWeakTopicsAppearMoreOften() {
        let cards = Topic.feedTopics.flatMap { t in (0..<10).map { Fixtures.card("\(t.rawValue)-\($0)", t) } }
        let profile = FeedRanker.Profile(interests: Set(Topic.feedTopics), mastery: [.art: 1.0, .history: 0.0])
        let top = FeedRanker().rank(cards, profile: profile).prefix(20)
        let art = top.filter { $0.topic == .art }.count
        let history = top.filter { $0.topic == .history }.count
        XCTAssertGreaterThan(history, art)
    }

    func testNoTopicMoreThanTwiceInARow() {
        let cards = (0..<10).map { Fixtures.card("a\($0)", .art) } + (0..<3).map { Fixtures.card("m\($0)", .music) }
        let ranked = FeedRanker().rank(cards, profile: .init(interests: [.art])).map(\.topic)
        XCTAssertEqual(ranked.count, 13)
        let firstMusicRun = ranked.prefix(9)
        for i in 2..<firstMusicRun.count {
            XCTAssertFalse(ranked[i] == ranked[i - 1] && ranked[i] == ranked[i - 2], "triple at \(i)")
        }
    }

    func testUnseenFirst() {
        let cards = [Fixtures.card("a1", .art), Fixtures.card("a2", .art)]
        let ranked = FeedRanker().rank(cards, profile: .init(interests: [.art], seenCardIDs: ["a1"]))
        XCTAssertEqual(ranked.map(\.id), ["a2", "a1"])
    }
}

final class ContentParsingTests: XCTestCase {
    let json = """
    {
      "version": 3,
      "generatedAt": "2026-11-20T09:00:00Z",
      "cards": [{
        "id": "art-001", "topic": "art", "kind": "standard",
        "title": {"fr": "L'impressionnisme", "en": "Impressionism"},
        "body": {"fr": "Corps", "en": "Body"},
        "takeaway": {"fr": "À retenir", "en": "Takeaway"},
        "quiz": {"question": {"fr": "Q", "en": "Q"}, "options": [{"fr": "A", "en": "A"}, {"fr": "B", "en": "B"}],
                 "answerIndex": 1, "explanation": {"fr": "E", "en": "E"}},
        "tags": ["xixe"],
        "editorial": {"status": "in_review", "sources": [{"title": "Musée d'Orsay", "url": "https://www.musee-orsay.fr"}],
                      "lastReviewed": null, "reviewer": null}
      }],
      "vocab": [{
        "id": "v-001", "term": "ostensiblement", "partOfSpeech": "adv.", "register": "soutenu",
        "definition": "D", "gloss": "G", "example": "Ex", "nuances": [{"word": "manifestement", "note": {"fr": "n", "en": "n"}}],
        "pitfalls": [], "sets": ["nuances"],
        "editorial": {"status": "published", "sources": [{"title": "TLFi"}], "lastReviewed": "2026-11-01", "reviewer": "A"},
        "nativeReviewer": "A"
      }],
      "vocabSets": [{"id": "nuances", "title": {"fr": "Nuances", "en": "Nuances"}}],
      "cities": [{"id": "paris", "name": {"fr": "Paris", "en": "Paris"}, "timeZoneID": "Europe/Paris", "latitude": 48.85, "longitude": 2.35}],
      "venues": [{"id": "garnier", "name": "Palais Garnier", "cityID": "paris", "address": "Place de l'Opéra, 75009 Paris", "latitude": 48.872, "longitude": 2.3316}],
      "events": [{
        "id": "e1", "title": "La traviata", "category": "opera_ballet", "cityID": "paris", "venueID": "garnier",
        "start": "2026-12-31T23:30:00+01:00", "timeZoneID": "Europe/Paris",
        "price": {"minEUR": 15, "maxEUR": 230, "isFree": false},
        "officialURL": "https://www.operadeparis.fr", "sourceName": "Opéra national de Paris",
        "lastChecked": "2026-11-20T08:00:00.000Z", "status": "cancelled", "editorialStatus": "published", "isSample": true
      }],
      "placementQuiz": []
    }
    """

    func testDecodesBundle() throws {
        let bundle = try ContentDecoder.bundle(from: Data(json.utf8))
        XCTAssertEqual(bundle.version, 3)
        XCTAssertEqual(bundle.cards.first?.title[.en], "Impressionism")
        XCTAssertEqual(bundle.vocab.first?.register, .soutenu)
        XCTAssertEqual(bundle.events.first?.isCancelled, true)
        XCTAssertEqual(bundle.events.first?.price.maxEUR, 230)
        XCTAssertEqual(EventSchedule().dayKey(of: bundle.events[0]), "2026-12-31")
    }

    func testVisibilityFiltersUnreviewedContent() throws {
        let bundle = try ContentDecoder.bundle(from: Data(json.utf8))
        XCTAssertEqual(bundle.filtered(for: .publishedOnly).cards.count, 0)
        XCTAssertEqual(bundle.filtered(for: .includeInReview).cards.count, 1)
    }

    func testValidatorFlagsPublishedCardWithoutSource() throws {
        var bundle = try ContentDecoder.bundle(from: Data(json.utf8))
        bundle.cards[0].editorial = EditorialInfo(status: .published, sources: [])
        let messages = ContentValidator().validate(bundle).map(\.message)
        XCTAssertTrue(messages.contains("published without a source"))
        XCTAssertTrue(messages.contains("published without a last-reviewed date"))
    }

    func testValidatorFlagsGalleryImageWithoutLicence() throws {
        var bundle = try ContentDecoder.bundle(from: Data(json.utf8))
        let alt = LocalizedText(fr: "a", en: "a")
        bundle.cards[0].image = LicensedImage(url: URL(string: "https://example.org/a.jpg")!, license: "CC0", credit: "Museum", altText: alt)
        bundle.cards[0].gallery = [LicensedImage(url: URL(string: "https://example.org/b.jpg")!, license: "", credit: "", altText: alt)]
        XCTAssertEqual(bundle.cards[0].images.count, 2)
        XCTAssertTrue(ContentValidator().validate(bundle).map(\.message).contains("image without licence or credit"))
    }

    func testEnglishFallsBackToFrench() {
        XCTAssertEqual(LocalizedText(fr: "Bonjour", en: "")[.en], "Bonjour")
    }

    func testPreferredLanguage() {
        XCTAssertEqual(AppLanguage.fromPreferred(["en-GB", "fr-FR"]), .en)
        XCTAssertEqual(AppLanguage.fromPreferred(["de-DE", "fr-FR"]), .fr)
        XCTAssertEqual(AppLanguage.fromPreferred(["de-DE"]), .fr)
    }
}
