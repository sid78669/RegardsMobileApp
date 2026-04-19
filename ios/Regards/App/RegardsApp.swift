import SwiftUI

@main
struct RegardsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("regards")
                .font(.system(.largeTitle, design: .serif).italic())
                .foregroundStyle(Color("Ink"))
                .accessibilityAddTraits(.isHeader)
            Text("Phase 0 scaffold")
                .font(.footnote)
                .foregroundStyle(Color("Muted"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }
}

#Preview {
    RootView()
}
