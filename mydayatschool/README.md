# MyDayAtSchool

A planner for students: today's lessons, timetable, homework and tests, a bag
checklist, school contacts, and Sudoku / maths / word games by age group.
Flutter app for iPhone. Everything is saved on the phone. No accounts, no
network, no tracking.

Colours follow the Colchester Royal Grammar School website (purple, green
stripe, gold, white, serif headings). The school's crest and name are **not**
used. See "Before you submit" below.

## What is in this folder

| Path | What it is |
|---|---|
| `lib/` | The app code (screens, games, saving) |
| `test/` | 28 automated tests (Sudoku has exactly one answer, maths answers are right, saving, every screen) |
| `ios/` | The iPhone project. Bundle ID `com.prabha.mydayatschool`, iPhone only, portrait |
| `ios/ExportOptions.plist` | Used by the TestFlight upload |
| `../.github/workflows/mydayatschool-testflight.yml` | Builds on a Mac in GitHub and uploads to TestFlight |
| `../docs/mydayatschool/privacy.html` | Privacy policy page (needed for the App Store listing) |

## Before you submit

1. **Name.** "My School Day" is already an App Store app, so this one is called
   MyDayAtSchool. Names must be unique, so confirm it is free when you create the
   app in App Store Connect. If it is taken, change `CFBundleDisplayName` in
   `ios/Runner/Info.plist` and the title in `lib/main.dart`.
2. **School crest.** The app icon is an original planner icon in the school's
   colours. Do not swap in the school's crest or put the school's name in the app
   name unless the school has agreed in writing. Apple rejects apps that look
   like they are made by someone they are not.
3. **Privacy page.** Add a contact email to `docs/mydayatschool/privacy.html`
   (search for "add a contact email").

## Put it on TestFlight (one-time setup, about 20 minutes)

You need a paid Apple Developer account. No Mac is needed: GitHub builds it.

1. **Create the app record.** App Store Connect > Apps > **+** > New App.
   Platform iOS, name MyDayAtSchool, language English, bundle ID
   `com.prabha.mydayatschool` (register it first under Certificates, Identifiers &
   Profiles > Identifiers if it is not in the list), SKU `mydayatschool`.
2. **Make an API key.** App Store Connect > Users and Access > Integrations >
   App Store Connect API > Team Keys > **+**. Name it, give it the **App Manager**
   role, download the `.p8` file (you can only download it once). Note the
   **Key ID** and the **Issuer ID** shown on that page.
3. **Find your Team ID.** developer.apple.com > Account > Membership details.
4. **Add four secrets** in GitHub: repository > Settings > Secrets and variables >
   Actions > New repository secret.

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID` | The Key ID |
   | `ASC_ISSUER_ID` | The Issuer ID |
   | `ASC_KEY_P8_BASE64` | The `.p8` file as base64. On a Mac: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
   | `APPLE_TEAM_ID` | The 10-character Team ID |

   Keep the key out of chat, email and the repo. Only paste it into GitHub.
5. **Run the build.** GitHub > Actions > **MyDayAtSchool to TestFlight** >
   Run workflow. It checks the code, runs the tests, signs the app, and uploads it.
6. **TestFlight.** After Apple processes the build (usually 10 to 30 minutes) it
   appears in App Store Connect > your app > TestFlight. Add yourself under
   Internal Testing, install the TestFlight app on your iPhone, and open it.

This workflow has not been run on a real runner yet. If the first run fails, the
log shows which step; the usual causes are a wrong secret or the bundle ID not
being registered.

## Later, for the public App Store

- Privacy policy URL: the page in `docs/mydayatschool/` once GitHub Pages serves it.
- App Privacy: choose **Data Not Collected**.
- Export compliance is already answered in the app (no non-exempt encryption).
- Age rating: no web access, no user content shared, no purchases. Expect 4+.
- Screenshots: iPhone 6.9-inch (1320 x 2868). The app is iPhone only.

## Build on a Mac instead

```
flutter pub get
flutter test
open ios/Runner.xcworkspace   # Signing & Capabilities: pick your team, then Product > Archive
```
