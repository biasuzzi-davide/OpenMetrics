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
        NavigationSplitView {
            UsageFiltersSidebar(store: store)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            content
                .frame(minWidth: 620, minHeight: 440)
        }
        .navigationTitle("Utilizzo AI")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Sezione", selection: $section) {
                    ForEach(UsageSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            ToolbarItemGroup(placement: .primaryAction) {
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
        }
        .onAppear { store.loadIfNeeded() }
    }

    private var subtitle: String {
        "\(UsageFormatter.integer(store.recordCount)) richieste · \(stateDetail)"
    }

    private var stateDetail: String {
        switch store.state {
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

    @ViewBuilder
    private var content: some View {
        if store.isBusy && store.recordCount == 0 {
            UsageLoadingView(state: store.state)
        } else if section == .trend {
            // L'andamento puo essere piu alto della finestra: scorre, mentre le tabelle
            // scorrono da sole e vogliono un'altezza definita.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summaryBlocks

                    UsageChartView(analysis: store.analysis, filter: store.filter)
                        .padding(14)
                        .card()

                    if store.analysis.byProvider.count > 1 {
                        UsageBreakdownTable(
                            rows: store.analysis.byProvider,
                            grandTotal: store.analysis.totals,
                            labelColumn: "Provider",
                            showsProvider: true,
                            pricing: store.pricing
                        )
                        .frame(height: 36 + CGFloat(store.analysis.byProvider.count) * 28)
                        .tableCard()
                    }
                }
                .padding(16)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                summaryBlocks

                switch section {
                case .models:
                    UsageBreakdownTable(
                        rows: store.analysis.byModel,
                        grandTotal: store.analysis.totals,
                        labelColumn: "Modello",
                        showsProvider: false,
                        pricing: store.pricing
                    )
                    .tableCard()
                case .projects, .trend:
                    UsageBreakdownTable(
                        rows: store.analysis.byProject,
                        grandTotal: store.analysis.totals,
                        labelColumn: "Progetto",
                        showsProvider: true,
                        pricing: store.pricing
                    )
                    .tableCard()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var summaryBlocks: some View {
        if store.filter.isFiltered {
            UsageActiveFiltersBar(store: store)
        }

        UsageSummaryCards(analysis: store.analysis, granularity: store.filter.granularity)

        if !store.unpricedModels.isEmpty {
            UsagePricingBanner(store: store)
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

private extension View {
    /// Una `Table` porta il suo sfondo: basta ritagliarla e bordarla come le altre card.
    func tableCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return clipShape(shape)
            .overlay(shape.strokeBorder(.quaternary.opacity(0.7), lineWidth: 1))
    }
}

struct UsageLoadingView: View {
    var state: UsageHistoryStore.LoadState

    var body: some View {
        VStack(spacing: 12) {
            if case .scanning(let progress) = state, progress.totalFiles > 0 {
                ProgressView(value: progress.fraction)
                    .frame(maxWidth: 260)
                Text("Indicizzo \(progress.scannedFiles) di \(progress.totalFiles) file di log")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                Text("Cerco i log di Claude Code e Codex")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("Solo la prima volta: dopo vengono lette soltanto le righe nuove.")
                .font(.caption)
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
                .font(.callout.weight(.semibold))

            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.16), in: Capsule())
            }

            Spacer()

            Button("Azzera") { store.resetFilters() }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Avvisa che il costo mostrato esclude i modelli senza tariffa e offre come rimediare.
struct UsagePricingBanner: View {
    @ObservedObject var store: UsageHistoryStore

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            IconBadge(systemName: "exclamationmark.triangle.fill", tint: .orange, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.unpricedModels.count) modelli senza tariffa")
                    .font(.callout.weight(.semibold))
                Text(store.unpricedModels.prefix(6).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button("Configura prezzi") {
                configurePricing()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func configurePricing() {
        guard let url = try? store.writePricingTemplate() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
