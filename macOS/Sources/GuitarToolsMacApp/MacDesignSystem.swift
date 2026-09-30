import SwiftUI

struct MacPageHeader<Trailing: View>: View {

    let title: String
    let subtitle: String?
    let trailing: () -> Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing:
            @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 20
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(title)
                    .font(
                        .system(
                            size: 28,
                            weight: .semibold
                        )
                    )

                if let subtitle,
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            Spacer(minLength: 20)

            trailing()
        }
    }
}

extension MacPageHeader
where Trailing == EmptyView {

    init(
        _ title: String,
        subtitle: String? = nil
    ) {
        self.init(
            title,
            subtitle: subtitle
        ) {
            EmptyView()
        }
    }
}

struct MacSection<Content: View>: View {

    let title: String
    let subtitle: String?
    let content: () -> Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content:
            @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 14
        ) {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(title)
                    .font(.headline)

                if let subtitle,
                   !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            content()
        }
        .padding(16)
        .background(
            .quaternary.opacity(0.18),
            in:
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
        )
    }
}

struct MacMetric: View {

    let label: String
    let value: String
    let detail: String?
    let systemImage: String?

    init(
        _ label: String,
        value: String,
        detail: String? = nil,
        systemImage: String? = nil
    ) {
        self.label = label
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(
            alignment: .center,
            spacing: 12
        ) {
            if let systemImage {
                Image(
                    systemName:
                        systemImage
                )
                .font(.title3)
                .foregroundStyle(
                    .secondary
                )
                .frame(width: 22)
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(value)
                    .font(
                        .title3
                            .weight(.semibold)
                    )
                    .monospacedDigit()

                if let detail,
                   !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(
                            .tertiary
                        )
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            Color.secondary.opacity(0.05),
            in:
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
        )
    }
}

struct MacStatusPill: View {

    let text: String
    let systemImage: String
    let role: Role

    enum Role {
        case neutral
        case success
        case warning
        case destructive
    }

    var body: some View {
        Label(
            text,
            systemImage: systemImage
        )
        .font(
            .caption
                .weight(.medium)
        )
        .padding(
            .horizontal,
            9
        )
        .padding(
            .vertical,
            5
        )
        .background(
            tint.opacity(0.12),
            in: Capsule()
        )
        .foregroundStyle(tint)
    }

    private var tint: Color {
        switch role {
        case .neutral:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        case .destructive:
            .red
        }
    }
}

struct MacAudioLevelMeter: View {

    let levelDBFS: Double
    let clipping: Bool

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 5
        ) {
            HStack {
                Text("Input")
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Spacer()

                Text(levelText)
                    .font(
                        .caption
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        clipping
                        ? .red
                        : .secondary
                    )
            }

            ProgressView(
                value: progress
            )
            .tint(
                clipping
                ? .red
                : .accentColor
            )
        }
    }

    private var progress: Double {
        min(
            max(
                (levelDBFS + 60) / 60,
                0
            ),
            1
        )
    }

    private var levelText: String {
        if levelDBFS <= -119 {
            return "−∞ dBFS"
        }

        return String(
            format:
                "%.1f dBFS",
            levelDBFS
        )
    }
}

extension View {

    func macPageWidth(
        _ width: CGFloat = 1_080
    ) -> some View {
        frame(
            maxWidth: width,
            alignment: .leading
        )
        .frame(
            maxWidth: .infinity,
            alignment: .topLeading
        )
    }
}
