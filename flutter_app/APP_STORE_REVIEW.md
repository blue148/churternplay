# App Store Review — Remaining Blockers & Plan

Tracking the issues that will cause an Apple App Store rejection, with a plan to
fix each. Ordered by severity. Created from a pre-submission review on 2026-06-12.

> **Already done:** In-app account deletion (Guideline 5.1.1(v)) — implemented via
> the `delete-account` edge function + confirm drawer in the profile screen.
> Remaining deploy step: set `SUPABASE_SERVICE_ROLE_KEY` secret and
> `supabase functions deploy delete-account`.

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

## 1. Missing Privacy Manifest — Guideline 5.1.2 — HARD BLOCKER

There is no `PrivacyInfo.xcprivacy` in the iOS app target. Apple has required this
since May 2024 and the build will be rejected at upload/review without it.

**Why it applies here:** several dependencies use "required-reason" APIs, and the
app collects user data (email, account content):
- `shared_preferences` → `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`)
- `supabase_flutter` / `cached_network_image` → file-timestamp & disk-space reasons
  (`C617.1`, `E174.1`, `85F4.1`) for their on-disk caches

**Plan:**
1. Create `ios/Runner/PrivacyInfo.xcprivacy` (a plist) declaring:
   - `NSPrivacyAccessedAPITypes` — UserDefaults (`CA92.1`) plus the file-timestamp
     and disk-space categories the caching libs use.
   - `NSPrivacyCollectedDataTypes` — email address and user content (linked to
     identity, used for app functionality, not tracking).
   - `NSPrivacyTracking` = `false`; empty `NSPrivacyTrackingDomains`.
2. Add the file to the Runner target in Xcode (`project.pbxproj`) so it ships in
   the bundle — creating the file alone is not enough.
3. Verify many plugins already ship their own manifest; Xcode aggregates them. Our
   job is the **app target's** manifest + anything not covered by a plugin.

**Acceptance:** `Runner.app/PrivacyInfo.xcprivacy` present in an archive build; no
ITMS privacy-manifest warnings on upload.

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

## 3. Dead / placeholder UI — Guideline 2.1 (App Completeness) — LIKELY BLOCKER

Reviewers tap every control; non-functional buttons read as an unfinished app.

Current offenders:
- `lib/features/profile/profile_screen.dart` — **Wishlist**, **Friends**,
  **Shared Libraries**, **Settings** menu items all have `onTap: () {}` (`// TODO`).
- `lib/features/scanner/scanner_screen.dart` — the "Game not found" sheet's
  **Add Manually** button is `// TODO: navigate to manual entry` (just closes).

**Plan (choose per item):**
- Wire up the destinations that already exist (wishlist/friends data + screens
  appear to exist in the backend), **or**
- Hide the not-yet-built entries for the first submission so nothing dead is
  visible. Lowest-risk path to approval: hide what isn't wired, ship a smaller
  but complete surface.
- For **Add Manually**: either implement the manual-entry flow (see
  `docs/manual-entry-flow.md`) or replace the button with a "Scan Again" / dismiss
  so there's no dead end.

**Acceptance:** Every visible, enabled control does something.

---

## 4. Export compliance key — friction (not auto-reject)

`Info.plist` lacks `ITSAppUsesNonExemptEncryption`. Without it, every build prompts
the export-compliance question in App Store Connect.

**Plan:** App only uses standard HTTPS (Supabase), so add to
`ios/Runner/Info.plist`:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

**Acceptance:** No export-compliance prompt on build submission.

---

## 5. Placeholder app identity — Guideline 2.3 (metadata) — possible query

Inconsistent naming may draw a metadata rejection / clarification:
- Display name: **"Churntern Play"** (`CFBundleDisplayName`)
- In-app branding: **"The Catalogue"** (auth screen)
- Package: `churntern_play`; pubspec `name: churntern_play`
- Bundle ID still the unset `$(PRODUCT_BUNDLE_IDENTIFIER)` template

**Plan:**
1. Decide the real product name and make `CFBundleDisplayName`, the App Store
   listing name, and in-app branding agree.
2. Set a real reverse-DNS bundle identifier in Xcode (e.g. `com.<org>.<app>`).
3. (Optional, cosmetic) rename the Dart package away from `churntern_play`.

**Acceptance:** Store name, on-device name, and in-app branding match; real bundle
ID configured.

---

## 6. iPad support — verify, don't assume — possible 2.x

`Info.plist` declares iPad orientations and sets no `UIDeviceFamily` restriction,
so **Apple will review on iPad too.** Broken iPad layout = rejection.

**Plan:** Either
- Test dashboard / library / game-nite / scanner on an iPad simulator and fix any
  stretched/broken layouts, **or**
- Restrict to iPhone-only (set the Devices/`TARGETED_DEVICE_FAMILY` to iPhone) if
  iPad isn't a target for v1.

**Acceptance:** App looks correct on the largest reviewed device, or iPad is
explicitly out of scope.

---

## Suggested order
1. Privacy Manifest (#1) + App Privacy answers (#2) — the two that bounce apps most.
2. Dead UI cleanup (#3).
3. Export key (#4) + identity (#5) — quick.
4. iPad decision (#6).
