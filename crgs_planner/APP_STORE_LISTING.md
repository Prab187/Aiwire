# App Store Connect: everything to paste

Work top to bottom. Items marked **you** need your own details.

## 1. New App form
| Field | Value |
|---|---|
| Platforms | iOS only |
| Name | `CRGS Kampus` |
| Primary Language | English (U.K.) |
| Bundle ID | `com.prabha.crgsstudentplanner` (register it first under Certificates, Identifiers & Profiles > Identifiers > App IDs > App > Explicit) |
| SKU | `crgsplanner` |
| User Access | Full Access |

## 2. App Information
| Field | Value |
|---|---|
| Subtitle (max 30) | `Lessons, homework & AI radio` |
| Primary category | Education |
| Secondary category | Productivity |
| Content rights | "Does your app contain, show or access third-party content?" Yes. It shows news headlines from public feeds (BBC News, Schools Week and others), with the source named and a link to the original. |
| Privacy Policy URL | `https://prab187.github.io/Aiwire/crgs-planner/privacy.html` (works once the branch is merged to `main` and GitHub Pages has updated; open it first to check) |

## 3. Version 1.0 page (needed before public release; TestFlight does not need it)
**Promotional text (max 170):**
```
New: AI Radio reads you the latest news about schools adopting AI, and shows which school got which AI.
```

**Description:**
```
CRGS Kampus keeps your school day in one place.

TODAY
See today's lessons (or tomorrow's after school), what homework is due, your next test and a quick bag check, all on one screen.

TIMETABLE
Type in your lessons for each day. Every subject gets its own colour so you can scan your week at a glance.

HOMEWORK
Add homework and tests with due dates. Overdue work is flagged, finished work moves to Done.

AI RADIO
Listen to the latest news about schools adopting AI, read out by your phone's voice. A "Who got which AI" board shows which school is using which AI tool, and stories about your school play first.

GAMES
Sudoku, a 60-second maths sprint and a word scramble, set for ages 5 to 16.

CONTACTS
Keep your tutor, teachers, parents and study buddies in one list.

PRIVATE BY DESIGN
No account. No ads. No tracking. Your timetable, homework and notes stay on your iPhone.

Unofficial student app. Not made or endorsed by Colchester Royal Grammar School.
```

**Keywords (max 100, no spaces after commas):**
```
school,planner,timetable,homework,student,sudoku,revision,GCSE,AI,radio,bag,schedule,tests,study
```

| Field | Value |
|---|---|
| Support URL | Needs a web page. Use the privacy page address above for now, after adding your contact email to it |
| Marketing URL | Leave empty |
| Copyright | `2026 [your name]` (**you**) |
| Version | 1.0 |

## 4. Age Rating questionnaire
Answer **None / No** to everything: violence, sexual content, nudity, profanity, horror, drugs, alcohol and tobacco references, gambling, medical content, contests. Also **No** to: unrestricted web access (links open in Safari, not inside the app), user-generated content, messaging or chat, advertising, parental controls, age assurance. Expected rating: **4+**.

## 5. App Privacy
- Do you or your third-party partners collect data from this app? **No** (Data Not Collected).
- Tracking: **No**.
- The Radio tab downloads public news without sending anything personal. Read Apple's definitions once and confirm you are happy with "No".
- Export compliance: already answered inside the app (it uses no special encryption). Apple will not ask.

## 6. App Review information (public release)
- Sign-in required: **No**.
- Contact name, phone, email: **you**.
- Notes:
```
No account is needed. Open the Radio tab and tap Play to hear news headlines about AI in schools (downloaded from public feeds: GDELT, BBC News, Schools Week). The app keeps playing when the screen is locked (audio background mode), because the radio reads stories aloud. This is an unofficial student app and is not affiliated with any school.
```

## 7. TestFlight
**Test Information** (App Store Connect > your app > TestFlight > Test Information):
| Field | Value |
|---|---|
| Beta App Description | `A school planner with an AI news radio, homework tracker, timetable, contacts and games.` |
| Feedback Email | **you** |
| Contact info (name, phone, email) | **you** |
| Sign-in required | No |

**What to Test** (shown in the TestFlight app):
```
Please try:
1. Add your timetable and a piece of homework.
2. Open Radio and tap Play. Do stories load and get read out? Does it keep playing with the screen locked?
3. Under "Tune the radio", set your school and check its stories come first.
4. Play a Sudoku and the maths sprint.
Tell us anything confusing, broken or slow.
```

**Internal testers** (up to 100, no Apple review): Users and Access > add each person with their Apple ID email > TestFlight > Internal Testing > add them.
**External testers** (up to 10,000, first build is reviewed by Apple): TestFlight > External Testing > **+** > new group > add testers by email, or switch on the public link.

## 8. Screenshots (public release only)
Required size: iPhone 6.9-inch, **1320 x 2868**, 1 to 10 images. Easiest way: install the TestFlight build on a recent iPhone Pro Max, press Side button + Volume Up on Today, Radio, Homework and Games, and upload those.
