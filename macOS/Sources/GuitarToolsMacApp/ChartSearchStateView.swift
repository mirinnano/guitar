import SwiftUI

/// Gives the search a visible starting point, and distinguishes zero results from no search yet.
struct ChartSearchStateView: View {
    @Binding var query: String
    let submittedQuery: String?
    let error: String?
    let onSearch: () -> Void

    private var title: String {
        if error != nil { return "譜面を取得できませんでした" }
        if submittedQuery != nil { return "譜面が見つかりませんでした" }
        return "好きな曲を探しましょう"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MacPageHeader(title, subtitle: "ChordWiki・U-FRETの曲名・アーティスト名で検索")
                MacSection("曲を探す") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            searchField
                            searchButton
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            searchField
                            searchButton
                        }
                    }
                    if let error {
                        Text(error)
                            .foregroundStyle(.secondary)
                        Text("通信状況を確認して、もう一度検索してください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let submittedQuery {
                        Text("「\(submittedQuery)」の検索結果は0件です。曲名を短くするか、アーティスト名で探してみてください。")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("まずは知っている曲から。検索して曲を選ぶと、譜面とコードの押さえ方を一緒に見られます。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(MacLayout.pagePadding)
            .macPageWidth(720)
        }
    }

    private var searchField: some View {
        TextField("曲名またはアーティスト名", text: $query)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("曲名またはアーティスト名")
            .onSubmit(onSearch)
    }

    private var searchButton: some View {
        Button(error == nil ? "検索" : "もう一度検索", systemImage: "magnifyingglass", action: onSearch)
            .buttonStyle(.borderedProminent)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

struct ChartLoadErrorBanner: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("譜面を開けませんでした", systemImage: "exclamationmark.triangle")
                .fontWeight(.semibold)
            Text(message)
            Text("曲名をもう一度選ぶか、別の曲を検索してください。")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}
