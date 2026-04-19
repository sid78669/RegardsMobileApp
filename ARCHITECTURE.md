# Regards — Architectural Design Document

**Status:** Draft v0.5 (talking-points / conversation-queue feature added to V2 candidates)
**Last updated:** 2026-04-19
**Audience:** Claude Code implementation agent + human reviewers
**Scope:** Native iOS (Swift / SwiftUI) + Native Android (Kotlin / Jetpack Compose) mobile app. Local-first. No backend. No passive messaging integrations.

> **Name:** Regards. The word means "warm remembrance sent to someone" — the exact feeling the app is designed to produce. Tagline candidates: *"Send your regards before it's been too long."* / *"Keep your people in your regards."*

---

## 1. Vision

Regards helps you keep up with the people who matter. It answers one question: **"Who have I been meaning to talk to, but haven't?"**

The user imports their device contacts, marks the ones they actively want to stay in touch with, sets a desired cadence per contact (weekly, monthly, quarterly, yearly, or custom), and picks a preferred way to reach out (call, SMS, WhatsApp, etc.). The app fires local reminders when a cadence elapses — but only during the *reminder windows* the user has chosen (evenings, weekends, lunch breaks — never in the middle of a workday). Tapping a reminder deep-links directly into the right app, with the right contact, ready to go.

## 2. What's in V1

1. Read-only import of device contacts.
2. Per-contact configuration:
   - Whether this contact is tracked.
   - Cadence (e.g., every 2 weeks).
   - Preferred communication channel (from a fixed catalog).
   - Optional: override reminder windows for this specific contact.
