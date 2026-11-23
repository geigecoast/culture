# Culture

**To install the app on your iPhone or iPad, follow [INSTALL.md](INSTALL.md).**

A bilingual (FR/EN) general-knowledge and cultural-events app for iPhone and iPad, built in the style of Instagram: a feed of visual cards, quick quizzes, a French "soutenu" vocabulary trainer with spaced repetition, and an agenda of cultural events in Paris, Frankfurt and München.

This repository contains:

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen spec for the universal iOS app (app, widget extension, UI tests) |
| `App/` | SwiftUI app: sources, String Catalog, privacy manifest, seed content bundle |
| `CultureKit/` | Swift package `CultureCore`: domain logic with no UI (models, SRS, streak, time zones, feed ranking, validation) and its unit tests |
| `Widgets/` | WidgetKit extension: Mot du jour, streak, next event |
| `UITests/` | XCUITest flows: onboarding, quiz, vocabulary review, RSVP |
| `content/` | Seed content as JSON, which the editor works on directly |
| `admin/` | Web editor (Node, no dependencies), validator, bundle builder, event-freshness check |
| `backend/supabase/` | Postgres schema with row-level security for privacy, account deletion, GDPR export |
| `docs/CONTENT_REVIEW_REPORT.md` | Content that still needs expert review |
| `.github/workflows/ci.yml`, `fastlane/` | CI and TestFlight lane |

`index.html` at the root predates this project and is not part of the app.

## Current status

This is a Phase 1 codebase. CI on GitHub (macOS, Xcode 16) **compiles the app for iPhone and iPad**, runs the 33 domain unit tests, and **launches the app in the iPhone and iPad simulators** to take screenshots. It has not yet been run on a physical device: see [INSTALL.md](INSTALL.md).

