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
                        navRow("Reminder windows",
                               subtitle: "when it's OK to nudge you",
                               destination: AnyView(ReminderWindowsScreen()))
                        Hair(inset: 16)
                        navRow("Find duplicate contacts",
                               subtitle: "virtual merges only",
                               destination: AnyView(MergeDuplicatesScreen(
                                viewModel: MergeDuplicatesViewModel(contacts: env.contacts)
                               )))
                    }
                }

                SectionHeader("Privacy")
                RegardsCard {
                    navRow("Transparency",
                           subtitle: "how the privacy claim is verifiable",
                           destination: AnyView(TransparencyScreen()))
                }

                SectionHeader("Help")
                RegardsCard {
                    navRow("Onboarding preview",
                           subtitle: "revisit the permission intro",
                           destination: AnyView(OnboardingScreen()))
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

    private func navRow(_ title: String,
                        subtitle: String,
                        destination: AnyView) -> some View {
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
        .accessibilityIdentifier("settings.\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
