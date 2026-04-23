import SwiftUI

@main
struct RegardsApp: App {
    // Phase 0 runs against MockRepositories. Phase 1 swaps in GRDBRepositories
    // here without touching any view code.
    private let env = AppEnvironment.makeMock()

    var body: some Scene {
        WindowGroup {
            RootView(env: env)
        }
    }
}

/// The first SwiftUI view the user sees. Shows the splash for a brief brand
/// moment, then crossfades into the real tab root once `.task` fires.
struct RootView: View {
    let env: AppEnvironment
    @State private var isReady = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isReady {
                RegardsTabRoot(env: env)
                    .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isReady)
        .task {
            // Give the splash a single beat before cutting to content —
            // enough to feel intentional, short enough not to feel slow.
            try? await Task.sleep(nanoseconds: 600_000_000)
            isReady = true
        }
    }
}

/// Splash shown during the app's first render pass. Phase 1 will drive the
/// transition off actual loading completion; Phase 0 just waits briefly.
struct SplashView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var wordmarkWidth: CGFloat = 240

    var body: some View {
        ZStack {
            RegardsDS.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Image("LaunchWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: wordmarkWidth)
                    .accessibilityHidden(true)
                Spacer()
                Text("© 2026 Sid Dahiya")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(RegardsDS.muted)
                    .padding(.bottom, 24)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Regards. Loading.")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("launch.root")
    }
}

/// The tab-bar root. Every feature screen reaches users through one of the
/// four tabs. Each tab wraps its content in a `NavigationStack` so pushes
/// (Contact Detail, Edit, Transparency, …) stay local to the tab.
struct RegardsTabRoot: View {
    let env: AppEnvironment
    @State private var selected: Tab = .overdue
    @State private var overdueVM: OverdueViewModel
    @State private var upcomingVM: UpcomingViewModel

    enum Tab: Hashable { case overdue, upcoming, contacts, settings }

    init(env: AppEnvironment) {
        self.env = env
        self._overdueVM = State(initialValue: OverdueViewModel(contacts: env.contacts))
        self._upcomingVM = State(initialValue: UpcomingViewModel(contacts: env.contacts))
    }

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                OverdueScreen(
                    viewModel: overdueVM,
                    upcomingCount: upcomingVM.totalCount,
                    onTapContact: { _ in },
                    onTapChannel: { _ in },
                    onSwitchToUpcoming: { selected = .upcoming }
                )
            }
            .tabItem { Label("Overdue", systemImage: "exclamationmark.circle") }
            .tag(Tab.overdue)

            NavigationStack {
                UpcomingScreen(
                    viewModel: upcomingVM,
                    overdueCount: overdueVM.overdueCount,
                    onSwitchToOverdue: { selected = .overdue }
                )
            }
            .tabItem { Label("Upcoming", systemImage: "calendar") }
            .tag(Tab.upcoming)

            NavigationStack {
                AllContactsScreen(env: env)
            }
            .tabItem { Label("Contacts", systemImage: "person.2") }
            .tag(Tab.contacts)

            NavigationStack {
                SettingsScreen(env: env)
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(RegardsDS.accent)
        // Kick off both VMs up-front so the cross-tab counters on the
        // segmented control (Overdue shows upcomingCount, Upcoming shows
        // overdueCount) are populated at launch — otherwise the opposite
        // tab's `.task` wouldn't fire until the user tapped it.
        .task {
            async let overdueLoad: Void = overdueVM.load()
            async let upcomingLoad: Void = upcomingVM.load()
            _ = await (overdueLoad, upcomingLoad)
        }
    }
}

#Preview("Splash") {
    SplashView()
}

#Preview("Tab root") {
    RegardsTabRoot(env: AppEnvironment.makeMock())
}