3. Global reminder-window preferences (the user picks allowed days + time ranges; reminders only fire inside those windows).
4. A "last talked" timestamp per contact, set by the user via a one-tap "Caught up" button on any reminder or contact detail screen.
5. Local notifications when a contact is overdue, batched into a digest at the next available reminder window.
6. Tap a reminder → deep-link to the preferred communication app, pre-scoped to that contact where the channel supports it. No message prefill.
7. Manual "I talked to X" logging from the contact detail screen.
8. Priority tiers so the user can distinguish inner circle from acquaintances.
9. **Upcoming Reminders view** — a forward-looking list of reminders coming in the next 14 days (or the user's chosen horizon), grouped by day. Lets the user get a head start — e.g., "I'll be near Alex tomorrow, let me reach out now" — and mark someone caught up before the reminder fires. Also shows which reminders will collapse into the next digest window.
10. **Birthday & anniversary reminders.** Annual-recurrence reminders for special occasions, read from two on-device sources:
    - **System Contacts**: `CNContact.birthday` and `CNContact.dates` on iOS; `ContactsContract.CommonDataKinds.Event` (`TYPE_BIRTHDAY`, `TYPE_ANNIVERSARY`) on Android.
    - **Local device Calendar** (EventKit on iOS, CalendarContract on Android) — optional user-granted permission, catches users who store birthdays in calendar-only.
    Fire as morning-of notifications (different default window from cadence reminders), deep-link to the contact's preferred channel. Feb 29 birthdays fall back to Feb 28 in non-leap years.
11. **In-app contact editing (write-back to system Contacts).** Users can edit a contact's standard fields — name, phone, email, postal address, birthday, anniversary, notes — directly from Regards without leaving the app. Edits write through to the system Contacts database via `CNSaveRequest` (iOS) / `ContactsContract` batch operations (Android). System Contacts remain the source of truth; Regards doesn't maintain a private copy. This sets us up for Holiday Pack (users can fill in missing addresses in-app before export).
12. **In-app duplicate detection & virtual merging.** Regards can detect likely duplicate contacts (same name + overlapping phone/email) and let the user group them under a single "reminder target" — so two entries for "Mom" don't produce two reminders. The merge is **virtual**: we never modify or combine the underlying system contacts. Regards stores a `ContactGroup` locally; scheduling, Upcoming, and notifications operate on the group. Users can unmerge at any time. See §7 for data model, §10 for the Merge Duplicates screen.
13. **Home screen & Lock Screen widget.** Small widget (iOS WidgetKit, Android Glance) showing the top 3 overdue contacts with tap-to-open-contact-detail. Medium size shows 5 contacts with channel icons. iOS 16+ Lock Screen widget shows count-only ("4 overdue"). Widgets read from a shared app-group container (iOS) or direct DB read (Android) — no network, no new permissions.

## 3. What's explicitly out of V1

- No reading of email, SMS, or messenger history. No OAuth connections.
- No Telegram TDLib. No WhatsApp Web. No Android notification listener. No SMS content observer. No call-log scraping.
- **No OAuth-based calendar integrations — ever.** No Google Calendar, Outlook, or Facebook birthday sync. These require network access and would break the privacy guarantee (§11). Users whose birthdays live in Google Calendar can subscribe to the Google Birthdays calendar from their device Calendar app, which we then read via the local Calendar permission — transitive coverage with no network access in our app.
- **No destructive contact operations.** Contact editing (V1 item #11) is additive and modifies single fields by user intent. Regards never deletes a system contact, never merges them in the system contact database, and never bulk-edits. Duplicate "merges" (V1 item #12) are virtual — only Regards' internal grouping changes; system contacts are untouched.
- No backend. No cloud sync across devices. No user account.
- No message sending or composing from the app. Reminders deep-link out; the actual message happens in the user's existing app.
- No AI suggestions for what to say.
- No timeline of historical interactions automatically populated from external sources.

These are explicit non-goals in V1 because:
1. Messaging integrations carry high API/ToS risk and require long certification cycles (Google CASA, Play Store restricted permissions, etc.).
2. The core value — "remind me to check in, at a reasonable time, in a way that lowers friction to actually doing it" — is fully deliverable without any of them.
3. Shipping the reminder UX first validates the product before we invest in integration work.

They remain on the roadmap (§14) as v2+ candidates.

## 4. Market position & business model

### Competitive landscape
This space exists but is not saturated, especially at the simple / privacy-forward / friends-and-family end.

| Competitor | Focus | Pricing (April 2026) | What we're not |
|---|---|---|---|
| **Dex** | Professional networking, heavy integrations, AI | $12/month flat | Not doing networking or AI. |
| **Covve** | Business contacts + news | Free up to 20 relationships, $9.99/mo Pro | Narrower focus; no news aggregation. |
| **Social Compass** | Friends & family cadences | Subscription | Closest direct competitor by positioning. |
| **Smart Contact Reminder** (Android) | Basic reminders | Free | Closest competitor feature-wise; weak reminder-window story. |
| **Mesh** (ex-Clay) | Network enrichment | Subscription | Different product entirely. |
| **UpHabit** | Pivoted to sales CRM in 2022 | N/A | Not a competitor anymore; cautionary tale about scope creep. |

### Differentiators

1. **Reminder-window awareness.** None of the competitors above treat "when is it OK to bug the user" as a first-class design concern. This is our lead pitch.
2. **One-tap deep link into the right app.** Reminders are action-oriented, not to-do lists.
3. **Privacy as a feature.** Local-first, no account required, no ads ever.
4. **Native apps on both platforms.** Most competitors are web-first with thin mobile wrappers.

### Revenue model: one-time purchase, no subscriptions, optional tip jar

The app is local-only with no server costs, so a subscription would be dishonest. Users pay once and get everything.

**Pricing is geo-tiered** using purchasing-power-parity anchors. $4.99 in the US is affordable, but at current FX rates that's ~₹425 in India (where comparable apps price at ₹79–₹99) and ~R$25 in Brazil (vs a R$5–10 norm). Using a single USD tier would effectively cut Regards out of the global market where the privacy pitch resonates most strongly. Both Apple (App Store Connect → Pricing and Availability → auto-pricing-per-storefront) and Google (Play Console → pricing templates with per-country overrides) natively support regional pricing; this is configuration, not code.

**Tier anchors (USD-equivalent, indicative — final values chosen from Apple/Google's tier tables):**

| Market cluster | Anchor | Examples | Unlock price | Coffee tip | Thanks tip | Feature tip |
|---|---|---|---|---|---|---|
| Tier A — high-income | $4.99 | US, CA, UK, AU, NZ, DE, FR, NL, SE, NO, DK, FI, IE, CH, AT, BE, JP, SG, HK, IL, AE | **$4.99** | $2.99 | $6.99 | $14.99 |
| Tier B — upper-middle | $2.99 | PL, CZ, GR, PT, ES, IT, KR, TW, CL, UY | **~$2.99** | $1.99 | $3.99 | $8.99 |
| Tier C — mid | $1.99 | MX, BR, AR, ZA, TR, MY, TH, SA, RO, HU | **~$1.99** | $0.99 | $2.99 | $5.99 |
| Tier D — lower-income | $0.99 | IN, ID, PH, VN, EG, PK, NG, BD, LK, KE, MA | **~$0.99** | — | $1.99 | $3.99 |

Actual storefront prices will be set using Apple/Google's nearest tier (e.g., India will land on ₹99 for unlock, ₹199 for Thanks tip; Brazil will land on R$9.90 / R$17.90). We'll anchor to these clusters and then let the auto-pricing sync feature maintain them as FX shifts.

| Item | Base (Tier A / US) | Notes |
|---|---|---|
| **Full app unlock** | $4.99 one-time | Single non-consumable IAP. Unlocks the entire app. No feature gates. Localized to each tier above. |
| **Free trial** | 7 days | Unlocked trial via StoreKit (iOS) / Play Billing grace mechanism (Android). Fully functional. Same duration globally. |
| **Tip: "Coffee"** | $2.99 | Non-consumable. Shown only in Settings → Support after purchase. No functional effect. Localized. |
| **Tip: "Thanks"** | $6.99 | Same. Localized. |
| **Tip: "Fund the next feature"** | $14.99 | Same. Localized. |

### Why this pricing

- **$4.99 is the "free without being free" price in developed markets.** Below psychological friction for anyone with an iPhone or modern Android in those markets, high enough to signal real quality. After the 15% App Store Small Business Program cut: ~$4.24 net per sale.
- **Geo-tiering reflects real purchasing power.** A $0.99 unlock in India is proportionally comparable to $4.99 in the US; charging a flat $4.99 globally is effectively a pricing-out exclusion. Indie apps (Overcast, Flighty, Halide) increasingly use PPP tiers and the data shows unit sales in emerging markets more than compensate for per-unit revenue loss.
- **Break-even math:** at blended ~$2.50 net per sale (heavier weight on Tier A/B early), year-one dev cost (~$530) breaks even at ~215 sales globally.
- **No free tier with contact caps.** Caps feel punitive. A trial + honest price is cleaner.
- **Tip jar is deliberate.** Daily users of indie utilities frequently want to pay more — Overcast, Flighty, and Ivory all prove this. It's not a paywall; the tips give nothing functional. They're a way to say thanks.
- **No ads, no analytics SDKs, no trackers of any kind, ever.** See §11 for the verification stack.

### Dev cost baseline

| Line item | Cost | Cadence |
|---|---|---|
| Claude Max subscription (~3 mo active dev) | ~$300 | one-time |
| Apple Developer Program | $99 | annual |
| Google Play Console | $25 | one-time |
| Domain | $12 | annual |
| Email (Cloudflare Email Routing) | $0 | — |
| Landing page (GitHub/Cloudflare Pages) | $0 | — |
| Affinity Designer v2 (icon + marketing art) | $70 | one-time |
| Bakery (icon export for iOS + Android adaptive) | $25 | one-time |
| Gemini (banner art — covered by existing subscription) | $0 | — |
| **Year 1 total** | **~$531** | |
| **Year 2+ ongoing** | **~$111/yr** | |

### Monetization mechanics

- **StoreKit 2 (iOS) + Play Billing Library 7 (Android)** for the unlock IAP and tip IAPs. Billing is handled entirely by platform; no developer-run server.
- **Entitlement check is on-device.** StoreKit receipt / Play Billing query. "Restore Purchases" button in Settings.
- **Trial handling:** StoreKit non-consumable trial on iOS; Android uses a pseudo-trial via a 7-day grace token written to the encrypted local DB on first launch. Graceful expiry UX — lock the app into a soft paywall, don't delete data.
- **Enroll in Apple Small Business Program + Google Play's equivalent** from day one for the 15% store cut.

### Revenue risks to flag

1. **Contacts permission denial kills the product.** Onboarding must earn it before asking.
2. **Niche ceiling.** "Personal CRM for friends" is real but small. Plan for a slow burn — Product Hunt, privacy-focused press (Privacy Guides, Tom's Guide, MacStories), App Store editorial pitch.
3. **No recurring revenue.** Year 2+ income depends entirely on new acquisition. Offset by near-zero ongoing costs and the tip jar from retained users.

## 5. High-level architecture

```
+---------------------------------------------------------------+
|                         UI layer                              |
|    SwiftUI (iOS)                |    Jetpack Compose (Android)|
+---------------------------------+-----------------------------+
|                   ViewModel / Presentation                    |
+---------------------------------------------------------------+
|                       Domain layer                            |
|                                                               |
|   Contact  |  Cadence  |  ReminderEngine  |  ReminderWindow  |
|   ChannelCatalog  |  DeepLinkBuilder                          |
|                                                               |
|  Pure Swift / pure Kotlin. No platform APIs. Unit-testable.   |
+---------------------------------------------------------------+
|                       Platform adapters                       |
|                                                               |
|   ContactsReader  |  NotificationScheduler  |  DeepLinker |   |
|   BillingAdapter  |  ContactPhotoLoader                       |
+---------------------------------------------------------------+
|                         Data layer                            |
|                                                               |
|   SQLite (GRDB on iOS, Room on Android)                       |
|   Encrypted at rest (iOS Data Protection / SQLCipher)         |
+---------------------------------------------------------------+
|                         Platform layer                        |
|   Contacts framework / ContactsContract                       |
|   UNUserNotificationCenter / NotificationManager              |
|   UIApplication.open / Intent.ACTION_VIEW                     |
|   StoreKit 2 / Play Billing                                   |
+---------------------------------------------------------------+
```

Note what's absent compared to v0.1: no integration sources, no TDLib, no OAuth, no background sync scheduler. The app is dramatically simpler to build and operate.

## 6. Tech stack

### iOS
- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI (iOS 17+)
- **Persistence:** GRDB.swift
- **Async:** Swift Concurrency
- **Notifications:** `UNUserNotificationCenter` with time-triggered local notifications
- **Contacts:** `Contacts.framework`
- **Deep linking out:** `UIApplication.shared.open(url)` with schemes declared in `Info.plist` under `LSApplicationQueriesSchemes`
- **Billing:** StoreKit 2
- **Min target:** iOS 17.0

### Android
- **Language:** Kotlin 2.x
- **UI:** Jetpack Compose + Material 3
- **Architecture libs:** Jetpack (ViewModel, Navigation-Compose, Lifecycle)
- **Persistence:** Room + SQLCipher
- **Async:** Kotlin Coroutines + Flow
- **Notifications:** `NotificationManagerCompat` + `AlarmManager.setExactAndAllowWhileIdle` for precise reminder-window timing (with `SCHEDULE_EXACT_ALARM` permission on Android 12+) or `WorkManager` with tight windows if exact alarms are refused
- **Contacts:** `ContactsContract`
- **Deep linking out:** `Intent(Intent.ACTION_VIEW, Uri.parse(...))` with `resolveActivity` fallback
- **Billing:** Play Billing Library 7
- **Min SDK:** 28 (Android 9). Target SDK: current stable.

### Shared
- This document + a sibling `DOMAIN_MODEL.md` defining entities in platform-neutral pseudocode.
- No KMP in V1. The domain is small and the platform specifics are the interesting part.

## 7. Data model

All local SQLite. No cloud, no sync.

```
Contact
  id: UUID (primary key)
  systemContactRef: TEXT UNIQUE     -- platform-native identifier from Contacts framework / ContactsContract
  displayName: TEXT
  photoRef: TEXT?                   -- derived from system contact; cached locally
  tracked: BOOLEAN                  -- false means imported-but-not-following
  cadenceDays: INTEGER?             -- null if tracked == false
  priorityTier: INTEGER (0-3)       -- 0 = inner circle
  preferredChannel: TEXT            -- enum, see ChannelCatalog
  preferredChannelValue: TEXT       -- e.g., phone number, email, handle — resolved at config time
  reminderWindowOverride: TEXT?     -- JSON blob; null means "use global"
  lastInteractedAt: INTEGER?        -- epoch seconds. Source of truth.
  notes: TEXT                       -- Regards-local; NOT written back to system Contacts
  contactGroupId: UUID?             -> ContactGroup.id  -- null = ungrouped; non-null = virtually merged
  createdAt: INTEGER
  archivedAt: INTEGER?

ContactGroup                        -- virtual merge targets; NOT written back to system Contacts
  id: UUID (primary key)
  displayName: TEXT                 -- user-chosen group name (defaults to primary contact's name)
  primaryContactId: UUID            -> Contact.id  -- the "face" of the group (photo, channel)
  createdAt: INTEGER
  createdBy: TEXT                   -- 'user' | 'suggestion_accepted' — for analytics on suggestion quality (stored locally, never exfiltrated)

ReminderWindow (global prefs, single row)
  id: INTEGER PRIMARY KEY CHECK (id = 1)
  allowedDaysMask: INTEGER          -- bitmask, Sun=1, Mon=2, ... Sat=64
  allowedTimeRangesJson: TEXT       -- e.g., [{start:"18:00", end:"22:00"}, {start:"12:00", end:"13:00"}]
  timezone: TEXT                    -- IANA, defaults to device

ScheduledReminder
  id: UUID
  contactId: UUID -> Contact.id
  kind: TEXT                        -- 'cadence' | 'birthday' | 'anniversary' | 'custom_occasion'
  occasionDate: TEXT?               -- ISO month-day (e.g., "02-29") for annual-recurrence kinds; null for cadence
  occasionLabel: TEXT?              -- free-text label for anniversaries / custom (e.g., "Wedding", "Met on Bumble")
  scheduledFor: INTEGER             -- epoch seconds, already snapped into an allowed window
  osNotificationId: TEXT            -- the identifier used when we scheduled it with UNUserNotificationCenter / AlarmManager, so we can cancel/replace
  state: TEXT                       -- pending | fired | cancelled | user_caught_up

  -- Note: we do NOT persist birthdays/anniversaries ourselves. They are re-read from
  -- system Contacts + local Calendar on each scheduling pass. This preserves the
  -- "system contacts are the source of truth" rule and sidesteps sync drift.

InteractionLog
  id: UUID
  contactId: UUID
  occurredAt: INTEGER
  source: TEXT                      -- 'manual' | 'reminder_tap' | 'reminder_caught_up'
  channel: TEXT?                    -- channel the user said they used, if manual entry specified it

UserProfile
  id INTEGER PRIMARY KEY CHECK (id = 1)
  onboardingCompletedAt: INTEGER?
  entitlementTier: TEXT             -- 'free' | 'plus_monthly' | 'plus_annual' | 'lifetime'
  entitlementRefreshedAt: INTEGER
```

**Key indexes:**
- `Contact(tracked, archivedAt)` — fast home-screen query.
- `Contact(contactGroupId)` — fast group membership lookup for scheduling.
- `ScheduledReminder(state, scheduledFor)` — fast "what's next?" lookup.
- `Contact(systemContactRef)` — fast re-import reconciliation.

**Re-import logic:** on every app launch + on Contacts change notification, we reconcile imported contacts against `systemContactRef`. New contacts are imported as `tracked=false`. Contacts that have been deleted from the device are marked archived (not deleted from our DB, since the user's cadence/log history may be valuable if they re-add the contact).

**Write-back logic (V1 feature #11):** `CNSaveRequest` / `ContactsContract` batch-update. We only write the fields the user explicitly edited (partial updates, not full-record replacement, so we don't stomp on data we didn't read). `notes` in our Contact row is Regards-local — we deliberately keep it out of the write-back pipeline to avoid polluting the user's system contacts with app-specific annotations.

**Duplicate-detection heuristic (V1 feature #12):** runs on-demand from Settings → "Find duplicate contacts". Candidate pairs are generated where any one of the following holds: (a) normalized display names match (case/diacritic-insensitive), (b) any phone number in E.164 form matches between two contacts, (c) any email (lowercased) matches. We present candidates ranked by strength (phone + name = high; name-only = low) and the user confirms each merge manually. Nothing auto-merges. The algorithm is local, deterministic, and testable without any system APIs — pure Kotlin/Swift on the normalized field set.

**Scheduling under virtual merges:** the ReminderEngine treats a `ContactGroup` as the reminder target when `contactGroupId` is non-null. `lastInteractedAt` is taken as the max across group members (interacting with any grouped contact counts). Preferred channel comes from `ContactGroup.primaryContact`. Upcoming/Overdue views display one row per group. Members retain their own rows in the All Contacts screen for clarity.

## 8. Channel catalog & deep linking

This is the differentiator section. V1 ships with this fixed catalog of channels. Each entry defines (a) how we ask the user for the channel value, (b) how we validate it, and (c) how we build the deep link.

| Channel | User supplies | Validation | iOS link | Android link | Notes |
|---|---|---|---|---|---|
| `phone_call` | phone | E.164 parse | `tel:+15551234567` | `tel:+15551234567` | Always works. |
| `sms` | phone | E.164 parse | `sms:+15551234567` | `sms:+15551234567` | iOS routes to iMessage if contact is iMessage-enabled. |
| `facetime` | phone or email | `facetime:15551234567` | N/A | iOS only. Hide on Android. |
| `email` | email | RFC 5322 | `mailto:alex@example.com` | `mailto:alex@example.com` | |
| `whatsapp` | phone | E.164, strip `+` | `https://wa.me/15551234567` | same | Universal link — graceful fallback to web if app missing. |
| `telegram` | @handle | handle regex | `https://t.me/alexc` | same | |
| `signal` | phone | E.164 | `https://signal.me/#p/+15551234567` | same | Requires the number be registered with Signal. We warn the user. |
| `messenger` | handle or m.me link | | `https://m.me/alexc` | same | |
| `instagram_dm` | @handle | handle regex | `https://ig.me/m/alexc` | same | |
| `linkedin_msg` | vanity handle or profile URL | | `https://linkedin.com/in/alex-chen` | same | Opens profile; user taps Message. |
| `discord` | username (display only) + optional user ID | | `discord://discord.com/users/USER_ID` if ID known, else `discord://` | same | Discord IDs aren't easily discoverable. If no ID, we open Discord generically and show the contact's username as a note. |
| `in_person` | — | — | none (no deep link) | none | Used for people the user prefers to see face-to-face; reminder fires but no link. |
| `custom` | arbitrary URL | URL parse | that URL | same | Escape hatch for anything we missed (Slack, Teams, Matrix, etc.). |

**Implementation:**
- `ChannelCatalog` is a pure-domain enum + lookup table per platform.
- `DeepLinkBuilder` takes a `(Channel, value)` pair and returns a platform-specific `URL` / `Uri`.
- Actually opening the URL is a thin platform adapter (`UIApplication.shared.open` on iOS; `Intent.ACTION_VIEW` + `resolveActivity` on Android).

**iOS `Info.plist` requirement:** every custom scheme above (`whatsapp`, `telegram`, `tg`, `sgnl`, `fb-messenger`, `instagram`, `discord`) must be declared under `LSApplicationQueriesSchemes` — otherwise `canOpenURL` returns false and users on iOS 9+ see no indication the app is installed. We always prefer universal HTTPS links where available (wa.me, t.me, ig.me, etc.) because they don't require this declaration and fall back to Safari gracefully.

**Android fallback:** `resolveActivity(packageManager, 0)` before launching; if null, show a toast "It looks like [App] isn't installed on this device — open it in the browser?" and offer the https fallback.

**Adding channels in V1.1+** requires an app update because of the `LSApplicationQueriesSchemes` constraint on iOS. Acceptable.

## 9. Reminder-window engine

This is the second differentiator. It gates every notification through user-defined "OK to remind me now" windows.

### Global reminder window configuration

The user picks:
- Allowed **days of the week**: e.g., Mon–Fri evenings + all day Sat/Sun.
- Allowed **time ranges** per day: one or more ranges per day (e.g., 18:00–22:00 + 12:00–13:00). V1 uses the same ranges for every allowed day to keep the UI simple; per-day ranges are a Plus-tier upsell.
- **Timezone:** defaults to device, honors DST automatically via platform calendar APIs.
- **Quiet hours:** an absolute "never between X and Y, even if in-window logic says yes." Hard override.

### Per-contact override

Any contact can override the global window (e.g., "never remind me about my boss before 9 am on a weekday"). Stored as `reminderWindowOverride` JSON. Falls back to global if null.

### Scheduling algorithm

Given:
- `now: Date`
- `contact.lastInteractedAt`, `contact.cadenceDays`
- Effective reminder window (per-contact override or global)
- Existing `ScheduledReminder` for this contact, if any

We compute:

```
overdueAt = lastInteractedAt + cadenceDays * 86400
targetFireTime = max(now, overdueAt)
scheduledFor = nextAllowedSlot(window, from: targetFireTime)
```

Where `nextAllowedSlot` walks forward day-by-day starting at `targetFireTime` and returns the earliest `(day, time)` that:
1. The day is allowed by `allowedDaysMask`.
2. The time falls inside one of `allowedTimeRanges`.
3. The time is not inside `quietHours`.

We then create (or replace, if a pending reminder already exists for the contact) a platform-level local notification for that time.

**Batching:** within a single reminder window, multiple overdue contacts collapse into one notification: *"3 contacts are overdue: Priya, Alex, Mom. Tap to see."* Tapping opens the Overdue view. This is critical — per-contact nag notifications are the #1 reason relationship apps get silenced.

**Re-evaluation triggers:**
- User marks a contact "Caught up" → cancel pending reminder, clear `scheduledFor`, update `lastInteractedAt`.
- User changes cadence → cancel & reschedule.
- User changes reminder windows → bulk-reschedule all pending reminders. (This is bounded by tracked-contact count, so it's cheap.)
- App launch / foreground → reconcile: cancel any orphaned OS notifications, re-verify scheduled times are still in-window (timezone changes, DST).

**Forward-looking queries (Upcoming view):** the engine exposes `upcomingReminders(horizonDays: Int) -> [ScheduledReminder]`. This returns all pending `ScheduledReminder` rows where `scheduledFor` falls in `[now, now + horizonDays]`, sorted ascending, joined with the `Contact` row for rendering. Since scheduled reminders are already persisted (we don't re-derive them on the fly), this is an indexed single-query read — no recomputation cost. The Upcoming screen observes this as a reactive stream (Combine publisher / Kotlin Flow) so it updates instantly when the user marks someone caught up from that view.

### Annual recurrence (birthdays & anniversaries)

Occasion reminders follow a parallel scheduling path, sharing the notification plumbing and batching logic but with different inputs:

**Source aggregation.** On each scheduling pass (app launch, Contacts/Calendar change, post-occasion advance), the engine queries:
1. System Contacts — `CNContact.birthday` + `CNContact.dates` (iOS); `ContactsContract.CommonDataKinds.Event` (Android).
2. Local device Calendar, if permission granted — EventKit events with `EKEventKind.birthday` or titles matching birthday/anniversary patterns (iOS); CalendarContract events on the auto-generated birthdays calendar (Android).
3. Merges by system-contact ID; Calendar is a fallback when Contacts has no date.

**Scheduling.** For each occasion:
```
nextOccurrence = next (month, day) ≥ today for that contact
  — special case: (Feb 29) → (Feb 28) in non-leap years
scheduledFor = morning-of at user's "occasion notification time" (default: 09:00 local)
```
A separate default window is used for occasions (morning-of, not evening) because the user needs to act early in the day, not on their way to bed.

**Firing.** Birthday notification copy: *"🎂 It's Priya's birthday today — open WhatsApp?"* Same deep-link targets as cadence reminders. After firing, the engine advances `nextOccurrence` by one year and re-schedules.

**No double-up.** If a contact has both a cadence reminder overdue and a birthday today, the birthday wins and the cadence reminder is marked `user_caught_up` (birthday interaction counts as staying in touch).

**Privacy note.** Calendar access is optional. The app works fine with just Contacts permission; Calendar permission is a gentle upsell in Settings, never a blocker.

### Platform nuance

**iOS:** `UNCalendarNotificationTrigger` is the right primitive. We use non-repeating triggers; the reminder engine re-schedules after each fire. iOS caps pending notifications at 64 per app — a trivial limit for us (we only schedule the next reminder per contact, so ~N contacts ≤ 64 is fine; contacts with overlapping times collapse into the batched notification anyway, one pending per window).

**Android:** `AlarmManager.setExactAndAllowWhileIdle` with `SCHEDULE_EXACT_ALARM` permission (Android 12+). If the user denies the exact-alarm permission, we fall back to `WorkManager` with a short flex window — reminders may fire 5–15 minutes later than planned, which is acceptable. On Android 14+, the app needs to be in a role or have the exact-alarm permission granted; we request it gracefully.

## 10. UI / UX architecture

Eight screens + one widget family in V1:

1. **Home / Overdue** — lists contacts overdue right now, sectioned by priority tier. Each row: photo, name, "2 weeks overdue", preferred-channel icon, big tap target (opens deep link), swipe to "mark caught up" or "snooze 1 week". Segmented control at top toggles between **Overdue** and **Upcoming**. Virtually-merged contacts (§7) appear as a single row using the group's primary contact as the face.
2. **Upcoming** — forward-looking timeline of reminders scheduled in the next 14 days (user-configurable horizon: 7 / 14 / 30 days). Grouped by day ("Tomorrow — Thu Apr 16", "Fri Apr 17", etc.) with collapsed-days summary. Each row shows contact, channel icon, and the scheduled time-of-day within their reminder window. Swipe actions: **Reach out now** (opens deep link, logs interaction, advances cadence) and **Mark caught up** (skips this reminder, advances cadence). Tap row → Contact Detail. Useful for proactive catching-up: "I've got a spare 15 minutes, who's up next?"
3. **All Contacts** — lists all tracked contacts, sectioned by priority or sorted by next-reminder date. Search. Tap to configure. Shows group-membership indicator where applicable.
4. **Contact Detail** — photo, cadence, channel, reminder-window override, priority, **next scheduled reminder**, last interaction, recent log entries, big "Open [channel]" button, "I talked to them" manual log button, **"Edit contact" button** (opens screen #5), **"Merged with..." disclosure row** when part of a group (tap → group management).
5. **Edit Contact** — form that mirrors system-contact fields: name, phone numbers, emails, postal addresses, birthday, anniversary dates. Save writes through to system Contacts via `CNSaveRequest` / `ContactsContract`. Partial-update semantics: only fields the user touched are written back. Regards-local `notes` field is visible but clearly labeled as "private to Regards, not saved to your address book."
6. **Merge Duplicates** (Settings entry point) — presents ranked candidate duplicate pairs (§7 heuristic). For each pair: side-by-side preview, user picks primary face, confirms to create a `ContactGroup`. Undo is one tap. Also supports manually linking any two contacts the heuristic missed.
7. **Settings** — global reminder windows, quiet hours, timezone, notification digest time, occasion notification time, Upcoming view horizon (7/14/30 days), "Find duplicate contacts" entry, entitlement / upgrade, export data, delete data, Transparency screen.
8. **Onboarding** — sells the concept in 3 screens, then requests Contacts permission (read + write), then offers optional Calendar permission for birthday coverage, then walks the user through setting up their first 3–5 contacts to get immediate value.

**Widget family (iOS WidgetKit + Android Glance):**

- **Small widget** (2x2): top 3 overdue contacts, photo + name + "Xd overdue". Tap opens the app to that contact's detail screen. Refreshes on `TimelineProvider` cadence (iOS) / `GlanceAppWidget` update (Android) whenever the app updates state.
- **Medium widget** (4x2): top 5 overdue with channel icons visible, designed so tapping a channel icon deep-links directly (iOS supports per-element tap targets via `widgetURL`; Android supports per-view `setOnClickPendingIntent`).
- **iOS Lock Screen widget** (inline + circular variants, iOS 16+): count-only — *"4 overdue"*. Tap opens the app.
- **Data access:** widget reads from a shared App Group container on iOS (shared SQLite file opened read-only) and direct shared DB read on Android. No IPC round-trip to the main app needed, so widget rendering stays under the platform's strict time budgets.
- **Privacy:** no new permissions, no network, no widget-specific entitlements beyond App Groups (iOS). Widget respects the "data not collected" posture.

State shape is identical across platforms — SwiftUI `OverdueViewState` and Compose `OverdueUiState` have the same fields in the same order.

## 11. Privacy & security — verifiable, not marketing

The app's privacy claim is "no data collected, no call-home, ever." We stack technical, legal, and transparency guarantees so the claim is provable, not merely written in a footer.

### Data handling inside the app

1. **Contacts access is read + scoped-write, always local.** We read name, photo, phone numbers, email addresses, postal addresses, birthday, anniversary, and system identifier. We write only when the user explicitly edits a contact from the Edit Contact screen, and only the specific fields the user changed — never bulk-writes, never deletions, never merges in the system contact database. All writes happen on-device via `CNSaveRequest` / `ContactsContract`; no network is involved. This does require the expanded `WRITE_CONTACTS` permission on Android (in addition to `READ_CONTACTS`); on iOS, the same `NSContactsUsageDescription` covers both, but the usage-description string explicitly mentions "edit contacts from within Regards" so users grant informed consent.
2. **Minimum necessary fields imported.** Name, photo, phone numbers, email addresses, postal addresses (for Holiday Pack in V1.1), birthday, anniversary date(s), system identifier. Nothing else.
3. **Calendar access is local-only and optional.** When granted, we read events flagged as birthdays/anniversaries from the device Calendar (EventKit / CalendarContract). We do **not** write to Calendar, sync to any remote calendar service, or use any OAuth-based calendar API. Calendar permission can be denied or revoked without breaking the app — birthdays fall back to the Contacts source.
4. **All data at rest is encrypted.**
   - iOS: `NSFileProtectionCompleteUntilFirstUserAuthentication` on the DB file.
   - Android: Room + SQLCipher, key in Android Keystore.
5. **Data export / delete.** "Export my data" produces a JSON archive to the user's Files/Storage. "Delete everything" wipes DB + Keychain/Keystore entries + resets to first-run state.
6. **Permission transparency.** Contacts and Calendar permissions are each preceded by a pre-prompt screen explaining the exact fields we read and why.

### Technical anti-call-home guarantees

**Android — nuclear-tier guarantee:**
- **Do not declare `android.permission.INTERNET` in `AndroidManifest.xml`.**
- Without this permission the Linux kernel denies socket creation to the app's UID. Network access is technically impossible — not just policy-forbidden. This is the single strongest guarantee we can make on any mobile platform.
- Play Billing runs in a separate system process and does not require our app to hold INTERNET permission.
- This rules out any SDK that requires network: no Firebase, no Crashlytics, no analytics, no ad SDKs, no remote config. We must enforce this in code review — any new dependency that needs INTERNET breaks the guarantee.

**iOS — strongest-available guarantee:**
- Do not link `URLSession` / `Network.framework` code in our own modules. StoreKit is a separate OS-provided framework and exempt.
- `Info.plist` ATS config:
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsArbitraryLoads</key><false/>
      <key>NSAllowsArbitraryLoadsInWebContent</key><false/>
      <key>NSAllowsLocalNetworking</key><false/>
  </dict>
  ```
- No networking background modes declared in capabilities.
- Ship a `PrivacyInfo.xcprivacy` privacy manifest declaring zero tracking domains and zero data collected.
- Omit `AppTrackingTransparency` code entirely — we're not tracking, so we don't need the prompt.

### Legal / store declarations

- **App Store privacy nutrition label:** "Data Not Collected" across every category. ("Collected" specifically means transmitted off-device; local read/write of the user's own contacts is not collection under Apple's definition.)
- **Play Store Data Safety form:** "No data collected" and "No data shared." The form separately asks whether the app accesses sensitive user data on-device — we answer yes (contacts, calendar) and that the data stays on-device.
- Both platforms review these declarations; false claims are a rejection offense and retroactively a policy violation.

### Transparency artifacts (what makes the claim credible)

1. **Source-available on GitHub under [Polyform Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/).** The code is publicly readable, auditable, and forkable for personal / educational use — but commercial use and redistribution are legally forbidden. This gives ~95% of the trust benefit of full open source (researchers, journalists, and privacy-conscious users can audit every line) while retaining legal protection against commercial cloning. We *do not* call this "open source" publicly — it's "source-available" — because that's accurate and respects the OSI definition.
2. **Published [Exodus Privacy](https://reports.exodus-privacy.eu.org/) report** for each Android release. Free automated tracker scan; a "0 trackers, 0 permissions-beyond-Contacts" report is marketable.
3. **Network-capture demo.** One-page writeup + short video showing Proxyman / Little Snitch running during a full usage session — zero outbound connections outside StoreKit / Play Billing.
4. **Reproducible Android builds** documented in the repo so a third party can rebuild the APK from source and compare hashes.
5. **In-app "Transparency" screen** in Settings. In plain language: "This app cannot connect to the internet on Android. It has no networking code on iOS. Source code: [link]. Audit reports: [link]."
6. **Privacy Guides submission.** [privacyguides.org](https://www.privacyguides.org/) has a strict review process aligned with our posture; acceptance is high-authority social proof in the privacy-conscious community. (Note: Privacy Guides historically prefers OSI-approved licenses; we'll need to make a case for Polyform-NC eligibility.)
7. **Optional one-time third-party audit** (e.g., Cure53, Trail of Bits) once the app has traction and revenue. Not a V1 requirement; a "once we've made $5k" stretch goal.

### License rationale (decision lock-in)

We publish under Polyform Noncommercial, not MIT/Apache, for three reasons:
- **Protection against commercial cloning.** Someone who lifts our code, rebrands, and ships on the App Store is infringing and subject to DMCA takedowns.
- **No loss of privacy credibility.** Readers can still see every line; the source-available distinction matters to purists but not to end-user trust.
- **Flexibility to relicense later.** If the app eventually justifies a fully open-source posture, we can dual-license or switch — the Noncommercial license is a floor, not a ceiling.

Contributors will be asked to sign a CLA granting us relicense rights, so we retain the option to change terms later.

### What we explicitly do NOT claim

- We don't claim Apple / Google don't collect OS-level telemetry about the app. They do, and that's outside our control.
- We don't claim the app is "certified" by anyone official — there's no FDA-equivalent for app privacy. Our claim is that the *artifacts above* make the promise verifiable.

## 11a. Support & feedback mechanism

All channels are backend-free and cost $0–$12/year total.

1. **`support@[app-domain]` via Cloudflare Email Routing.** Forwards to the developer's inbox. In-app "Contact support" button opens `mailto:` with a pre-filled subject `[{AppName} {version} / {OS} / {device}] ` and the body prepopulated with (non-identifying) diagnostic context the user can review and edit before sending.
2. **GitHub Issues (public).** Because source is published on GitHub (under Polyform-NC), Issues becomes the bug tracker and feature backlog at no cost. Users can file, upvote, and watch.
3. **Public roadmap** on a GitHub Projects board: Shipped / In Progress / Considering / Not Doing.
4. **User-initiated diagnostic report.** When the user taps "Send diagnostics" the app assembles crash history + recent-errors + OS/device metadata into a `mailto:` draft the user reads before sending. We never collect automatically. This is the privacy-compatible alternative to Sentry/Crashlytics.
5. **App Store & Play Store review responses.** For the first year, respond to every review publicly. High-leverage word-of-mouth signal.
6. **Community channel (optional, Phase 4+).** A subreddit or Discord, launched only once there are ~500+ active users. Before that it's a ghost town.

What we explicitly do NOT use:
- Zendesk, Intercom, or any help-desk SaaS — overkill at our volume and a privacy risk.
- In-app chat — requires a backend.
- Automated crash reporting — violates the privacy guarantee.

## 11b. Build-in-public journal

We document the build on **Substack**, biweekly, from before the first line of code is written through post-launch retrospectives. The journal is a customer-acquisition channel, a transparency artifact, and a design log.

### Why Substack (vs. alternatives)

- Free, zero-maintenance, owns the email distribution.
- Substack Recommendations network drives compounding discovery in the indie-dev / privacy-forward niche.
- Cross-posts cleanly to Hacker News, Indie Hackers, r/SideProject, X/Bluesky.
- Alternatives considered: Ghost (~$9/mo, overkill), blog on app domain (no discovery), Hashnode (wrong audience).

### Cadence & content mix

- **Biweekly** posts. Weekly sounds good and isn't sustainable past ~6 weeks.
- Content buckets, roughly even split: (a) progress updates with numbers, (b) technical deep-dives (reminder-window algorithm, deep-link catalog, no-INTERNET-permission setup), (c) business decisions (pricing, licensing, naming), (d) user stories post-launch.

### Editorial voice

The journal talks about **what I'm building and why**, not **what others get wrong**. When other apps naturally come up (Fabriq, Garden, Catchup, Friend Reminder, Socially, Cloze, Contacts Journal, etc.), the tone is appreciative and additive: these apps proved people will pay attention to their relationships, and Regards exists because I wanted a slightly different slice — one-time purchase, verifiable no-cloud, deep-link heavy. Comparisons are factual and non-pejorative; no "they get it wrong, I get it right" framing. Readers sniff out competitive resentment instantly; genuine respect reads as confidence.

### First-quarter editorial calendar

| # | Post | Publish |
|---|---|---|
| 1 | "Why I'm building Regards in the open" — origin story + thesis | Before first commit |
| 2 | "The apps that came before Regards" — appreciative tour of Fabriq, Garden, Catchup, Friend Reminder, Socially, Cloze, Contacts Journal; what each does well, and the specific slice Regards is aiming for | Week 2 |
| 3 | "Designing reminders that respect your time" — reminder-window differentiator | Week 4 |
| 4 | "No servers, no ads, no call-home: how to prove it" — privacy stack deep-dive | Week 6 |
| 5 | "Choosing a source-available license" — the Polyform decision | Week 8 |
| 6 | "Deep-linking into 12 messaging apps" — §8 table as standalone post (SEO magnet) | Week 10 |
| 7 | "Pricing Regards at $4.99: the math and the feeling" — one-time vs subscription economics, framed as a bet on a different customer, not a critique of subscriptions | Week 12 |
| 8 | "First TestFlight build" | On TestFlight milestone |
| 9 | "Launch day" | On public launch |
| 10 | "First 30 days with Regards" — retro with real numbers | 30 days post-launch |
| 11 | "Reading birthdays without phoning home" — how Calendar + Contacts give us annual reminders without ever touching a network | Anchor post for v1.0 birthdays feature |
| 12 | "A holiday card list, no spreadsheet wrangling" — V1.1 Holiday Pack launch | Early October (paired with V1.1 ship) |

### Integration with the app and repo

- Settings → "Behind the App" opens the journal in Safari / Chrome.
- App Store + Play Store listings link to the journal.
- Landing page has "Follow the build journal" above the fold.
- GitHub README header links to the journal.
- Every journal post links to: the app download, the GitHub repo, and the previous 1–2 related posts. This is the compounding loop.

### Realistic target

~400 email subscribers at the 12-month mark. The journal converts readers to customers — engagement matters more than list size.

## 12. Module / package layout

### iOS (single Xcode project, SPM modules) — primary platform

```
Regards/
  App/                 — entry, DI
  Features/
    Overdue/
    Upcoming/
    Contacts/
    ContactDetail/
    EditContact/
    MergeDuplicates/
    Onboarding/
    Settings/
    Paywall/
  Widget/              — WidgetKit extension target, reads from App Group shared container
  Domain/              — Contact, ContactGroup, Cadence, ReminderWindow, ReminderEngine, ChannelCatalog, DeepLinkBuilder, DuplicateDetector
  Data/                — GRDB schema, migrations, repositories, ContactsWriter (CNSaveRequest wrapper)
  Platform/
    ContactsImport/
    CalendarImport/
    Notifications/
    DeepLinks/
    Billing/           — StoreKit 2
  RegardsTests/
  RegardsUITests/
```

### Android (multi-module Gradle, Kotlin DSL) — follow-on port after iOS launch

```
:app                    — entry, Hilt, nav graph
:feature:overdue
:feature:upcoming
:feature:contacts
:feature:contact-detail
:feature:edit-contact
:feature:merge-duplicates
:feature:onboarding
:feature:settings
:feature:paywall
:widget                 — Glance AppWidget
:domain                 — pure Kotlin (port of iOS Domain module; same entities, same rules, same tests)
:data                   — Room, SQLCipher, ContactsContract writer
:platform:contacts
:platform:calendar
:platform:notifications
:platform:deeplinks
:platform:billing       — Play Billing Library 7
```

## 13. Testing strategy

- **Domain layer: 100% unit-test coverage.** The reminder-window scheduler has real edge cases (DST, timezone changes, contiguous-range collapse, same-day cadence, midnight boundaries). A pure-function test suite pays back within a week.
- **Platform adapters:** contract tests + fakes for the Contacts reader, notification scheduler, and deep linker. Integration test on emulator/simulator that an `SCHEDULE_EXACT_ALARM` denial gracefully falls back to WorkManager.
- **Deep-link catalog test:** parametric test — one entry per channel — that asserts the builder produces the expected URL for a canned (channel, value) input. Catches typos in Info.plist or manifest.
- **UI snapshot tests** for Overdue, Upcoming, Contact Detail, Edit Contact, Merge Duplicates, Onboarding, and Widget across state permutations (empty, lots-of-contacts, past-due, all-caught-up, trial-expired, post-purchase).
- **StoreKit / Play Billing** tested with sandbox accounts + CI smoke that restore-purchases works from a fresh install.

## 14. Phased roadmap

The app ships on **iOS first, Android second**. Rationale: Apple's review cycle is longer and more variable, so starting iOS gives us earlier feedback; the domain layer developed for Swift serves as a validated reference when we port to Kotlin (same entities, same scheduling rules, same tests — a test-suite-driven port is faster than greenfield); going single-platform-at-a-time keeps the scope focused. We retain the "native on both platforms, no KMP" decision — porting is fine, shared code is not the goal.

### iOS track (primary)

**iOS Phase 0 — Domain + UI shell (2 weeks)**
- Data model, migrations, repositories (GRDB).
- Domain layer including ReminderEngine with full unit tests.
- Eight-screen nav shell with mock data.
- No system integrations yet (Contacts, Calendar, notifications, widgets are mocked).

**iOS Phase 1 — Core integrations (3 weeks)**
- Contacts permission (read + write) + import flow.
- Calendar permission (optional) + birthday ingestion.
- Reminder-window configuration UI.
- Local notification scheduling end-to-end (cadence + annual-recurrence paths).
- Deep-link catalog for every channel in §8.
- Edit Contact screen with `CNSaveRequest` write-back.
- Merge Duplicates screen with local heuristic.
- Onboarding flow.

**iOS Phase 2 — Widget + monetization + polish (2 weeks)**
- WidgetKit widgets (small, medium, Lock Screen) reading from App Group shared container.
- StoreKit 2 integration with geo-tiered pricing configured in App Store Connect.
- 7-day trial flow, paywall, tip jar.
- Accessibility pass (Dynamic Type, VoiceOver, Reduce Motion respect).
- Localization scaffolding (English at launch; strings wrapped for later language packs).

**iOS Phase 3 — Submission & launch (1–2 weeks elapsed, mostly Apple wait time)**
- App Store Connect listing + Privacy Nutrition Label.
- `PrivacyInfo.xcprivacy` manifest.
- TestFlight internal → external beta.
- Public launch: Product Hunt, indie press, Substack "launch day" post.

**iOS total elapsed: ~8 weeks of dev + Apple review buffer.**

### Android track (follow-on, starts after iOS public launch)

**Android Phase 0 — Port domain + UI shell (1.5 weeks)**
- Re-implement the domain layer in pure Kotlin, driven by the iOS test suite translated to JUnit. Same types, same rules, no algorithmic drift.
- Room + SQLCipher schema matching the iOS GRDB schema.
- Compose nav shell for the eight screens.

**Android Phase 1 — Core integrations (2.5 weeks)**
- ContactsContract read + scoped-write.
- CalendarContract (optional).
- `AlarmManager.setExactAndAllowWhileIdle` scheduling + WorkManager fallback.
- Deep-link catalog (intent-based where possible, HTTPS universal links where available).
- Edit Contact + Merge Duplicates screens.
- Onboarding.

**Android Phase 2 — Widget + monetization + polish (1.5 weeks)**
- Glance widgets.
- Play Billing Library 7 with geo-tiered pricing configured in Play Console.
- Accessibility (TalkBack, large-text support).

**Android Phase 3 — Submission & launch (1 week)**
- Play Console listing + Data Safety form.
- Exodus Privacy report published.
- Internal → closed → open testing.
- Public launch: cross-posted to Substack, r/androidapps, DroidCon communities.

**Android total elapsed: ~6 weeks after iOS launch.**

### V1.1 — Holiday Pack (target: September drop, ahead of holiday-card season)
- **Christmas / holiday card list export.** Generate CSV (and optionally XLSX) of tracked contacts with mailing addresses, formatted to match Shutterfly / Minted / Zola / Paper Culture address-book import schemas (First, Last, Address1, Address2, City, State, Zip, Country).
- **Address editing UI** — surfaces the postal-address fields from system Contacts (`CNPostalAddress` / `StructuredPostal`) so users can review and fill gaps before exporting. Edits write back to system Contacts (with explicit user confirmation per record), keeping system Contacts as the source of truth.
- **Holiday list curation** — let the user pick "this contact gets a card" as a separate flag from "tracked for reminders" (Aunt Marge gets a card every year but doesn't need a monthly check-in reminder).
- Why September: gives users 6–8 weeks of lead time before peak Shutterfly ordering season (early-to-mid November), and gives us a clean "feature shipped for the holidays" Substack post in early October. Also avoids the November content traffic-jam from every other indie dev's holiday push.

### V2 candidates (explicitly not V1)
- **Talking points / conversation queue.** A running list of things the user wants to bring up next time they talk to a specific contact (e.g., *"ask about her new job"*, *"share photo from the trip"*, *"follow up on his dad's surgery"*). Items can be added any time from Contact Detail, from a share-sheet action on another app ("remember to tell Priya about this article"), or via Siri/Google Assistant shortcut. When the reminder fires for that contact, the notification preview surfaces the count (*"3 things to bring up with Priya"*) and tapping it opens a talking-points list before deep-linking out to the chosen channel. After the interaction, the user can tick items off individually or bulk-clear with the "Caught up" action. Data model: new `TalkingPoint` table keyed by `contactId` (or `contactGroupId` when the contact is part of a virtual merge), with `body`, `createdAt`, `discussedAt?`, and `source` ('manual' | 'share_sheet' | 'siri'). Stored locally and encrypted at rest like the rest of the DB; private to Regards — never written to system Contacts. The **surface-at-reminder-time** behavior is the differentiator vs. competitors' static-notes implementations, and fits the app's "lower the friction to actually reaching out" thesis.
- Email integration (Gmail + Outlook via OAuth, metadata-only).
- Telegram integration via TDLib.
- Android SMS + call log integration.
- iOS Share Extension / Android Share Intent for logging from other apps.
- iCloud / Google Drive-backed sync across devices.
- Contact "streaks" & stats (Plus teaser).
- ICS file import as a fallback for users with non-standard calendar setups.
- Full localization for top-5 non-English languages (ES, PT-BR, JA, DE, FR) once we have data on which markets convert best.
- Apple Watch / Wear OS companion app.

## 15. Open questions

1. **Android exact-alarm permission (Android track).** Will users grant `SCHEDULE_EXACT_ALARM`? If denial rate is high, reminder precision suffers. Measure in Android closed beta; consider a clear onboarding card explaining why the app asks.
2. **Discord user IDs.** Without an easy way for users to obtain their contacts' Discord user IDs, deep linking into a specific DM is unreliable. V1 behavior: open Discord generically with a note showing the username. Acceptable?
3. **Contacts WRITE permission acceptance rate.** Adding write access expands what the permission prompt says. Some users may decline. Fallback: if write is denied, Edit Contact screen shows a "this requires Contacts write permission" state with a direct link to Settings. Measure decline rates in iOS TestFlight; if high, consider splitting into separate read and write prompts.
4. **Duplicate-detection heuristic tuning.** Starting with name + phone/email match. We need to test on real address books (contacts with shared family emails, contacts with international phone formatting) to tune false-positive vs false-negative rates. Add instrumentation (local-only counters, never exfiltrated) for how many suggestions are accepted vs dismissed so we can iterate the algorithm.
5. **Widget refresh cadence.** iOS WidgetKit budgets timeline updates aggressively. If overdue-list changes more often than the budget allows updates, the widget lags. Mitigation: also trigger a timeline reload via `WidgetCenter.shared.reloadAllTimelines()` from the main app whenever it updates state, so the widget stays fresh while the main app is actively used.
6. **Geo-tier reconciliation over time.** FX rates drift; Tier D markets could drift into "too cheap" or "now reasonable" territory. Decision: review Apple/Google auto-pricing quarterly for the first year, then annually. Document the review in a Substack post so the pricing stays transparent.
7. **Android launch timing vs iOS feedback.** Rigid iOS-first means Android users wait ~3 months. Risk: Android-first would-be buyers forget or find alternatives. Mitigation: capture email on the landing page for "notify me when Android ships."

## 16. Decisions log

| # | Decision | Date | Rationale |
|---|---|---|---|
| 1 | V1 ships with NO passive messaging integrations | 2026-04-15 | Ship the core reminder UX first; integrations are risky and can wait. |
| 2 | Native on both platforms, no KMP | 2026-04-15 | Shared logic is small; platform APIs are the interesting part. |
| 3 | Local-first, no backend | 2026-04-15 | Trust is the moat. Contacts + cadence is too personal for a server. |
| 4 | Reminder-window gating is first-class | 2026-04-15 | Unique positioning vs. Dex/Covve/Smart Contact Reminder. |
| 5 | Universal HTTPS deep links preferred over custom schemes | 2026-04-15 | Graceful web fallback; fewer Info.plist declarations. |
| 6 | Batched digest notification, not per-contact | 2026-04-15 | Per-contact nags get the app silenced. |
| 7 | One-time $4.99 + tip jar, no subscriptions, no ads ever | 2026-04-15 | Local-only app; subscription would be dishonest. Tip jar captures supporter goodwill. |
| 8 | No free tier with contact caps; 7-day trial instead | 2026-04-15 | Caps feel punitive; trust-forward positioning requires trusting the user with the full app. |
| 9 | Android: no `INTERNET` permission; iOS: ATS-deny + no networking code | 2026-04-15 | Kernel-enforced guarantee on Android; verifiable-by-source on iOS. |
| 10 | Source-available on GitHub under Polyform Noncommercial 1.0.0 | 2026-04-15 | ~95% of the privacy-claim credibility of MIT/Apache, with legal protection against commercial cloning. |
| 11 | Support via mailto:, GitHub Issues, manual diagnostics; no SaaS help desk | 2026-04-15 | Backend-free; preserves the zero-data-collection posture. |
| 12 | Named the app **Regards** (working title "Stay In Touch" conflicted with Fabriq's subtitle) | 2026-04-15 | Chose from shortlist after checking App Store / Play Store / trademark collisions. Rejected: Wick (dating-app vibe), Kept (too vague standalone), Ember/Kith/Tend/Hearth/Cairn/Recall/Keepsake/Lore/Revere (all taken in adjacent categories), Sincerely (crowded by *Sincerely - Off My Chest*). Regards wins on clarity, warmth, and searchability. |
| 13 | Document the build publicly on Substack, biweekly | 2026-04-15 | Customer-acquisition channel + transparency artifact + design log. |
| 14 | Birthday & anniversary reminders ship in V1, not V2 | 2026-04-15 | Table-stakes for the category. Both platforms expose dates from system Contacts for free; scope increment is modest (new `kind` on ScheduledReminder + annual-recurrence path). |
| 15 | Calendar access is local-only via EventKit / CalendarContract; OAuth calendar integrations (Google, Outlook, Facebook) are permanently out-of-scope | 2026-04-15 | OAuth calendar would require INTERNET permission on Android and break ATS-deny on iOS, collapsing the verifiable-privacy guarantee. Users whose birthdays live in Google Calendar can subscribe via their device Calendar app, which we read locally — transitive coverage, no compromise. |
| 16 | Holiday card export shipped as V1.1 in September, not bundled into V1 | 2026-04-15 | Single-season utility, narrow use case, depends on address data most users haven't populated. Better as a focused "shipped for the holidays" drop with 6–8 weeks lead time before peak Shutterfly ordering. |
| 17 | V1 includes in-app contact editing with write-back to system Contacts | 2026-04-15 | Needed to support address editing for V1.1 Holiday Pack; also a standalone quality-of-life win. Writes stay on-device (CNSaveRequest / ContactsContract) so privacy posture is unchanged. Adds WRITE_CONTACTS permission to Android manifest. |
| 18 | V1 includes virtual-merge duplicate detection; system Contacts are never modified for merges | 2026-04-15 | Users with messy address books generate duplicate reminders without this. Virtual merge via a local `ContactGroup` table avoids touching the user's authoritative contacts database. |
| 19 | V1 includes WidgetKit / Glance widget | 2026-04-15 | Moved up from V1.1 per user request. Small scope, no new permissions, reads via App Group shared container. Significant retention boost per indie-app pattern. |
| 20 | iOS ships first; Android follows after iOS public launch | 2026-04-15 | Apple review cycle is longer and more variable; starting iOS gives earlier market feedback. Domain layer built for Swift becomes the validated reference for the Kotlin port. No KMP — we port, not share. |
| 21 | Pricing is geo-tiered via Apple/Google auto-pricing, anchored on $4.99 US (Tier A) down to $0.99 (Tier D) | 2026-04-15 | Flat $4.99 globally prices out emerging markets where the privacy pitch resonates strongly (India, Brazil, Indonesia). PPP-adjusted tiers expand addressable market without adding operational cost (platforms handle the conversion). |
| 22 | Talking points / conversation queue deferred to V2 | 2026-04-19 | Common feature in the category (Dex has "notes per contact", Monica has "things to remember", UpHabit pre-pivot had "talking points", Cloze surfaces notes with reminders). Meaningful value, but additive to the core reminder loop — V1 ships fine without it. Keep V1 scope tight; the Regards-specific twist worth preserving for V2 is surfacing the list *at reminder time*, which is rare in the category and reinforces the "lower friction to reaching out" thesis. |

## 17. How to use this document with Claude Code

A good opening prompt for Claude Code:

> Read `ARCHITECTURE.md`. Start with iOS Phase 0: create the Xcode project per the iOS module layout in §12, implement the Domain entities in §7 (including `Contact`, `ContactGroup`, `ScheduledReminder`, and the duplicate-detection heuristic) with full unit tests, build the ReminderEngine in §9 — cover cadence, annual-recurrence, DST, timezone edge cases, and virtual-merge scheduling — and wire up an empty eight-screen navigation shell per §10 with mock data. Do not integrate Contacts, Calendar, widgets, or schedule real notifications yet — surface a plan for iOS Phase 0 first and wait for review.

Subsequent phases follow §14. Every feature PR should cite the section of this doc it implements and flag any deviation.

---

*End of document.*
