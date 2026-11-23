import UIKit

enum Haptics {
    @MainActor static func like() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    @MainActor static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    @MainActor static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    @MainActor static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
