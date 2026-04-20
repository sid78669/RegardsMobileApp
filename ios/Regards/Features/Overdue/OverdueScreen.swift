import SwiftUI

public struct OverdueScreen: View {
    @State private var viewModel: OverdueViewModel
    private let upcomingCount: Int
    private let onTapContact: (UUID) -> Void
    private let onTapChannel: (OverdueRowState) -> Void

    public init(viewModel: OverdueViewModel,
                upcomingCount: Int = 7,
                onTapContact: @escaping (UUID) -> Void = { _ in },
                onTapChannel: @escaping (OverdueRowState) -> Void = { _ in }) {
        self._viewModel = State(initialValue: viewModel)
        self.upcomingCount = upcomingCount
        self.onTapContact = onTapContact
        self.onTapChannel = onTapChannel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RegardsNavBar(
                    title: "Overdue",
                    subtitle: subtitle,
                    rightAction: (text: "All", handler: nil)
                )
                .padding(.top, 10)

                RegardsSegmentedControl(
                    selection: $viewModel.selectedTab,
                    options: [
                        .init(id: .overdue,  label: "Overdue",  count: viewModel.overdueCount),
                        .init(id: .upcoming, label: "Upcoming", count: upcomingCount),
                    ]
                )
                .padding(.top, 18)

                digestRow
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                if viewModel.rows.isEmpty {
                    emptyState
                } else {
                    if !viewModel.innerCircleRows.isEmpty {
                        SectionHeader("Inner circle · overdue")
                        RegardsCard { rowStack(for: viewModel.innerCircleRows, innerCircle: true) }
                    }
                    if !viewModel.closeFriendRows.isEmpty {
                        SectionHeader("Close friends · overdue")
                        RegardsCard { rowStack(for: viewModel.closeFriendRows) }
                    }
                    if !viewModel.otherRows.isEmpty {
                        SectionHeader("Others · overdue")
                        RegardsCard { rowStack(for: viewModel.otherRows) }
                    }

                    Text("Quiet until 6:00 pm. Reminders stay inside your chosen windows.")
                        .font(.footnote)
                        .foregroundStyle(RegardsDS.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(RegardsDS.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("screen.overdue")
        .task { await viewModel.load() }
    }

    private var subtitle: String {
        switch viewModel.overdueCount {
        case 0: return "all caught up"
        case 1: return "1 person"
        default: return "\(viewModel.overdueCount) people"
        }
    }

    private var digestRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Send your regards —")
                .font(RegardsFont.serifItalic(.title2))
                .foregroundStyle(RegardsDS.ink)
            Text(viewModel.nextDigestLabel)
                .font(.subheadline)
                .foregroundStyle(RegardsDS.muted)
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("All caught up.")
                .font(RegardsFont.serifItalic(.title))
                .foregroundStyle(RegardsDS.ink)
            Text("Nobody's overdue right now.")
                .font(.subheadline)
                .foregroundStyle(RegardsDS.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func rowStack(for rows: [OverdueRowState], innerCircle: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                OverdueRow(
                    row: row,
                    isInnerCircle: innerCircle,
                    onTapContact: { onTapContact(row.contactId) },
                    onTapChannel: { onTapChannel(row) }
                )
                if idx < rows.count - 1 {
                    Hair(inset: 72)
                }
            }
        }
    }
}

struct OverdueRow: View {
    let row: OverdueRowState
    let isInnerCircle: Bool
    let onTapContact: () -> Void
    let onTapChannel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTapContact) {
                HStack(spacing: 10) {
                    Avatar(name: row.name, size: 40, hasAccentRing: isInnerCircle)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(row.name)
                                .font(RegardsFont.rowTitle())
                                .foregroundStyle(RegardsDS.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            if row.isVirtualMerged {
                                Text("merged")
                                    .font(.caption2)
                                    .foregroundStyle(RegardsDS.muted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(RegardsDS.hairSoft))
                            }
                        }
                        metadataLine
                    }
                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityHint("Double-tap to open contact detail.")

            channelPill
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var metadataLine: some View {
        Text(metadataString)
            .font(.footnote)
            .foregroundStyle(RegardsDS.muted)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var metadataString: String {
        var parts: [String] = ["\(row.overdueDays)d overdue", row.cadenceText]
        if let last = row.lastInteractedText {
            parts.append("last \(last)")
        }
        return parts.joined(separator: " · ")
    }

    private var channelPill: some View {
        Button(action: onTapChannel) {
            HStack(spacing: 5) {
                ChannelGlyph(channel: row.channel, size: 13, color: .white)
                Text(row.channelLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().fill(RegardsDS.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(row.channelLabel)")
        .accessibilityHint("Opens \(row.channelLabel) with \(row.name).")
    }
}
