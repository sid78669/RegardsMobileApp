# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Source of truth

`ARCHITECTURE.md` at the repo root is the canonical design doc — vision, V1 scope, data model, channel catalog, reminder-window engine, privacy stack, phase plan. When a code change and `ARCHITECTURE.md` disagree, either the code is wrong or the doc needs a sibling PR. Read the relevant section before implementing anything non-trivial. Section cross-references in code comments (e.g. "§11", "§5") point into this file.

Regards is a **local-first, no-backend, no-network** mobile app. Privacy is a merge-gated invariant (see the privacy-grep guard below), not a marketing claim.

Status: pre-alpha, iOS-first. The `android/` directory does not exist yet. PRs are not currently accepted (solo project under PolyForm Noncommercial 1.0.0).

## iOS — the only live platform today

All iOS work lives under `ios/`. The Xcode project is generated from `ios/project.yml` by **XcodeGen**; never hand-edit `Regards.xcodeproj`.

### Setup

```bash
brew install xcodegen swiftlint
# Xcode 16+; Swift 6 strict concurrency is on by default.
```

### Regenerate the project after editing project.yml

```bash
cd ios && xcodegen generate
```

Commit both `project.yml` *and* the regenerated `Regards.xcodeproj/`. CI runs `xcodegen generate && git diff --exit-code` — a drifted xcodeproj fails the `xcodegen-determinism` job.

### Build and test

```bash
cd ios
xcodebuild -project Regards.xcodeproj -scheme Regards \
  -destination 'platform=iOS Simulator,name=iPhone 15' build

# Full test action (both unit + accessibility suites):
xcodebuild -project Regards.xcodeproj -scheme Regards \
  -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Run a single suite or test:

```bash
# Only the swift-testing unit bundle
xcodebuild ... -only-testing:RegardsTests test
# Only the accessibility XCUITest bundle
xcodebuild ... -only-testing:RegardsAccessibilityTests test
# A specific test identifier
xcodebuild ... -only-testing:RegardsTests/OverdueViewModelTests/testName test
```

`RegardsUITests` exists but is **not** in the default test plan — it's a placeholder for general UI automation.

### Lint

```bash
swiftlint --strict   # CI uses --strict; warnings fail
```

Notable SwiftLint customizations in `.swiftlint.yml`: a custom rule (`button_requires_accessibility`) flags `Button { Image/Spacer/EmptyView }` without an explicit `.accessibilityLabel`. Warnings are treated as errors in both Debug and Release via `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.

## Architecture — layer purity is CI-enforced

The app follows a strict layered design (ARCHITECTURE.md §5). Two of those layer boundaries are enforced by grep-based CI guards in `.github/workflows/guards.yml`:

1. **Domain purity (§5).** `ios/Regards/Domain/**` must be pure Swift. No `import UIKit | SwiftUI | Contacts | EventKit | UserNotifications | GRDB | StoreKit`. Platform-dependent code belongs in `Regards/Platform/` or `Regards/Data/`.
2. **No networking anywhere in app sources (§11).** The `privacy-grep` job scans `ios/Regards` for call sites of `URLSession*`, `NWConnection/Endpoint/Listener/PathMonitor/Interface/Path`, `URLRequest`, `URLProtocol`, `CF{Read,Write}Stream*`. The pattern matches `Foo.` or `Foo(` — not the bare token — so the same names may appear in user-facing copy (e.g. the Transparency screen) without tripping the gate. Narrow any new copy around these terms carefully.

Layout inside `ios/Regards/`:

