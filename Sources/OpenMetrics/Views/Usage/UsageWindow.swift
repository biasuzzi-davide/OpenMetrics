import AppKit
import SwiftUI

enum UsageSection: String, CaseIterable, Identifiable {
    case trend = "Andamento"
    case models = "Modelli"
    case projects = "Progetti"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .trend: return "chart.bar.xaxis"
        case .models: return "cpu"
        case .projects: return "folder"
        }
    }
}

struct UsageWindow: View {
    @ObservedObject var store: UsageHistoryStore
    @State private var section = UsageSection.trend

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            NavigationSplitView {
                UsageFiltersSidebar(store: store)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 340)
            } detail: {
                content
                    .frame(minWidth: 620, minHeight: 440)
            }
        }
        .onAppear { store.loadIfNeeded() }
    }

    /// Barra comandi disegnata nella vista: la finestra usa un titlebar trasparente,
    /// cosi i controlli restano allineati al resto del contenuto.
    private var headerBar: some View {
        HStack(spacing: 10) {
            UsageStatusLabel(state: store.state, recordCount: store.recordCount)

            Spacer()

            Button {
                exportCSV()
            } label: {
                Label("Esporta CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(store.analysis.buckets.isEmpty)
            .help("Esporta i periodi visualizzati in CSV")

            Button {
                store.refresh()
            } label: {
                Label("Aggiorna", systemImage: "arrow.clockwise")
            }
            .disabled(store.isBusy)
            .help("Rilegge i log e aggiunge le sessioni nuove")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isBusy && store.recordCount == 0 {
                UsageLoadingView(state: store.state)
            } else {
                Picker("", selection: $section) {
                    ForEach(UsageSection.allCases) { item in
                        Label(item.rawValue, systemImage: item.icon).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if store.filter.isFiltered {
                    UsageActiveFiltersBar(store: store)
                }

                UsageSummaryCards(analysis: store.analysis, granularity: store.filter.granularity)

                if !store.unpricedModels.isEmpty {
                    UsagePricingBanner(store: store)
                }

                Divider()

                sectionBody
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch section {
        case .trend:
            VStack(alignment: .leading, spacing: 12) {
                UsageChartView(analysis: store.analysis, filter: store.filter)

                if store.analysis.byProvider.count > 1 {
                    UsageBreakdownTable(
                        rows: store.analysis.byProvider,
                        grandTotal: store.analysis.totals,
                        labelColumn: "Provider",
                        showsProvider: true,
                        pricing: store.pricing
                    )
                    .frame(minHeight: 90, maxHeight: 130)
                }
            }
        case .models:
            UsageBreakdownTable(
                rows: store.analysis.byModel,
                grandTotal: store.analysis.totals,
                labelColumn: "Modello",
                showsProvider: false,
                pricing: store.pricing
            )
        case .projects:
            UsageBreakdownTable(
                rows: store.analysis.byProject,
                grandTotal: store.analysis.totals,
                labelColumn: "Progetto",
                showsProvider: true,
                pricing: store.pricing
            )
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "openmetrics-usage.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? store.exportCSV(to: url)
    }
}

struct UsageStatusLabel: View {
    var state: UsageHistoryStore.LoadState
    var recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(UsageFormatter.integer(recordCount)) richieste indicizzate")
                .font(.caption)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        switch state {
        case .idle:
            return "in attesa"
        case .loadingCache:
            return "carico la cache"
        case .scanning(let progress):
            guard progress.totalFiles > 0 else { return "cerco i log" }
            return "scansione \(progress.scannedFiles)/\(progress.totalFiles)"
        case .ready(let date):
            return "aggiornato \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            return message
        }
    }
}

struct UsageLoadingView: View {
    var state: UsageHistoryStore.LoadState

    var body: some View {
        VStack(spacing: 10) {
            if case .scanning(let progress) = state, progress.totalFiles > 0 {
                ProgressView(value: progress.fraction)
                    .frame(maxWidth: 260)
                Text("Indicizzo \(progress.scannedFiles) di \(progress.totalFiles) file di log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                Text("Cerco i log di Claude Code e Codex")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Solo la prima volta: dopo vengono lette soltanto le righe nuove.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Un filtro stretto puo ridurre la finestra a poche richieste: senza un segnale esplicito
/// sembra che i dati siano spariti.
struct UsageActiveFiltersBar: View {
    @ObservedObject var store: UsageHistoryStore

    private var chips: [String] {
        var chips: [String] = []
        if store.filter.providers.count != AIProviderID.allCases.count {
            chips.append(store.filter.providers.map(\.rawValue).sorted().joined(separator: ", "))
        }
        if !store.filter.models.isEmpty {
            chips.append("\(store.filter.models.count) modelli su \(store.catalog.models.count)")
        }
        if !store.filter.projects.isEmpty {
            chips.append("\(store.filter.projects.count) progetti su \(store.catalog.projects.count)")
        }
        let search = store.filter.search.trimmingCharacters(in: .whitespaces)
        if !search.isEmpty {
            chips.append("ricerca \u{201C}\(search)\u{201D}")
        }
        return chips
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.tint)

            Text("Filtri attivi")
                .font(.caption.weight(.semibold))

            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.caption2)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.18), in: Capsule())
            }

            Spacer()

            Button("Azzera") { store.resetFilters() }
                .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Avvisa che il costo mostrato esclude i modelli senza tariffa e offre come rimediare.
struct UsagePricingBanner: View {
    @ObservedObject var store: UsageHistoryStore

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.unpricedModels.count) modelli senza tariffa")
                    .font(.caption.weight(.semibold))
                Text(store.unpricedModels.prefix(6).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Configura prezzi") {
                configurePricing()
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func configurePricing() {
        guard let url = try? store.writePricingTemplate() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
