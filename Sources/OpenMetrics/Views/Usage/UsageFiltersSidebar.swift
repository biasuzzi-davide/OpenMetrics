import SwiftUI

struct UsageFiltersSidebar: View {
    @ObservedObject var store: UsageHistoryStore
    @State private var modelQuery = ""
    @State private var projectQuery = ""

    private var models: [String] {
        guard !modelQuery.isEmpty else { return store.catalog.models }
        return store.catalog.models.filter { $0.localizedCaseInsensitiveContains(modelQuery) }
    }

    private var projects: [UsageCatalog.Project] {
        guard !projectQuery.isEmpty else { return store.catalog.projects }
        return store.catalog.projects.filter {
            $0.name.localizedCaseInsensitiveContains(projectQuery) || $0.path.localizedCaseInsensitiveContains(projectQuery)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                period
                view
                providers
                modelPicker
                projectPicker
                footnote
            }
            .padding(14)
        }
    }

    private var period: some View {
        UsageFilterGroup(title: "Periodo") {
            Picker("", selection: $store.filter.preset) {
                ForEach(UsageRangePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .labelsHidden()

            if store.filter.preset == .custom {
                DatePicker("Da", selection: $store.filter.customStart, displayedComponents: .date)
                DatePicker("A", selection: $store.filter.customEnd, displayedComponents: .date)
            }

            if let first = store.catalog.firstRecord, let last = store.catalog.lastRecord {
                Text("dati da \(first.formatted(date: .abbreviated, time: .omitted)) a \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var view: some View {
        UsageFilterGroup(title: "Vista") {
            Picker("Metrica", selection: $store.filter.metric) {
                ForEach(UsageMetricKind.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            Picker("Raggruppa", selection: $store.filter.granularity) {
                ForEach(UsageGranularity.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            Picker("Dividi per", selection: $store.filter.stack) {
                ForEach(UsageStackDimension.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
        }
    }

    private var providers: some View {
        UsageFilterGroup(title: "Provider") {
            ForEach(AIProviderID.allCases) { provider in
                Toggle(isOn: providerBinding(provider)) {
                    HStack(spacing: 6) {
                        AIProviderIcon(provider: provider, size: 12)
                        Text(provider.rawValue)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    private var modelPicker: some View {
        UsageFilterGroup(
            title: "Modelli",
            subtitle: selectionLabel(store.filter.models.count, total: store.catalog.models.count)
        ) {
            UsageSelectionControls(
                selection: $store.filter.models,
                universe: store.catalog.models,
                visible: models.map(\.self),
                isSearching: !modelQuery.isEmpty
            )

            TextField("Filtra modelli", text: $modelQuery)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            UsageCheckboxList(
                items: models.map { UsageCheckboxItem(id: $0, label: $0) },
                universe: store.catalog.models,
                selection: $store.filter.models
            )
        }
    }

    private var projectPicker: some View {
        UsageFilterGroup(
            title: "Progetti",
            subtitle: selectionLabel(store.filter.projects.count, total: store.catalog.projects.count)
        ) {
            UsageSelectionControls(
                selection: $store.filter.projects,
                universe: store.catalog.projects.map(\.path),
                visible: projects.map(\.path),
                isSearching: !projectQuery.isEmpty
            )

            TextField("Filtra progetti", text: $projectQuery)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            UsageCheckboxList(
                items: projects.map { UsageCheckboxItem(id: $0.path, label: $0.name, help: $0.path) },
                universe: store.catalog.projects.map(\.path),
                selection: $store.filter.projects
            )
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Il costo e una stima a tariffe API. Con un abbonamento Claude o ChatGPT quei token non si pagano a consumo: serve a confrontare il peso dei periodi, non a leggere la spesa reale.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectionLabel(_ selected: Int, total: Int) -> String {
        selected == 0 ? "tutti (\(total))" : "\(selected) di \(total)"
    }

    private func providerBinding(_ provider: AIProviderID) -> Binding<Bool> {
        Binding(
            get: { store.filter.providers.contains(provider) },
            set: { isOn in
                var providers = store.filter.providers
                if isOn {
                    providers.insert(provider)
                } else if providers.count > 1 {
                    // Togliere anche l'ultimo provider lascerebbe la finestra vuota.
                    providers.remove(provider)
                }
                store.filter.providers = providers
            }
        )
    }
}

/// "Tutti" riporta il filtro a vuoto (che significa nessuna restrizione); "Solo questi"
/// tiene esattamente le voci che la ricerca sta mostrando.
struct UsageSelectionControls: View {
    @Binding var selection: Set<String>
    var universe: [String]
    var visible: [String]
    var isSearching: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button("Tutti") { selection = [] }
                .disabled(selection.isEmpty)

            if isSearching {
                Button("Solo questi") { selection = Set(visible) }
                    .disabled(visible.isEmpty || Set(visible) == selection || visible.count == universe.count)
            }

            Spacer()
        }
        .controlSize(.small)
        .buttonStyle(.link)
        .font(.caption2)
    }
}

struct UsageCheckboxItem: Identifiable, Equatable {
    var id: String
    var label: String
    var help: String?
}

/// Lista a spunte dove "niente selezionato" vale "tutti".
///
/// Scorre entro un'altezza fissa: una lista libera dichiarerebbe l'altezza di tutte le
/// sue righe (anche centocinquanta) e sfonderebbe il layout della sidebar.
struct UsageCheckboxList: View {
    var items: [UsageCheckboxItem]
    /// Tutti gli id esistenti, non solo quelli mostrati: la selezione va calcolata su
    /// questo insieme, altrimenti spuntare una voce mentre si cerca butterebbe via
    /// tutto cio che la ricerca sta nascondendo.
    var universe: [String]
    @Binding var selection: Set<String>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 3) {
                if items.isEmpty {
                    Text("nessun risultato")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(items) { item in
                    Toggle(isOn: binding(for: item.id)) {
                        Text(item.label)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(item.help ?? item.label)
                    }
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)
        }
        .frame(height: listHeight)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
    }

    private var listHeight: CGFloat {
        items.count <= 4 ? 88 : 180
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { UsageSelection.isSelected(id, in: selection) },
            set: { isOn in
                selection = UsageSelection.toggling(id, to: isOn, in: selection, universe: universe)
            }
        )
    }
}

struct UsageFilterGroup<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
