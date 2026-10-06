import SwiftUI

/// Gives the search a visible starting point, and distinguishes zero results from no search yet.
struct ChartSearchStateView: View {
    @Binding var query: String
    let submittedQuery: String?
    let error: String?
    let onSearch: () -> Void
    var recentCharts: [ChordWikiSearchResult] = []
    var onOpenRecent: ((ChordWikiSearchResult) -> Void)?
    var onRemoveRecent: ((ChordWikiSearchResult) -> Void)?

    private var title: String {
        if error != nil { return "譜面を取得できませんでした" }
        if submittedQuery != nil { return "譜面が見つかりませんでした" }
        return "譜面"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 16) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 64, height: 64)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityHidden(true)
                    MacPageHeader(title, subtitle: "曲名・アーティスト名で検索")
                }
                VStack(alignment: .leading, spacing: 12) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            searchField
                            searchButton
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            searchField
                            searchButton
                        }
                    }
                    Text("ChordWiki・U-FRET")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let error {
                        Text(error).foregroundStyle(.secondary)
                    } else if let submittedQuery {
                        Text("「\(submittedQuery)」の検索結果は0件です。")
                            .foregroundStyle(.secondary)
                    }
                }
                if !recentCharts.isEmpty, let onOpenRecent {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最近開いた譜面")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(Array(recentCharts.enumerated()), id: \.element.id) { index, result in
                                ChartRecentRow(result: result) { onOpenRecent(result) }
                                    .contextMenu {
                                        if let onRemoveRecent {
                                            Button("履歴から削除", role: .destructive) { onRemoveRecent(result) }
                                        }
                                    }
                                if index < recentCharts.count - 1 {
                                    Divider().padding(.leading, 64)
                                }
                            }
                        }
                        .macContentSurface(radius: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
            .padding(MacLayout.pagePadding)
            .padding(.top, 16)
            .macPageWidth(800)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("曲名またはアーティスト名", text: $query)
                .textFieldStyle(.plain)
                .accessibilityLabel("曲名またはアーティスト名")
                .onSubmit(onSearch)
        }
        .font(.title3)
        .padding(16)
        .macContentSurface(radius: 14)
    }

    private var searchButton: some View {
        Button(error == nil ? "検索" : "再検索", action: onSearch)
            .controlSize(.large)
            .macActionButton(prominent: true)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private struct ChartRecentRow: View {
    let result: ChordWikiSearchResult
    let onOpen: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if !result.subtitle.isEmpty {
                        Text(result.subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovered ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(result.title)
    }
}

struct ChartLoadErrorBanner: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("譜面を開けませんでした", systemImage: "exclamationmark.triangle")
                .fontWeight(.semibold)
            Text(message)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}
