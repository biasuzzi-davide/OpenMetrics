import AppKit
import SwiftUI

struct Footer: View {
    var store: MetricsStore
    var snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Text("Uptime \(MetricsFormatter.duration(snapshot.uptime))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                store.refresh()
            } label: {
                Label("Aggiorna", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Esci", systemImage: "power")
            }
            .buttonStyle(.bordered)
        }
    }
}

struct MetricRow: View {
    var icon: String
    var title: String
    var value: String
    var detail: String
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                Text(title)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct MiniMetric: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct DetailSection<Content: View>: View {
    var title: String
    var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct InfoRow: View {
    var title: String
    var value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption)
    }
}
