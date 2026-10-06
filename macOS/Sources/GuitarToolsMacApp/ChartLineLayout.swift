import SwiftUI

/// Wraps chord/lyric pairs together without adding source lines or playback beats.
struct ChartLineLayout: Layout {
    var rowSpacing: CGFloat = 14

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = availableWidth(proposal, subviews: subviews)
        let frames = Self.frames(for: sizes(subviews, width: width), width: width, rowSpacing: rowSpacing)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = Self.frames(for: sizes(subviews, width: bounds.width), width: bounds.width,
                                 rowSpacing: rowSpacing)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }

    private func availableWidth(_ proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let width = proposal.width, width.isFinite { return max(1, width) }
        return max(1, subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width })
    }

    private func sizes(_ subviews: Subviews, width: CGFloat) -> [CGSize] {
        subviews.map { subview in
            let ideal = subview.sizeThatFits(.unspecified)
            return subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, max(1, width)), height: nil))
        }
    }

    static func frames(for sizes: [CGSize], width: CGFloat, rowSpacing: CGFloat = 14) -> [CGRect] {
        let width = max(1, width)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        return sizes.map { size in
            let size = CGSize(width: min(size.width, width), height: size.height)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x += size.width
            rowHeight = max(rowHeight, size.height)
            return frame
        }
    }
}
