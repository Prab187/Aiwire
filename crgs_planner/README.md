# CRGS Student Planner

A planner for students: today's lessons, timetable, homework and tests, a bag
checklist, school contacts, and Sudoku / maths / word games by age group.
Flutter app for iPhone. Everything is saved on the phone. No accounts, no
network, no tracking.

Colours follow the Colchester Royal Grammar School website (purple, green
stripe, gold, white, serif headings). The school's crest is **not** used. See
"Before you submit" below.

## What is in this folder

| Path | What it is |
|---|---|
| `lib/` | The app code (screens, games, saving) |
| `test/` | 28 automated tests (Sudoku has exactly one answer, maths answers are right, saving, every screen) |
| `ios/` | The iPhone project. Bundle ID `com.prabha.crgsplanner`, iPhone only, portrait |
| `ios/ExportOptions.plist` | Used by the TestFlight upload |
| `../.github/workflows/crgs-planner-testflight.yml` | Builds on a Mac in GitHub and uploads to TestFlight |
| `../docs/crgs-planner/privacy.html` | Privacy policy page (needed for the App Store listing) |

## Before you submit

1. **Name.** The app is called exactly **CRGS Student Planner**, also under the icon
   on the home screen. The name must be unique on the App Store, so confirm it is
   free when you create the app in App Store Connect.
2. **The school's name and crest.** The name includes the school's initials, so
   Apple can ask who made the app and whether the school agrees. The app says
   "Unofficial student app. Not made or endorsed by Colchester Royal Grammar
   School." on the Today screen and in the privacy policy. Keep that wording, and
   ask the school's permission before you publish publicly. TestFlight for you
   and friends is fine in the meantime.
3. **Icon.** The app icon is an original planner icon in the school's colours. The
   school's crest is not used. Only use the crest if the school has agreed in
   writing; then add the image file and the icon sizes can be regenerated.
4. **Privacy page.** Add a contact email to `docs/crgs-planner/privacy.html`
   (search for "add a contact email").

## Put it on TestFlight (one-time setup, about 20 minutes)

You need a paid Apple Developer account. No Mac is needed: GitHub builds it.

1. **Create the app record.** App Store Connect > Apps > **+** > New App.
   Platform iOS, name CRGS Student Planner, language English, bundle ID
   `com.prabha.crgsplanner` (register it first under Certificates, Identifiers &
   Profiles > Identifiers if it is not in the list), SKU `crgsplanner`.
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
5. **Run the build.** GitHub > Actions > **CRGS Student Planner to TestFlight** >
   Run workflow. It checks the code, runs the tests, signs the app, and uploads it.
6. **TestFlight.** After Apple processes the build (usually 10 to 30 minutes) it
   appears in App Store Connect > your app > TestFlight. Add yourself under
   Internal Testing, install the TestFlight app on your iPhone, and open it.

This workflow has not been run on a real runner yet. If the first run fails, the
log shows which step; the usual causes are a wrong secret or the bundle ID not
being registered.

## Later, for the public App Store

- Privacy policy URL: the page in `docs/crgs-planner/` once GitHub Pages serves it.
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
