import Combine
import Foundation

@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private let reader = SystemReader()
    private var refreshInterval = 1
    private var updateTask: Task<Void, Never>?

    init() {
        refresh()
        startUpdater()
    }

    deinit {
        updateTask?.cancel()
    }

    func setRefreshInterval(_ seconds: Int) {
        let clamped = min(max(seconds, 1), 10)
        guard clamped != refreshInterval else { return }
        refreshInterval = clamped
        startUpdater()
    }

    func refresh() {
        snapshot = reader.read()
    }

    private func startUpdater() {
        updateTask?.cancel()
        updateTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.refreshInterval))
                if !Task.isCancelled {
                    self.refresh()
                }
            }
        }
    }
}