| Area | State |
|---|---|
| Domain logic (SRS, streak with weekly joker, venue-time-zone dates, filters, feed ranking, validation) | Written, with XCTest coverage in `CultureKit/Tests` |
| iPhone tabs and iPad split view, keyboard shortcuts (⌘F, ⌘1–5, arrow keys, 1/2/3 to grade, Space to reveal) | Written |
| Home feed, card detail with FR/EN toggle and sources, quiz feed, vocabulary deck and review, agenda (list/week/map), event detail, collections, profile, settings, onboarding with placement quiz | Written |
| Sign in with Apple, magic link, RSVP sync, account deletion, data export | Written against Supabase REST. Needs a Supabase project to test |
| Widgets | Scaffolded (Phase 2 in the spec) |
| Editor, validator, bundle builder | Working and tested (`cd admin && npm test`) |
| Pictures | Image-first feed: 4:5 photo carousels, a full-screen zoomable viewer with credits, 3-column photo grids for saved and liked cards. 29 of 40 cards carry 51 public-domain images (most with a carousel), and 14 of 15 events carry an illustration |
| Seed content | 40 cards (8 per topic), 63 vocabulary entries, 15 **sample** events. Spec target: 150 cards and 200 entries. Everything is "in review"; nothing is published |
| Install on devices | Through Xcode on a Mac with a free Apple ID ([INSTALL.md](INSTALL.md)). TestFlight needs the paid Apple Developer Program (see [Release](#release)) |

### Decisions taken (spec §1 and §18: please confirm)

1. **Minimum iOS 17**, for SwiftData and Observation.
2. **Quiz merged into Home**: a row of story-style bubbles opens a full-screen quiz feed. The tab bar shows Home, Agenda, Vocabulaire, Collections and Profil.
3. **German is not a UI language.** It appears only in venue and event names, which are never translated.
4. **Architecture: MVVM with Observation.** The Composable Architecture was not used, to keep dependencies at zero.
5. **Backend: Supabase.** The app talks to it over plain HTTPS through a small typed client, so there are no third-party Swift packages.

## Setup

### iOS app

Requirements: macOS with Xcode 16 or later. `Culture.xcodeproj` is generated from `project.yml` by CI and committed, so you can open it directly. To regenerate it yourself: `brew install xcodegen && xcodegen generate`.

- Pick your team in Xcode (Signing & Capabilities). `project.yml` works with a free Apple ID; `project-paid.yml` adds Sign in with Apple, App Groups (`group.com.geigecoast.culture`), push and universal links for paid accounts.
- The app runs fully offline from the bundled seed content. To enable accounts and sync, fill in `CultureBackendURL` and `CultureBackendAnonKey` in `project.yml` (Supabase project URL and anon key; the anon key is public and protected by row-level security). To serve content updates remotely, also fill in `CultureContentBaseURL`.
- Build configurations: **Debug** and **Beta** (internal TestFlight) also show content that is still in review, marked with an "En relecture" banner. **Release** (App Store) shows only published content. With today's seed, a Release build shows an empty feed, by design.
- Domain tests run without Xcode: `cd CultureKit && swift test`.
- UI-test launch arguments: `-ui-testing` (in-memory store), `-skip-onboarding`, `-app-language fr|en`.

### Backend (Supabase)

```sh
supabase link --project-ref <ref>
supabase db push                      # applies backend/supabase/migrations
supabase test db                      # pgTAP privacy tests in backend/supabase/tests
```

In the Supabase dashboard, enable the Apple provider (Services ID, key) and email magic links, with redirect URL `culture://auth`. Upload `App/Resources/SeedContent/content-bundle.json` to a public storage path so that it is served at `<CultureContentBaseURL>/content/bundle.json`.

### Editor

```sh
node admin/server.mjs                 # http://127.0.0.1:4310, local mode (you are a native reviewer)
EDITOR_USERS="ana:editor:tok1,ben:reviewer:tok2,chloe:native-reviewer:tok3" node admin/server.mjs
```

With `EDITOR_USERS` set, the server listens on all interfaces and asks for a token. Run it behind HTTPS (a reverse proxy) if it is exposed beyond your machine. Every change is appended to `admin/audit.log`.

## Architecture

```
SwiftUI views ──▶ AppModel / UserDataStore (@Observable, @MainActor)
                    │             │
                    │             └─ SwiftData: reviews, saves, collections, likes, RSVPs, activity days
                    ├─ ContentRepository (actor): cached bundle → bundled seed → remote refresh (validated)
                    ├─ AuthService, SyncService: Supabase Auth and PostgREST over URLSession (APIClient actor)
                    ├─ NotificationService, LocationService (one-shot, when in use), ScreenTimeMonitor
                    └─ CultureCore (Swift package, Foundation only): models, SM2Scheduler, StreakCalculator,
                       EventSchedule, EventFilter, FeedRanker, ContentValidator
```

- **Content and user data are separate.** Editorial content is one versioned JSON bundle (`ContentBundle`), cached on disk, so the app works offline. User state lives in SwiftData and syncs to Supabase.
- **Language switching.** `AppSettings.language` is observable. Every string goes through `settings.t("key")`, which reads the matching `.lproj` bundle compiled from `Localizable.xcstrings`. Switching language therefore re-renders in place, without a restart and without losing scroll position: the feed order is frozen until the next refresh. Each card also has its own FR/EN toggle, and on iPad the card detail can show both languages side by side.
- **Time zones.** Every event stores an IANA zone. Dates are always formatted and grouped in the venue's zone (`EventSchedule`), never the device's. A 23:30 performance in Paris reads "31 décembre, 23:30" everywhere. Tests cover device zones, DST days and reminders.
- **Spaced repetition.** SM-2 with three grades: "je connais" (quality 5), "à revoir" (quality 3, interval ×1.2 only), and "difficile" (back tomorrow, lapse counted).
- **Streak.** Counts days with any activity. One missed day per ISO week is forgiven.
- **Feed.** A weighted round-robin. Followed topics weigh more, weaker topics (from quiz accuracy) get up to twice the share, and no topic appears more than twice in a row.
- **Privacy.** Attendance is private by default and enforced in Postgres row-level security (`backend/supabase/migrations`). Analytics are off until the user consents, and no analytics SDK is included. `PrivacyInfo.xcprivacy` declares no tracking. Location is requested once, on demand, and only the chosen city is kept.
- **Strings.** `scripts/l10n_source.py` is the source of truth. `python3 scripts/gen_strings.py` regenerates the catalog and fails if any key used in Swift is missing.

## Content editing

1. Run the editor, pick a collection (Art, Musique, …, Vocabulaire, Événements), then edit or create an item. FR and EN fields sit side by side.
2. Workflow: **Brouillon → En relecture → Publié**. Only reviewers can publish. Publishing stamps `reviewer` and `lastReviewed`. Vocabulary can only be published by a `native-reviewer`. Sample events can never be published.
3. Validation runs on every save. Publishing is refused while an item has errors: a published card must have at least one source, a review date and a reviewer; geopolitics cards need a "facts as of" date; images need a licence, a credit and alt text; event offsets must match the venue time zone.
4. **Publier un bundle** validates everything, bumps `content/manifest.json`, and writes `App/Resources/SeedContent/content-bundle.json`. Deploy that file to content storage. Installed apps fetch it on launch or pull-to-refresh and refuse any bundle that fails validation.
5. Commit the `content/` changes, so git is the history. CI fails if the bundle is out of date.

AI-assisted drafting (translation, simplification) is allowed by the spec, but everything must go through "En relecture" and be published by a human reviewer. The tools enforce the human step, not the AI step.

## Images

Every image in the app carries a licence, a credit, a link to the museum record and FR/EN alt text, and the validator rejects any image without them. The viewer always shows the credit.

- The seed images are **public-domain (CC0) works from the Art Institute of Chicago** open-access collection, picked by hand per card (`scripts/images/picks.py`). `python3 scripts/images/apply.py` fetches their metadata, checks that each image actually loads, and writes it into `content/`. `scripts/images/search.py` lists candidates for new cards.
- The Met's open-access API works, but its image CDN blocks automated requests from build servers. Met images can't be verified there, so none are used yet. An editor can still add Met images by hand in the editor.
- Event pictures are illustrations (a Degas ballet for a ballet night, for example) and are captioned "Illustration". Swap them for venue press photos once venues license them.
- Before launch, mirror the images to your own storage (Supabase Storage or a CDN) and point `url` there, so the app doesn't depend on museum servers.
- Some topics have no honest open-access match (the Berlin Wall in 1989, the Strait of Hormuz, NATO and others). Those cards keep their topic artwork until a licensed photo is added, rather than showing a misleading picture.

## Event-source maintenance

- `admin/sources.json` lists each venue's source, ingestion method, the date its **terms of use were checked**, and a contact. All entries are `to_be_agreed`: no source has been cleared for automated ingestion yet, so nothing is scraped.
- `node admin/check-events.mjs` (run daily by CI) lists events not re-checked in 24 hours and venues without a cleared source. It fails if a **published** event breaches the 24-hour window, which is the spec's limit for flagging cancellations.
- Cancelled, moved and sold-out events use `status` plus an optional bilingual `statusNote`. The app shows an "Annulé" banner in the list and in the detail view.
- Ticket links always open the venue's official page in an in-app Safari view. No tickets are sold in the app.
- Before launch: agree feeds with each venue or licensed partner, or use municipal open data where the licence allows. Write one importer per source that updates `lastChecked`, and replace all `[Exemple]` events.

## Testing

| Suite | Command |
|---|---|
| Domain unit tests (SRS, streak, time zones, parsing, feed, filters) | `cd CultureKit && swift test` |
| UI tests (onboarding, quiz, vocabulary review, RSVP) | `xcodebuild test -scheme Culture -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Content and editor | `node admin/validate.mjs` · `cd admin && npm test` |
| Database privacy rules | `supabase test db` |

Snapshot tests are not set up yet. Adding `swift-snapshot-testing` would be the natural next step, but it was left out to keep dependencies at zero for now.

## Release

`fastlane beta` validates content, generates the project, bumps the build number, archives the **Beta** configuration and uploads to TestFlight. It needs `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_CONTENT` (base64 App Store Connect API key) and a signing setup (Xcode automatic signing or `match`). Before the first upload, fill in the App Privacy labels in App Store Connect to match `PrivacyInfo.xcprivacy`: email, user ID and user content, all linked to the user, none used for tracking.

## Known gaps and next steps

- Seed content: write the remaining 110 cards and about 137 vocabulary entries, attach licensed images, and run every item through expert review (see `docs/CONTENT_REVIEW_REPORT.md`).
- Replace sample events with verified listings, once source agreements are in place.
- RSVP sync polls every 3 seconds in the foreground. Replace this with Supabase Realtime to cut traffic.
- Push notifications (APNs) need a server sender for friends' RSVPs and weekly digests. Local reminders and the daily word already work on-device.
- Phase 2 (stories, image sharing, friends' plans, group chat, venue follows, after-event reviews with moderation) and Phase 3 (premium with StoreKit 2, App Intents, more cities, venue dashboard) are not started. The schema and models leave room for them.
