# Beta Release Plan (resume point as of 2026-10-25)

## State
- `main` @ `ed5378d`, pushed. Netlify deploys web from `main`; the app is served at `/app/`.
- Done and live: profiles privacy lockdown (migrations 20261013120000 and 20261013130000, verified as alice), phone sign-in RPC, public privacy policy page, first-party beta analytics, Android applicationId `com.churternplay.churternPlay`, and upload signing (keystore `~/keystores/churternplay-upload.jks`, credentials in the gitignored `flutter_app/android/key.properties`).
- Rule: clients read other users through `public_profiles`, never `profiles`. New `profiles` columns are not client-writable until added to the GRANT UPDATE list.

## Remaining for beta (in suggested order)
1. **Android launcher icon.** `flutter_app/android/app/src/main/res/mipmap-*/ic_launcher.png` is probably still the Flutter default. Verify, then generate real icons (adaptive icon plus all densities).
2. **iOS icon.** Confirm the final artwork is in `flutter_app/ios/Runner/Assets.xcassets/AppIcon.appiconset` (1024px marketing icon included).
3. **App Store Connect.** Fill in the privacy questionnaire (declarations were corrected in `ba82ee1`), privacy policy URL and category (decision recorded in `0c1f6f1`).
4. **Play Console.** Fill in data safety, content rating and privacy policy URL.
5. **Builds.** Build and upload to TestFlight (iOS) and Play internal testing (Android `.aab`, signed with the upload key).
6. **Docs.** Mark the profiles item done in `docs/PRIVACY_RELEASE_CHECKLIST.md` (repo root).

## Known gaps (not fixed)
- Phone sign-in needs the exact digits including country code; entering a number without +1 fails.
- Password reset is email-only by design (a phone-based reset would leak the phone-to-email mapping).

## Friend features (separate track, see `docs/IMPLEMENTATION_PLAN_FRIEND_FEATURES.md` at repo root)
- Phase 0 (auto-grant library access): done, applied to the live DB, verified.
- Phase 1 (`friend_library_screen.dart`): committed in `694ec89`. Verified only by `flutter analyze`, `flutter test` and code review, with no interactive Simulator check.
- Phase 2 (Add to Wishlist from a friend's library): not started. No wishlist code in `friends_service.dart`.

## Working notes
- Ask before running `supabase db push` or any live auth.users reads or writes.
- Simulator UI automation: synthetic taps (cliclick/osascript) do not reach the Simulator. Use `xcrun simctl io booted screenshot`, code review and tests, or tap through manually.
- Seed test accounts: alice, bob and charlie (`database/seed-test-users.ts`).
