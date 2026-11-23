import Foundation
import WidgetKit

/// Small JSON snapshot shared with the widget extension through the App Group.
struct WidgetSnapshot: Codable {
    struct Word: Codable { var term: String; var definition: String; var register: String }
    struct NextEvent: Codable { var title: String; var venue: String; var start: Date; var timeZoneID: String; var cancelled: Bool }

    var word: Word?
    var streak: Int
    var nextEvent: NextEvent?
    var language: String

    static let fileName = "widget-snapshot.json"

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.geigecoast.culture")?.appending(path: fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(self).write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
