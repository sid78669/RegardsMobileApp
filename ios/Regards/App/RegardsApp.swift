import SwiftUI

@main
struct RegardsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// The first SwiftUI view the user sees. Sits on top of iOS's system launch
/// screen (which is just the background color — see `UILaunchScreen` in the
/// Info.plist) and paints the brand + copyright while later phases' content
/// is warming up. In Phase 0 it's the whole app; PR3 replaces the body with
/// the real tab root once the shell lands.
struct RootView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var wordmarkWidth: CGFloat = 240

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand wordmark — decorative; the whole screen's
                // accessibility element describes it below so VoiceOver
                // doesn't read the image + a separate "Regards" label twice.
                Image("LaunchWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: wordmarkWidth)
                    .accessibilityHidden(true)

                Text("Phase 0 scaffold")
                    .font(.footnote)
                    .foregroundStyle(Color("Muted"))
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                Spacer()

                disclaimer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Regards. Phase 0 scaffold. Copyright 2026 Sid Dahiya.")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("launch.root")
    }

    /// Quiet footer under the wordmark — the architecture doc's tone: literal,
    /// reassuring, no marketing. Single-line copyright keeps the splash
    /// distraction-free.
    private var disclaimer: some View {
        Text("© 2026 Sid Dahiya")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color("Muted"))
            .multilineTextAlignment(.center)
    }
}

#Preview {
    RootView()
}
