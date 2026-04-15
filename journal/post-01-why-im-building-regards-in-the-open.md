# Why I'm building Regards in the open

*Post #1 of the Regards build journal. Draft — review before publishing.*

---

A few months ago I opened my phone, scrolled past a name in my contacts list, and felt that specific small ache I think a lot of people know: *"I haven't talked to him in, what, a year? More?"* The guy had been in my wedding. I'd gone on a road trip with him in 2019. And somehow the thread between us had just — quietly, without anyone doing anything wrong — frayed.

I put the phone down, made a mental note to reach out that weekend, and of course I didn't. The weekend came, life happened, and the thought evaporated. The next time I remembered was three months later, and by then there was the additional friction of *"it's been so long now, what do I even say?"*

That loop — noticing, feeling bad, forgetting, noticing again, feeling worse — is what I'm trying to break. Not for everyone. For me, first. If it works for other people too, that's a nice side effect.

## What the existing tools couldn't do for me

I tried, in roughly this order: calendar reminders, a Notion database, a Google Sheet, Apple Reminders with recurring tasks, and then a handful of apps built specifically for this job — [Fabriq](https://fabriq.app), [Garden](https://www.garden-app.io), [Catchup](https://apps.apple.com/us/app/catchup-stay-in-touch/id1542622053), [Friend Reminder](https://apps.apple.com/us/app/friend-reminder/id1604626975), [Socially](https://apps.apple.com/us/app/socially-personal-crm-app/id1478075923), [Cloze](https://www.cloze.com), and [Contacts Journal](https://www.contactsjournal.com). Each of them is good at something. Some of them are good at a lot of things. The category isn't new and I don't want to pretend it is.

What I couldn't find was the specific slice I wanted. A few things kept not working for me personally:

The reminders fired at the wrong times. My phone would buzz at 2pm on a Wednesday telling me to catch up with someone, and — because I was in the middle of work — I'd swipe it away with every intention of dealing with it later, and "later" never came. The app had done its job perfectly well by the letter of the spec, but the spec was wrong. I didn't need the reminder *at all times*. I needed the reminder *when I was actually capable of acting on it*.

The reminders pointed at the app, not at the action. I'd tap the notification and land inside the reminder app, where I'd see a list that said "reach out to Alex." Then I'd leave that app, open WhatsApp, search for Alex, and by the time I got there the activation energy had mostly drained out of me. Three or four taps of friction is enough to lose me. I needed the reminder to deposit me directly inside the app I was actually going to message from, with the right contact pulled up.

The subscription model bothered me more than I expected it to. A personal-CRM app that reads my private contact list and asks me for $10 a month creates a relationship where I'm on the hook forever for something that has no ongoing costs on the developer's side. I understand why subscriptions exist and I don't begrudge the developers who use them — it's how indie apps survive. But for something this personal, with this much on-device data, I wanted to pay once and be done. I wanted the developer's incentives and mine aligned from day one.

And — the one that mattered most — I was uncomfortable handing my entire contacts list to anything with a backend. Not because I thought anyone specific was doing something bad. Because "we don't sell your data" is a promise, and promises in the tech industry have a half-life. If an app doesn't *have* a server, it can't leak, can't be breached, can't be sold, can't pivot to ads in year three. The only way to make that claim durable is to architect the app so it's technically incapable of phoning home.

None of these are complaints about the apps I tried. They're design choices, and those apps made the choices that made sense for the audiences they were built for. I just wasn't in the middle of their target audience on any of them, and the specific combination I wanted didn't exist.

So I'm building it.

## What Regards is

Three design bets, in order of how important they feel to me:

**Reminder-window awareness.** You tell the app when it's OK to bug you — specific days, specific time ranges, a hard quiet-hours override — and reminders only fire inside those windows. If someone becomes overdue at 11am on a Tuesday, Regards sits on the reminder until 6pm, or whenever you said it was fine. Multiple overdue contacts collapse into a single digest at the next window so you don't get pelted. This is the thing I most wanted from an app like this and couldn't find, and it's what I think is the most defensible piece of the design.

**Verifiable privacy.** The app is local-first with no account and no sync. On Android, I'm not going to declare the `INTERNET` permission in the manifest at all — which means the Linux kernel denies socket creation to the app's process, and network access becomes technically impossible rather than merely policy-forbidden. On iOS, App Transport Security will be set to deny all loads, and the app's own modules won't contain any networking code. I'll publish the source on GitHub under a source-available license so anyone can audit the claims. I'll run the Android builds through Exodus Privacy and publish the report. This isn't a privacy pitch, it's a privacy proof — and making the proof airtight is a large chunk of the fun for me.

**One tap to the actual action.** Tapping a reminder deep-links you straight into WhatsApp, Signal, iMessage, Telegram, your phone dialer, Instagram DMs, email, or whichever channel you picked for that contact — pre-scoped to that person where the platform allows it. No message prefill, no AI suggestions, nothing that gets between you and the thing you were already going to say. The app's job is to lower the activation energy; your job is the actual relationship.

A few things the app deliberately *won't* do: no reading your email or SMS history, no OAuth integrations to anything, no AI suggestions for what to say, no analytics, no trackers, no ads, no subscription. One-time purchase with a free trial, plus an optional tip jar for people who want to pay more. That's it.

## Why I'm writing about it publicly

A few reasons, in descending order of honesty.

**It keeps me honest.** Telling strangers on the internet that I'm going to ship this thing creates a small but real accountability loop that "tell myself in the shower" does not. I know this about myself and I'm using it.

**The privacy claim needs a paper trail.** "Trust me, the app doesn't phone home" is worth less than "here is the GitHub repo, here is the Exodus Privacy report, here is a video of Little Snitch showing zero outbound connections during a full usage session." Writing about the decisions as I make them is part of that paper trail. If someone, years from now, wants to know whether I quietly switched to a SaaS help desk or added a crash reporter, there's a public record they can check.

**I want to learn from the people reading this.** I'm a solo developer and this is my first shipped indie app. There are a hundred decisions ahead of me — pricing tiers in emerging markets, how to handle the Android exact-alarm permission, whether the duplicate-detection heuristic needs to be smarter — and some of you have done this before and have opinions I haven't even thought to have. That's worth more to me than the Substack subscriber count.

**And a little bit: I want a record of the process for myself.** This is the first indie app I've built that I actually believe might find its people. If it ships and does well, I want to be able to go back and read what I was thinking in week 2. If it doesn't, I want to be able to read what I got wrong.

## What this journal will be

Biweekly posts — not weekly, because I've tried weekly and it collapses by week six. An even-ish mix of: progress updates with real numbers, technical deep dives (the reminder-window algorithm, the deep-link catalog, the no-`INTERNET`-permission setup on Android), business decisions with their reasoning exposed (pricing, licensing, naming), and — post-launch — real stories from the people using the app.

The voice I'm aiming for is *what I'm building and why*, not *what the other guys got wrong*. I don't have the credibility yet to go around critiquing shipped apps, and even if I did, comparative resentment reads as weakness no matter who's doing it. When I mention the other apps in this space, it'll be because they did something well and I'm learning from it, or because a reader asked how Regards differs and I owe them an honest answer.

## A note on the tools I'm using

I should be upfront about this, because it's relevant to the transparency pitch: I'm using Anthropic's Claude as my primary collaborator throughout this build. That covers code, architecture discussion, this post, and most of the written artifacts in the repo. The banner image at the top of this post was generated with Google's Gemini. I'll probably lean on a handful of other AI tools as the project moves along, and I'll call them out when they show up.

None of that changes the privacy architecture of the app itself. Regards has no AI features, no model calls, no network code — the AI assistance lives entirely in *my* workflow, not in the product. But if I'm going to ask readers to trust me on the privacy claim, the bar for honesty about how I actually work has to be just as high. When a decision was shaped by a back-and-forth with Claude and I agreed with it, I'll say so. When a chunk of code starts as a Claude draft and I edit it down, the commit history will show both passes. The point isn't to hide the human behind the output or the model behind the human — both are in the loop and you should know it.

## Where to find the build

- **GitHub:** [github.com/sid78669/RegardsMobileApp](https://github.com/sid78669/RegardsMobileApp) — the architecture doc is already public there. Code lands in the next week or two.
- **This Substack:** you're here. Subscribe if you want the next post in your inbox; every post will link back to the repo and, when it exists, the app download.
- **Feedback:** reply to any post, or open a GitHub issue. Both reach me.

The first real code commit is imminent — starting on iOS with the domain layer and the eight-screen navigation shell. Regards is a one-person project, so I can only build one platform at a time: iOS ships first, Android follows. Next post will be the tour through the apps that came before Regards and what each of them taught me about this space. See you in two weeks.

— Sid
