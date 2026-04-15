# Regards

**Keep your people in your regards.**

Regards is a local-first mobile app that reminds you to stay in touch with the people who matter — at times that respect your day, with one tap into your preferred way to reach out.

It answers one question: *"Who have I been meaning to talk to, but haven't?"*

> **Status:** Pre-alpha. Regards is a one-person project, so the two apps are being built one platform at a time — iOS first, Android next. No public builds yet.

## What it does

- Import your device contacts (read-only until you choose to edit).
- Mark the people you actively want to stay in touch with. Set a cadence per contact — weekly, monthly, quarterly, yearly, or custom.
- Pick a preferred way to reach each person — phone, SMS, WhatsApp, Signal, Telegram, email, and more.
- Define **reminder windows** — the days and hours when it's OK for the app to bug you. Reminders never fire in the middle of a workday unless you ask them to.
- Tap a reminder to deep-link straight into the right app, with the right contact, ready to go. No message prefill.
- Birthdays and anniversaries are read from your device Contacts and (optionally) your local Calendar — no cloud sync, no OAuth.
- An Upcoming view shows what's coming in the next 14 days so you can get ahead of things.
- Home-screen and Lock Screen widgets surface who's overdue at a glance.

## What it doesn't do

- No cloud. No account. No sync.
- No message reading. Regards never looks at your email, SMS, or messenger history.
- No analytics, no trackers, no ads, ever.
- No AI suggestions for what to say. You know your people better than a model does.
- No subscription. One-time purchase with a 7-day free trial, plus an optional tip jar.

## Privacy — verifiable, not marketing

Regards makes a strong privacy claim and backs it up with technical, legal, and transparency guarantees:

- **Android: no `INTERNET` permission.** The Linux kernel denies socket creation to the app's UID. Network access is technically impossible, not just policy-forbidden.
- **iOS: no networking code in our modules.** App Transport Security is set to deny all loads. The only network-adjacent code in the app is StoreKit, which runs in a separate OS-provided framework.
- **All data at rest is encrypted.** iOS Data Protection on the DB file; Android uses SQLCipher with a key in the Android Keystore.
- **Contacts are read on-device only.** Writes (when you edit a contact from inside Regards) are scoped to the fields you touched and go through `CNSaveRequest` / `ContactsContract`. Regards never deletes, bulk-edits, or merges your system contacts.
- **Calendar access is optional, local-only, and read-only.** No OAuth calendar integrations — ever.
- **Source is available for audit.** Every line of code is publicly readable under the license below.
- **App Store and Play Store declarations:** "Data Not Collected" across the board.

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) §11 for the full privacy stack.

## Repository layout

This repo is the monorepo for both platforms. The two apps share no code at runtime — each is a native implementation of the same domain — but they share the design document, the domain specification, and this license.

```
.
├── ARCHITECTURE.md        Design doc. The source of truth for what we're building and why.
├── docs/
│   └── DOMAIN_MODEL.md    Platform-neutral entity + scheduling spec (shared between iOS and Android).
├── ios/                   Swift / SwiftUI app. Xcode project, SPM modules. Being built first.
├── android/               Kotlin / Jetpack Compose app. Multi-module Gradle. Built next.
├── LICENSE                PolyForm Noncommercial 1.0.0.
└── README.md              You are here.
```

## Tech stack

Regards is a one-person project, so the two apps are being built sequentially rather than in parallel — iOS first, Android next. Both are equally first-class once they ship; the order is a scheduling choice, not a statement of priority.

**iOS (in development)**
Swift 6 with strict concurrency, SwiftUI, GRDB.swift for persistence, StoreKit 2 for billing, WidgetKit for widgets. Minimum target: iOS 17.

**Android (next up)**
Kotlin, Jetpack Compose + Material 3, Room + SQLCipher, Play Billing Library 7, Glance for widgets. Minimum SDK: 28 (Android 9).

No cross-platform runtime. No KMP. The domain layer is ported between the two, not shared — see [`ARCHITECTURE.md`](./ARCHITECTURE.md) §6 and §14 for the rationale.

## Roadmap

- **V1 (in progress)** — Core reminder loop. iOS first, then Android. Contacts import, cadences, reminder windows, deep-link catalog for 12+ channels, local notifications, birthdays and anniversaries, widgets, in-app contact editing, virtual duplicate merging.
- **V1.1 — Holiday Pack (target: September).** Christmas-card list export with address editing, formatted for Shutterfly / Minted / Zola / Paper Culture import.
- **V2 candidates.** Email metadata integration (OAuth, read-only), Apple Watch / Wear OS companions, full localization for top non-English markets. Explicitly *not* V1.

See [`ARCHITECTURE.md`](./ARCHITECTURE.md) §14 for the full phased plan.

## Build journal

The entire build is being documented publicly, biweekly, on Substack — from before the first commit through post-launch retrospectives. Follow along if you want to see how an indie, privacy-forward mobile app is actually built.

**[Read the build journal →](https://sdahiya.substack.com/)**

## Contributing

This is a solo-developer project in its earliest phase. The code is source-available so you can **read, audit, learn from, and fork it for personal or educational use** — that's a core part of the privacy claim. Bug reports and feature suggestions via [GitHub Issues](../../issues) are welcome.

Pull requests are **not currently being accepted** while the architecture is still stabilizing. That will change once V1 ships. When it does, contributors will be asked to sign a CLA so the project retains the ability to relicense later if warranted.

Commercial use, resale, or redistribution of the code or a derivative app is **not permitted** under the license — see below.

## License

Regards is released under the **[PolyForm Noncommercial License 1.0.0](./LICENSE)**.

In plain English: you can read the code, run it locally, learn from it, fork it for personal or educational purposes, and audit the privacy claims. You **cannot** sell it, redistribute it commercially, or ship a paid fork to an app store.

This is "source-available," not "open source" in the OSI sense. The distinction matters to purists, and Regards respects it — this README will never call the project open source. The choice of PolyForm-NC over MIT/Apache is about protecting against commercial cloning while preserving every bit of the transparency that makes the privacy claim credible. See [`ARCHITECTURE.md`](./ARCHITECTURE.md) §11 for the full rationale.

---

Copyright © 2026 Siddharth Dahiya. Regards is a personal project, not affiliated with any employer.
