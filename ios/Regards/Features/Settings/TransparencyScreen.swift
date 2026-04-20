import SwiftUI

public struct TransparencyScreen: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                claimCard
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                proofsSection
                auditSection

                Text("Data Not Collected is our App Store declaration too. Lying there is grounds for removal.")
                    .font(.caption)
                    .foregroundStyle(RegardsDS.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .frame(maxWidth: .infinity)

                Color.clear.frame(height: 40)
            }
        }
        .background(RegardsDS.background.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("screen.transparency")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Transparency")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundStyle(RegardsDS.ink)
                .accessibilityAddTraits(.isHeader)
            Text("We say no call-home. Here's how you can check.")
                .font(RegardsFont.serifItalic(.title3))
                .foregroundStyle(RegardsDS.muted)
                .lineSpacing(2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var claimCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This app cannot reach the internet.")
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(.white)
                .lineSpacing(3)
            Text(
                "Not \"won't.\" Cannot. The Linux kernel denies network sockets to this app's UID because "
                + "android.permission.INTERNET is absent from the manifest."
            )
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.9))
            .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RegardsDS.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var proofsSection: some View {
        VStack(spacing: 0) {
            SectionHeader("Technical proofs")
            RegardsCard {
                VStack(spacing: 0) {
                    proofRow(
                        label: "No INTERNET permission",
                        status: "AndroidManifest.xml declares zero network permissions.",
                        value: "<manifest> … no <uses-permission …INTERNET /> …"
                    )
                    Hair(inset: 16)
                    proofRow(
                        label: "No networking code on iOS",
                        status: "URLSession and Network.framework are not linked in our modules.",
                        value: "NSAppTransportSecurity / NSAllowsArbitraryLoads = false"
                    )
                    Hair(inset: 16)
                    proofRow(
                        label: "0 trackers (Exodus Privacy)",
                        status: "Automated scan of the release APK. Re-runs on every update.",
                        value: nil
                    )
                    Hair(inset: 16)
                    proofRow(
                        label: "Encrypted at rest",
                        status: "Data Protection on iOS · SQLCipher + Keystore on Android.",
                        value: nil
                    )
                }
            }
        }
    }

    private var auditSection: some View {
        VStack(spacing: 0) {
            SectionHeader("Audit yourself")
            RegardsCard {
                VStack(spacing: 0) {
                    auditRow("Read the source",
                             detail: "github.com/sid78669/RegardsMobileApp",
                             isAccent: true)
                    Hair(inset: 16)
                    auditRow("Rebuild the APK",
                             detail: "reproducible-builds.md · compare SHA-256")
                    Hair(inset: 16)
                    auditRow("Watch the network",
                             detail: "Little Snitch / Proxyman walkthrough")
                }
            }
        }
    }

    private func proofRow(label: String, status: String, value: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(RegardsDS.accent).frame(width: 20, height: 20)
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 2)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RegardsDS.ink)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(RegardsDS.muted)
                    .lineSpacing(2)
                if let value {
                    Text(value)
                        .font(RegardsFont.mono(.caption))
                        .foregroundStyle(RegardsDS.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RegardsDS.hairSoft, in: RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func auditRow(_ title: String, detail: String, isAccent: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RegardsDS.ink)
                Text(detail)
                    .font(RegardsFont.mono(.caption))
                    .foregroundStyle(isAccent ? RegardsDS.accent : RegardsDS.muted)
            }
            Spacer()
            Text("Open")
                .font(.subheadline)
                .foregroundStyle(RegardsDS.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
