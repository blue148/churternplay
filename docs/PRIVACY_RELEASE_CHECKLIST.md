# Privacy release checklist

The user-facing policy is available in two places:

- Flutter: `flutter_app/lib/features/privacy/privacy_policy_content.dart`
- Hosted page: `public/privacy/index.html` (deployed at `/privacy/`)

Keep those copies synchronized when practices change.

## Required before store submission

- Treat the current `profiles` read policy as a privacy/security blocker. It lets
  any authenticated user query every profile row, including `email`. Restrict
  authenticated discovery to a public-profile projection (for example: id,
  username/display name, avatar, bio, and public stats) and keep contact fields
  private. After the backend is fixed, remove `email address` from the policy's
  Other users disclosure.
- Confirm the final legal operator/developer name and add a monitored privacy or
  support email and, if applicable, a mailing address. The current policy points
  to the developer contact in each store listing because no contact address is
  configured in the repository.
- Deploy the web app and verify that the public `/privacy/` URL works without a
  login. Enter that full URL in App Store Connect and Play Console.
- Complete App Store Connect App Privacy and Google Play Data safety disclosures
  based on the shipped build, including every third-party SDK.
- Add or update the iOS privacy manifest before submission.
- Decide whether the minimum age is 13 or higher. If the app targets children or
  knowingly collects data from children under 13, obtain specialist review for
  parental notice and verifiable consent requirements.

## Before adding analytics or advertising

- Select the vendors and document exactly what each SDK collects, retains, and
  shares. Update both policy copies and both store disclosures before release.
- Decide whether ads are contextual only. If personalized or cross-context ads
  are used, implement the required platform consent and regional opt-out flows.
- Provide a way to withdraw optional analytics/advertising consent as required.
- Do not send email, phone number, birthdate, state, private notes, or player
  names to an ad provider unless there is a reviewed, disclosed, necessary use.

## Before adding a connector

- Show the requested data and purpose at authorization time.
- Request only the minimum scopes needed.
- Provide an in-app disconnect/revoke control and define what imported data is
  kept after disconnection.
- Add the connector and its data practices to both policy copies and the store
  disclosures before shipping it.

This checklist and the draft policy are operational starting points, not legal
advice. Have counsel review the final policy against the actual release build,
the business's location, and the markets where the app is offered.
