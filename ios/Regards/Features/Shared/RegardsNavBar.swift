import SwiftUI

/// Custom nav bar matching the JSX `<RegardsNavBar>` — wordmark on the left,
/// an action label on the right, then a large 34pt title with an optional
/// muted subtitle ("4 people"). Slightly simpler than SwiftUI's native
/// `.navigationTitle(...)` styling so we can land the mock pixel-faithful.
public struct RegardsNavBar: View {
    public let title: String
    public let subtitle: String?
    public let rightAction: (text: String, handler: (() -> Void)?)?
    public let showWordmark: Bool

    public init(title: String,
                subtitle: String? = nil,
                rightAction: (text: String, handler: (() -> Void)?)? = nil,
                showWordmark: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.rightAction = rightAction
        self.showWordmark = showWordmark
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if showWordmark {
                    Wordmark(size: 17, color: RegardsDS.accent)
                } else {
                    Spacer().frame(height: 17)
                }
                Spacer()
                // Render the right action as a `Button` only when the caller
                // actually provided a handler — otherwise show inert muted
                // text so it doesn't look tap-affordable. (Stubs during mock
                // parity were showing as accent-colored "buttons" with no
                // effect, which is the worst of both worlds.)
                if let rightAction {
                    if let handler = rightAction.handler {
                        Button {
                            handler()
                        } label: {
                            Text(rightAction.text)
                                .font(.body)
                                .foregroundStyle(RegardsDS.accent)
                        }
                    } else {
                        Text(rightAction.text)
                            .font(.body)
                            .foregroundStyle(RegardsDS.muted)
                    }
                }
            }
            .frame(height: 24)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(RegardsFont.largeTitle())
                    .foregroundStyle(RegardsDS.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(RegardsDS.muted)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// Two-option segmented control used for the Overdue / Upcoming toggle.
public struct RegardsSegmentedControl<Tab: Hashable>: View {
    public struct Option: Identifiable {
        public let id: Tab
        public let label: String
        public let count: Int?

        public init(id: Tab, label: String, count: Int? = nil) {
            self.id = id
            self.label = label
            self.count = count
        }
    }

    @Binding var selection: Tab
    let options: [Option]

    public init(selection: Binding<Tab>, options: [Option]) {
        self._selection = selection
        self.options = options
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { opt in
                Button {
                    selection = opt.id
                } label: {
                    HStack(spacing: 6) {
                        Text(opt.label)
                            .font(.subheadline.weight(selection == opt.id ? .semibold : .medium))
                            .foregroundStyle(RegardsDS.ink)
                        if let count = opt.count {
                            Text("\(count)")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(
                                        selection == opt.id
                                            ? RegardsDS.accentSoft
                                            : RegardsDS.hairSoft
                                    )
                                )
                                .foregroundStyle(
                                    selection == opt.id ? RegardsDS.accentInk : RegardsDS.muted
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(selection == opt.id ? RegardsDS.surface : Color.clear)
                            .shadow(color: selection == opt.id ? .black.opacity(0.06) : .clear,
                                    radius: 1, y: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(opt.label)\(opt.count.map { ", \($0)" } ?? "")")
                .accessibilityAddTraits(selection == opt.id ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RegardsDS.hairSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 20)
    }
}
