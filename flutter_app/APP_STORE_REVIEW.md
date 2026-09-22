# App Store Review — Remaining Blockers & Plan

Tracking the issues that will cause an Apple App Store rejection, with a plan to
fix each. Ordered by severity. Created from a pre-submission review on 2026-06-12.
Updated 2026-09-22.

> **Already done:**
> - In-app account deletion (Guideline 5.1.1(v)) — implemented via
>   the `delete-account` edge function + confirm drawer in the profile screen.
>   Remaining deploy step: set `SUPABASE_SERVICE_ROLE_KEY` secret and
>   `supabase functions deploy delete-account`.
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

---

## 0. Missing hosted Privacy Policy URL — HARD BLOCKER (both stores)

Neither store submission can proceed without a live Privacy Policy URL — App
Store Connect requires it for every TestFlight build (internal or external
testing), and Play Console requires it before testers can be added to a closed
testing track. Invite-only does not exempt this.

**Why it matters here specifically:** the app has a friends/library-sharing
feature, so testers' library and profile data becomes visible to other testers
they connect with — that needs explicit disclosure, plus standard coverage of
what's collected (email, library/wishlist/session/profile content — see #2
below), that beta data may be reset/wiped without notice, and how to request
deletion (already built: `delete-account` edge function).

An in-app "Beta Preview" disclaimer now shows on every auth-screen launch
(`lib/features/auth/widgets/beta_disclaimer_dialog.dart`) referencing this
policy via `kPrivacyPolicyUrl`, currently a `TODO_PRIVACY_URL` placeholder.

**Plan:** Host a real privacy policy page (e.g. on the Netlify-deployed
marketing site) covering the beta-specific points above, then:
1. Replace `kPrivacyPolicyUrl` in `beta_disclaimer_dialog.dart` with the real
   URL (and consider re-adding `url_launcher` to make it tappable).
2. Add the URL to App Store Connect (App Information → Privacy Policy URL)
   and Play Console (App content → Privacy policy).

**Acceptance:** Privacy Policy URL live and set in both consoles; in-app
disclaimer links to the real URL.

---

## 1. Missing Privacy Manifest — Guideline 5.1.2 — DONE

`ios/Runner/PrivacyInfo.xcprivacy` created (UserDefaults/file-timestamp/disk-space
required-reason APIs + email/user-content collection, tracking = false) and wired
into the Runner target's Resources build phase. Verified present in a built
`Runner.app` via `flutter build ios --no-codesign`.

---

## 2. App Privacy questionnaire (App Store Connect) — HARD BLOCKER

Separate from the manifest: the App Store Connect "App Privacy" section must be
filled out before the app can be released.

**Plan:** In App Store Connect → App Privacy, declare collection of:
- **Contact Info → Email Address** (account creation) — linked to user, app
  functionality.
- **User Content** (library, wishlist, sessions, profile) — linked to user, app
  functionality.
- **Not used for tracking.**

Keep this consistent with the `PrivacyInfo.xcprivacy` from item 1.

**Acceptance:** Privacy section shows "complete" in App Store Connect.

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

## Remaining before submission
1. **#0 Hosted Privacy Policy URL** — confirm `public/privacy/index.html` is
   actually deployed and live at a real URL (not just present in the repo), then
   set it in App Store Connect (App Information) and Play Console (App content).
2. **#2 App Privacy questionnaire** — fill out App Store Connect's App Privacy
   section (Email Address + User Content, linked to user, app functionality only,
   not used for tracking) to match `PrivacyInfo.xcprivacy`.
3. Deploy `delete-account`: set `SUPABASE_SERVICE_ROLE_KEY` secret and run
   `supabase functions deploy delete-account` against the linked project.
4. Archive a release build in Xcode (or `flutter build ipa`) with real signing
   and upload to App Store Connect / TestFlight.
