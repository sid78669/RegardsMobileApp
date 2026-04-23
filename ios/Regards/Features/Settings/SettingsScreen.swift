import SwiftUI

public struct SettingsScreen: View {
    let env: AppEnvironment

    public init(env: AppEnvironment) {
        self.env = env
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                SectionHeader("Reminders")
                RegardsCard {
                    VStack(spacing: 0) {
                        navRow(
                            id: "reminder-windows",
                            title: "Reminder windows",
                            subtitle: "when it's OK to nudge you"
                        ) { ReminderWindowsScreen() }
                        Hair(inset: 16)
                        navRow(
                            id: "find-duplicate-contacts",
                            title: "Find duplicate contacts",
                            subtitle: "virtual merges only"
                        ) {
                            MergeDuplicatesScreen(
                                viewModel: MergeDuplicatesViewModel(contacts: env.contacts)
                            )
                        }
                    }
                }

                SectionHeader("Privacy")
                RegardsCard {
                    navRow(
                        id: "transparency",
                        title: "Transparency",
                        subtitle: "how the privacy claim is verifiable"
                    ) { TransparencyScreen() }
                }

                SectionHeader("Help")
                RegardsCard {
                    navRow(
                        id: "onboarding-preview",
                        title: "Onboarding preview",
                        subtitle: "revisit the permission intro"
                    ) { OnboardingScreen() }
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(RegardsDS.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("screen.settings")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundStyle(RegardsDS.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Generic over the destination so we don't pay the `AnyView` identity /
    /// diffing tax. `id` is an explicit stable accessibility identifier so the
    /// UI tests in `ScreensAccessibilityTests` don't silently break when copy
    /// tweaks (e.g. "Find duplicate contacts" → "Detect duplicates").
    private func navRow<Destination: View>(
        id: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(RegardsDS.ink)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(RegardsDS.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(RegardsDS.muted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.\(id)")
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
