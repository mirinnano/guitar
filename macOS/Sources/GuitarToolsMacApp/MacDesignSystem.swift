import SwiftUI

/// Content stays on quiet, opaque surfaces; glass is reserved for controls.
enum MacLayout {
    static let pagePadding: CGFloat = 32
    static let sectionSpacing: CGFloat = 24
    static let surfaceRadius: CGFloat = 20
    static let heroRadius: CGFloat = 28
}

struct MacPageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                heading
                Spacer(minLength: 12)
                trailing
            }
            VStack(alignment: .leading, spacing: 12) {
                heading
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension MacPageHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

struct MacSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .macContentSurface()
    }
}

struct MacMetric: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String?

    init(
        _ title: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum MacStatusRole {
    case neutral, success, warning, destructive

    var color: Color {
        switch self {
        case .neutral: .secondary
        case .success: .green
        case .warning: .orange
        case .destructive: .red
        }
    }
}

struct MacStatusPill: View {
    let text: String
    let systemImage: String
    var role: MacStatusRole = .neutral

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(role.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(role.color.opacity(0.09), in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .combine)
    }
}

struct MacAudioLevelMeter: View {
    let levelDBFS: Double
    let clipping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("入力レベル", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(levelText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(clipping ? .red : .secondary)
            }
            ProgressView(value: progress)
                .tint(clipping ? .red : .accentColor)
                .accessibilityLabel("入力レベル")
                .accessibilityValue(levelText)
        }
    }

    private var progress: Double {
        min(max((levelDBFS + 60) / 60, 0), 1)
    }

    private var levelText: String {
        if levelDBFS <= -119 { return "−∞ dBFS" }
        return String(format: "%.1f dBFS", levelDBFS)
    }
}

private struct MacContentSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.045),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

private struct MacGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.macContentSurface(radius: radius)
        } else {
            // Older CI SDKs cannot type-check Liquid Glass, even behind #available.
            #if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                content.glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
            } else {
                content.background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
            }
            #else
            content.background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            #endif
        }
    }
}

private struct MacActionButton: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent).tint(.accentColor)
            } else {
                content.buttonStyle(.glass)
            }
        } else if prominent {
            content.buttonStyle(.borderedProminent).tint(.accentColor)
        } else {
            content.buttonStyle(.bordered)
        }
        #else
        if prominent {
            content.buttonStyle(.borderedProminent).tint(.accentColor)
        } else {
            content.buttonStyle(.bordered)
        }
        #endif
    }
}

extension View {
    func macContentSurface(radius: CGFloat = MacLayout.surfaceRadius) -> some View {
        modifier(MacContentSurface(radius: radius))
    }

    func macGlassSurface(radius: CGFloat = MacLayout.surfaceRadius) -> some View {
        modifier(MacGlassSurface(radius: radius))
    }

    func macActionButton(prominent: Bool = false) -> some View {
        modifier(MacActionButton(prominent: prominent))
    }

    func macPageWidth(_ width: CGFloat = 1_080) -> some View {
        frame(maxWidth: width, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}