- `App/` — `@main` app entry (`RegardsApp.swift`) and `AppEnvironment` (the repository bundle injected at the root view).
- `Domain/` — pure-Swift entities (`Contact`, `Channel`, `TimeOfDay`, `DayOfWeek`, `ReminderWindow`, …), the `ReminderEngine`, `DuplicateDetector`, `ChannelCatalog`, `DeepLinkBuilder`. Unit-tested in isolation.
- `Data/` — GRDB records, migrations, repositories, and `MockRepositories` (seeded with the JSX-mock cast for Phase 0).
- `Platform/` — Apple-framework adapters (Contacts, Notifications, StoreKit, deep linking). Currently empty; populated in Phase 1+.
- `DesignSystem/` — `RegardsDS` tokens (colors, typography, WCAG contrast helpers) and shared primitives (`Avatar`, `ChannelGlyph`, `Tag`, `Wordmark`).
- `Features/` — one folder per screen (`Overdue`, `Upcoming`, `Contacts`, `ContactDetail`, `EditContact`, `MergeDuplicates`, `ReminderWindows`, `Onboarding`, `Settings`, `Shared`). Each screen owns its `*Screen.swift` view and a `*ViewModel.swift` where stateful.
- `Resources/` — `Info.plist`, asset catalog, `PrivacyInfo.xcprivacy`.

### Phase 0 → Phase 1 dependency injection

`AppEnvironment` holds the six repositories the UI needs. In Phase 0 it's wired with `MockRepositories` (`AppEnvironment.makeMock()`) — **the real GRDB stack exists but isn't wired in yet**. The Phase 1 switch is a one-line change at the `@main` struct in `RegardsApp.swift`; no view code needs to move. Keep all new feature code talking to the `any *Repository` protocols, not concrete types.

Navigation uses **one `NavigationStack` per tab** with per-tab `NavigationPath` state, so a push inside Overdue doesn't bleed into Upcoming and tab state is preserved. `ContactDetailScreen` is constructed by a factory (`contactDetail(for:)`) so each push gets a fresh VM — don't rely on SwiftUI view identity to reset it.

## Accessibility is merge-blocking

`RegardsAccessibilityTests` runs `XCUIApplication.performAccessibilityAudit()` on every screen and fails CI on any audit finding. See `ios/docs/accessibility.md` for the standing rules (VoiceOver label completeness, Dynamic Type through `accessibility5`, WCAG AA contrast, Reduce Motion, 44×44pt touch targets, focus order). Every new screen gets a row in the "screens audited" table in that doc.

PR3 landed with the **structural** audit categories gating merges (`elementDetection`, `sufficientElementDescription`, `trait`). The **sensory** categories (`contrast`, `hitRegion`, `dynamicType`, `textClipped`) are temporarily off for the eight-screen shell and tracked in the "PR3 follow-ups" section of `accessibility.md` — the constant to flip once those are fixed is `pr3AuditCategories` in `ScreensAccessibilityTests`.

Manual VoiceOver smoke (`ios/docs/accessibility-smoke.md`) is expected before any UI-touching merge.

## Info.plist privacy invariants

The app target in `project.yml` pins ATS to deny all loads:

```yaml
NSAppTransportSecurity:
  NSAllowsArbitraryLoads: false
  NSAllowsArbitraryLoadsInWebContent: false
  NSAllowsLocalNetworking: false
```

Do not loosen these. Any channel deep link that needs `canOpenURL` must be added to `LSApplicationQueriesSchemes` in `project.yml`; prefer universal HTTPS links (wa.me, t.me, ig.me) where available so the declaration isn't needed.

## CI map

- `.github/workflows/ios-ci.yml` — xcodegen determinism → build → (unit tests + coverage) + (accessibility audit). Snapshot-tests job is declared with `if: false` as a branch-protection placeholder.
- `.github/workflows/guards.yml` — privacy-grep, domain-purity-grep, project.yml YAML syntax, markdown link check for `ios/docs/`.
- `.github/workflows/lint.yml` — `swiftlint --strict`.

All four workflows gate merges.

## Things to avoid

- Hand-editing `Regards.xcodeproj/` — always go via `project.yml` + `xcodegen generate`.
- Importing Apple frameworks from `Domain/`.
- Adding any networking primitive — even via an indirect wrapper — without explicitly updating ARCHITECTURE.md §11 and the privacy-grep guard first.
- Writing back to system Contacts outside the partial-field `CNSaveRequest` pattern described in §7 (never delete, never bulk-edit, never merge system contacts — merges are virtual via the local `ContactGroup` table).
- Adding an OAuth calendar integration. This is an explicit non-goal (§3); local EventKit only.
