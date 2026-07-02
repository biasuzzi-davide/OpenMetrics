import Combine
import Foundation

@MainActor
final class AIUsageStore: ObservableObject {
    @Published private(set) var snapshot = AIUsageSnapshot.empty
    @Published private(set) var isRefreshing = false

    private let reader = AIUsageReader()
    private var refreshTask: Task<Void, Never>?

    init() {
        refresh()
    }

    deinit {
        refreshTask?.cancel()
    }

    func refresh() {
        guard isRefreshing == false else { return }
        isRefreshing = true

        let loadingProviders = snapshot.providers.map {
            AIProviderUsage(id: $0.id, status: $0.metrics.isEmpty ? .loading : $0.status, plan: $0.plan, metrics: $0.metrics)
        }
        snapshot = AIUsageSnapshot(providers: loadingProviders, updatedAt: snapshot.updatedAt)

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let providers = await reader.read()
            if !Task.isCancelled {
                snapshot = AIUsageSnapshot(providers: providers, updatedAt: .now)
                isRefreshing = false
            }
        }
    }
}
