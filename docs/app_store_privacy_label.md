# App Store Connect — Privacy Nutrition Label Checklist

Use this checklist when filling in the **App Privacy** section in App Store Connect
(Your App → App Privacy → Edit). Check every row that applies to AIWire.

---

## How to read this document

Each section maps to a **Data type** in the App Store Connect UI.
For each type, note:

- **Collected?** — Does AIWire collect or transmit this data?
- **Use** — Select the matching purpose(s) in App Store Connect.
- **Linked to identity?** — Is it linked to the user's Apple ID / account?
- **Tracking?** — Is it used to track the user across apps/websites?

---

## 1. Contact Info

| Field | Collected? | Notes |
|---|---|---|
| Name | Yes | Google Sign-In returns `displayName`; Apple Sign-In returns name on first sign-in. Stored on-device and/or backend. |
| Email address | Yes | Both Apple and Google Sign-In return an email. Used for account identification. |
| Phone number | No | Not requested. |

**App Store Connect settings:**
- Use: **App Functionality** (authentication)
- Linked to identity: **Yes**
- Tracking: **No**

---

## 2. Identifiers

| Field | Collected? | Notes |
|---|---|---|
| User ID | Yes | Apple subject identifier (`sub`) or Google user ID stored in SharedPreferences / backend. |
| Device ID | No | Not collected explicitly. |

**App Store Connect settings:**
- Use: **App Functionality**
- Linked to identity: **Yes**
- Tracking: **No**

---

## 3. Purchases

| Field | Collected? | Notes |
|---|---|---|
| Purchase history | Yes | `is_premium` flag stored in SharedPreferences. StoreKit receipt / transaction IDs handled by Apple's in_app_purchase framework. |

**App Store Connect settings:**
- Use: **App Functionality** (unlocking premium features)
- Linked to identity: **Yes**
- Tracking: **No**

---

## 4. Usage Data

| Field | Collected? | Notes |
|---|---|---|
| Product interaction | Yes | Daily summary count (`daily_summary_count`) stored in SharedPreferences to enforce free tier limits. |
| Advertising data | No | No ad SDKs integrated. |
| Other usage data | No | No analytics SDK (e.g. Firebase, Mixpanel) detected. Add here if one is added later. |

**App Store Connect settings:**
- Use: **App Functionality** (enforcing free tier)
- Linked to identity: **No** (stored only on-device in SharedPreferences)
- Tracking: **No**

---

## 5. Diagnostics

| Field | Collected? | Notes |
|---|---|---|
| Crash data | No | No crash-reporting SDK (e.g. Crashlytics, Sentry) detected. Add here if one is added. |
| Performance data | No | — |

---

## 6. Other Data

| Field | Collected? | Notes |
|---|---|---|
| News reading behaviour / article clicks | No | Article URLs are opened externally via `url_launcher`; no click tracking sent to a server. |
| Text-to-speech audio | No | `flutter_tts` processes audio entirely on-device via the system TTS engine. |
| Shared content | No | `share_plus` hands content to the OS share sheet; AIWire does not receive or store the destination. |

---

## Data NOT Collected (confirm before submitting)

- Location data
- Health & fitness data
- Financial info (beyond purchase flag)
- Sensitive info
- Browsing history
- Search history
- Photos or videos

---

## Third-party SDKs — confirm their own data collection

| SDK | Data it may collect | Action |
|---|---|---|
| `google_sign_in` | Google account info (name, email, profile photo URL) | Covered under Contact Info above |
| `sign_in_with_apple` | Apple ID / email (may be anonymised relay) | Covered under Contact Info above |
| `in_app_purchase` (StoreKit) | Transaction receipts sent to Apple servers | Apple handles this; no extra disclosure needed |
| `cached_network_image` | Caches article images on-disk | On-device only; no disclosure needed |
| `google_fonts` (runtime fetching disabled) | None (fetching disabled via `allowRuntimeFetching = false`) | No disclosure needed |

---

## Checklist before submitting in App Store Connect

- [ ] Confirm whether a backend server receives any of the above data (name, email, user ID).
      If yes, mark those fields **Linked to identity: Yes**.
- [ ] Confirm no third-party analytics SDK has been added since this doc was last updated.
- [ ] If crash reporting is added, add **Crash Data** under Diagnostics.
- [ ] Review Apple's guidance: https://developer.apple.com/app-store/app-privacy-details/
- [ ] Save and submit the privacy label before each new App Store submission.
