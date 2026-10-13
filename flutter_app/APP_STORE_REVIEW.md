# App Store Review — Remaining Blockers & Plan

Tracking the issues that will cause an Apple App Store rejection, with a plan to
fix each. Ordered by severity. Created from a pre-submission review on 2026-06-12.
Updated 2026-09-22.

> **Already done:**
> - In-app account deletion (Guideline 5.1.1(v)) — implemented via
>   the `delete-account` edge function + confirm drawer in the profile screen.
>   Deployed and ACTIVE (v1) on the `oorilcytrytxhffindgy` project;
>   `SUPABASE_SERVICE_ROLE_KEY` secret was already set.
> - Hosted Privacy Policy URL (#0) — confirmed live at
>   `https://churternplay.netlify.app/privacy/` (HTTP 200). Ready to enter in
>   App Store Connect and Play Console.
> - Dead/placeholder UI (#3) — profile menu items (Friends, Profile Details,
>   Settings, Privacy Policy) and the scanner's "Add Manually" button are all
>   wired to real destinations.
> - Privacy Manifest (#1) — `ios/Runner/PrivacyInfo.xcprivacy` created and added
>   to the Runner target's Resources build phase; verified present in a built
>   `Runner.app` (`flutter build ios --no-codesign`).
> - Export compliance key (#4) — `ITSAppUsesNonExemptEncryption` = `false` added
>   to `Info.plist`.
> - iPad (#6) — restricted to iPhone-only for v1: `TARGETED_DEVICE_FAMILY` set to
>   `1` in `project.pbxproj`, and the now-unused
>   `UISupportedInterfaceOrientations~ipad` key removed from `Info.plist`.
> - App identity (#5) — DONE. Real reverse-DNS bundle ID:
>   `com.churternplay.churternPlay`. "Churntern Play" confirmed as the single
>   product name; fixed the two remaining "The Catalogue" strings
>   (`auth_screen.dart` wordmark, `beta_disclaimer_dialog.dart` copy) to match.
> - Privacy policy is now shown in-app (`PrivacyPolicyScreen` + beta disclaimer
>   dialog) rather than an external placeholder link.
> - First-party beta analytics — added `analytics_events` table (migration
>   `20260922130000`, applied to the live project), `AnalyticsService`
>   (`lib/data/services/analytics_service.dart`), a global Flutter/platform
>   error hook in `main.dart` logging `app_error`, and `sign_in`/`sign_up`/
>   `sign_out`/`account_deleted` events in `AuthService`. No third-party SDK,
>   no ATT/tracking required. Privacy policy §1 and `PrivacyInfo.xcprivacy`
>   updated to match (User ID, Product Interaction, Crash Data added); both
>   copies of the policy re-dated to September 22, 2026.
> - Phone number field (added by separate work, migration `20260922120000`) —
>   optional secondary contact identifier, not used for authentication.
>   Declared in `PrivacyInfo.xcprivacy` and covered by the policy's existing
>   phone-number language.

---

## 0. Missing hosted Privacy Policy URL — DONE (page live; consoles still need it entered)

`https://churternplay.netlify.app/privacy/` returns HTTP 200 and covers data
collected, beta disclosures, and account deletion. The in-app disclaimer links
to the in-app `PrivacyPolicyScreen` rather than this URL directly, which is
fine — but the URL still needs to be entered manually in App Store Connect
(App Information → Privacy Policy URL) and Play Console (App content →
Privacy policy); the CLI/API can't set that field.

---

## 1. Missing Privacy Manifest — Guideline 5.1.2 — DONE

`ios/Runner/PrivacyInfo.xcprivacy` created (UserDefaults/file-timestamp/disk-space
required-reason APIs + email/user-content collection, tracking = false) and wired
into the Runner target's Resources build phase. Verified present in a built
`Runner.app` via `flutter build ios --no-codesign`.

---

## 2. App Privacy questionnaire (App Store Connect) — HARD BLOCKER

Separate from the manifest: the App Store Connect "App Privacy" section must be
filled out before the app can be released. Updated 2026-09-22 after Jason had
manually selected 10 data types (including Advertising Data, Device ID, and
"Used for tracking purposes" on Name and Advertising Data) that did not match
what the app actually does — no ad/analytics SDK exists, and checking
"tracking" requires implementing Apple's App Tracking Transparency (ATT)
framework, which this app does not have.

**Correct declaration for this build** (matches `PrivacyInfo.xcprivacy` and the
first-party `analytics_events` logging added this session — see
`lib/data/services/analytics_service.dart`):

| Data type | Purposes | Linked to identity | Tracking |
|---|---|---|---|
| Name | App Functionality | Yes | **No** |
| Email Address | App Functionality | Yes | **No** |
| Phone Number | App Functionality | Yes | **No** |
| User ID | App Functionality, Analytics | Yes | **No** |
| Product Interaction | Analytics | Yes | **No** |
| Crash Data | App Functionality | Yes | **No** |
| User Content (library, wishlist, sessions, profile) | App Functionality | Yes | **No** |

**Do not select:** Search History, Device ID, Advertising Data, Performance
Data, Third-Party Advertising, Developer's Advertising or Marketing, or check
"Used for tracking purposes" on anything — none of these are true for this
build. If ads/analytics SDKs are added later, update this table, the manifest,
and the privacy policy (§5) together before that release.

**Acceptance:** Privacy section shows "complete" in App Store Connect and
matches this table.

---

## 3. Dead / placeholder UI — Guideline 2.1 (App Completeness) — DONE

Profile menu items (Friends, Profile Details, Settings, Privacy Policy) and the
scanner's "Add Manually" button (→ `/library/manual-add`, carrying the unmatched
barcode) are all wired to real destinations. No dead controls found.

---

## 4. Export compliance key — friction (not auto-reject) — DONE

Added `ITSAppUsesNonExemptEncryption` = `false` to `ios/Runner/Info.plist` (app
only uses standard HTTPS via Supabase).

---

## 5. Placeholder app identity — Guideline 2.3 (metadata) — DONE

"Churntern Play" confirmed as the single product name. Real reverse-DNS bundle ID
set (`com.churternplay.churternPlay`). Fixed the two lingering "The Catalogue"
strings in `auth_screen.dart` (wordmark) and `beta_disclaimer_dialog.dart` (copy)
so in-app branding, display name, and bundle ID all agree.

---

## 6. iPad support — possible 2.x — DONE (restricted to iPhone-only for v1)

`TARGETED_DEVICE_FAMILY` set to `1` (iPhone only) in `project.pbxproj`; the
now-unused `UISupportedInterfaceOrientations~ipad` key removed from `Info.plist`.
iPad can be revisited as a later release.

---

## 7. App Store category

**Decision:** Primary **Utilities**, Secondary **Entertainment**. Utilities fits
the core collection/inventory-management function; Entertainment captures the
board-game hobby angle for discoverability. Set both in App Store Connect →
App Information → Category.

---

## Remaining before submission (all manual, App Store Connect / Xcode side)
1. Enter `https://churternplay.netlify.app/privacy/` as the Privacy Policy URL
   in App Store Connect (App Information) and Play Console (App content).
2. **#2 App Privacy questionnaire** — fill out App Store Connect's App Privacy
   section (Email Address + User Content, linked to user, app functionality only,
   not used for tracking) to match `PrivacyInfo.xcprivacy`.
3. Set App Information → Category to Utilities (primary) / Entertainment
   (secondary) — see #7.
4. Archive a release build in Xcode (or `flutter build ipa`) with real signing
   and upload to App Store Connect / TestFlight.
