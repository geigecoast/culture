import Foundation
import Observation

/// Gentle, dismissible reminder after N minutes of continuous foreground use.
/// Users can turn it off in Settings. No streak pressure, no guilt copy.
@Observable
@MainActor
final class ScreenTimeMonitor {
    var shouldShowReminder = false
    private var task: Task<Void, Never>?

    func start(minutes: Int, enabled: Bool) {
        task?.cancel()
        guard enabled else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(minutes * 60))
            guard !Task.isCancelled else { return }
            self?.shouldShowReminder = true
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
