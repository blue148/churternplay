class PrivacySection {
  const PrivacySection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

const privacyPolicyEffectiveDate = 'September 22, 2026';

const privacyPolicyIntroduction =
    'This Privacy Policy explains how Churtern Play ("Churtern Play," "we," '
    '"us," or "our") collects, uses, discloses, and protects information when '
    'you use the Churtern Play mobile application and related services '
    '(collectively, the "App"). By using the App, you acknowledge the practices '
    'described here.';

const privacyPolicySections = <PrivacySection>[
  PrivacySection(
    title: '1. Information we collect',
    paragraphs: [
      'Account and contact information. We collect the information needed to '
          'create and manage an account, such as your username, name, email '
          'address, and password authentication data. Depending on the features '
          'you use, you may also choose to provide a profile photo, biography, '
          'phone number, birthdate, and state or region.',
      'Collection and play information. We collect the games in your library '
          'and wishlist; favorites, rankings, for-sale status, and notes; game '
          'session dates, duration, player count, player names, scores, results, '
          'and other details you enter; and friend connections and library-sharing '
          'choices. Please obtain permission before entering another person\'s '
          'information and do not enter sensitive information in free-form notes.',
      'Game and connector information. When you scan a barcode or search for a '
          'game, we process the barcode, search terms, game identifiers, and '
          'related game metadata. If you choose to connect a third-party account '
          'or convention service in the future, we may receive the profile, game '
          'collection, wishlist, registration, schedule, or other information you '
          'authorize that service to provide. The authorization screen for each '
          'connector will describe the requested access.',
      'Camera data. Camera access is used to recognize a game barcode. Camera '
          'images are processed on your device and are not stored by Churtern '
          'Play. The recognized barcode is sent to our service for lookup.',
      'Usage and diagnostic information. During the beta, we log certain app '
          'actions (such as signing in, signing up, and deleting an account), '
          'your account ID, general device platform, and crash reports directly '
          'to our own systems — not to a third-party analytics or advertising '
          'SDK. We use this information only to understand usage and diagnose '
          'problems during the beta. Some future builds may also collect ad '
          'views and interactions, app version, operating-system type, '
          'language, time zone, IP address, approximate location derived from '
          'IP address, and advertising or app-instance identifiers; we will '
          'update this Policy and applicable app-store disclosures before that '
          'begins.',
    ],
  ),
  PrivacySection(
    title: '2. Where information comes from',
    paragraphs: [
      'We receive information directly from you, automatically from the App and '
          'our service providers, from other users when they connect or share '
          'with you, and from services you choose to connect.',
      'For game identification and enrichment, the App currently uses '
          'BoardGameGeek, GameUPC, Barcode Lookup, and UPCitemdb. These sources '
          'primarily provide non-personal game information such as titles, '
          'publishers, release years, images, categories, mechanics, player '
          'counts, and BoardGameGeek identifiers. Future connectors may also '
          'provide information from game conventions or other game services. '
          'Those third parties operate under their own privacy policies.',
    ],
  ),
  PrivacySection(
    title: '3. How we use information',
    paragraphs: [
      'We use information to create and secure accounts; provide libraries, '
          'wishlists, play tracking, social features, shared libraries, barcode '
          'lookup, game search, and connectors; personalize your experience; '
          'respond to support requests; prevent fraud, abuse, and security '
          'incidents; maintain and troubleshoot the App; measure performance and '
          'feature usage; develop future features; display and measure advertising; '
          'and comply with law and enforce our terms.',
      'We may aggregate or de-identify information so it no longer reasonably '
          'identifies you, and use that information for analytics, research, and '
          'product planning.',
    ],
  ),
  PrivacySection(
    title: '4. When we disclose information',
    paragraphs: [
      'Service providers. We disclose information to vendors that host data, '
          'authenticate users, deliver app functionality, monitor reliability, '
          'provide analytics, support us, or perform other work on our behalf. '
          'They may use the information only for the services they provide to us '
          'and must protect it consistently with this Policy and applicable law.',
      'Game-data providers. We send game search terms, game identifiers, or '
          'barcodes as needed to identify and enrich games. Current requests are '
          'handled through our server-side service. We do not intentionally send '
          'your name, email address, phone number, or birthdate to BoardGameGeek, '
          'GameUPC, Barcode Lookup, or UPCitemdb for these lookups. When a barcode '
          'is matched to a game, we may contribute the barcode and BoardGameGeek '
          'identifier to GameUPC to improve future lookups.',
      'Other users. Your username, display name, profile image, biography, '
          'email address, and basic game statistics may currently be accessible '
          'to signed-in users so they can find and connect with you. Friends or '
          'people to whom you grant access may view the library information you '
          'share. Your phone number, birthdate, and state are not intended to '
          'appear in shared libraries.',
      'Legal, safety, and business transfers. We may disclose information when '
          'reasonably necessary to comply with law or legal process, protect '
          'rights and safety, investigate abuse, or complete a merger, financing, '
          'reorganization, or sale of all or part of the service. We will provide '
          'notice when legally required.',
    ],
  ),
  PrivacySection(
    title: '5. Advertising and analytics',
    paragraphs: [
      'The current beta does not include a third-party advertising or product '
          'analytics SDK. We plan to introduce usage analytics and may display '
          'paid advertisements. Before enabling a provider, we will update this '
          'Policy and the applicable app-store disclosures to identify material '
          'changes in the information collected and the purposes for which it is '
          'used.',
      'Ads may be contextual (based on the screen or game content) or, where '
          'permitted and with any consent required by law or platform rules, '
          'personalized using device, advertising, usage, and approximate-location '
          'information. Advertising and analytics partners may receive device or '
          'app identifiers, IP address, device details, app interactions, ad '
          'views, and ad interactions. We do not provide those partners with your '
          'password or private game-session notes.',
      'We do not sell personal information for money. Some privacy laws define '
          'the use of data for cross-context behavioral advertising as "selling" '
          'or "sharing." If we engage in that activity, we will provide the '
          'required notice and a way to opt out before or when it begins. You can '
          'also limit certain advertising identifiers through your device settings.',
    ],
  ),
  PrivacySection(
    title: '6. Retention and deletion',
    paragraphs: [
      'We keep personal information for as long as your account is active or as '
          'reasonably needed to provide the App, meet legal obligations, resolve '
          'disputes, prevent abuse, and enforce agreements. Retention varies by '
          'the type of information and why we use it. Backup copies and security '
          'logs may remain for a limited period after deletion.',
      'You can delete your account in Profile > Delete Account. Account deletion '
          'removes your profile, library, wishlist, sessions, friend relationships, '
          'and other account-linked content from active systems, subject to legal '
          'exceptions and limited backup retention. Shared game records and '
          'de-identified barcode-to-game mappings may remain because they are '
          'community game data and are not intended to identify you.',
      'During a pre-release beta, account data may also be reset or removed as '
          'the service and data model change.',
    ],
  ),
  PrivacySection(
    title: '7. Your choices and privacy rights',
    paragraphs: [
      'You can review or change available profile and sharing settings in the '
          'App, disconnect supported connectors, revoke camera permission in '
          'device settings, adjust device advertising settings, and delete your '
          'account in the App.',
      'Depending on where you live, you may have rights to request access, '
          'correction, deletion, or a copy of personal information; object to or '
          'restrict certain processing; withdraw consent; or opt out of targeted '
          'advertising or certain sales or sharing. We will not discriminate '
          'against you for exercising an applicable privacy right. To submit a '
          'request, use the developer contact shown on the App Store or Google '
          'Play listing. We may need to verify your identity before completing it.',
    ],
  ),
  PrivacySection(
    title: '8. Security and international processing',
    paragraphs: [
      'We use reasonable administrative, technical, and organizational safeguards '
          'designed to protect information. No method of transmission or storage '
          'is completely secure, so we cannot guarantee absolute security.',
      'Information may be processed in the United States and other countries '
          'where we or our providers operate. Those locations may have different '
          'data-protection laws than your home jurisdiction. Where required, we '
          'use appropriate safeguards for international transfers.',
    ],
  ),
  PrivacySection(
    title: '9. Children',
    paragraphs: [
      'The App is for a general audience and is not directed to children under '
          '13. We do not knowingly collect personal information from a child '
          'under 13 without legally required parental consent. If you believe a '
          'child has provided personal information contrary to this section, '
          'contact us through the developer contact shown on the app-store listing '
          'so we can investigate and delete it.',
    ],
  ),
  PrivacySection(
    title: '10. Entertainment-only service',
    paragraphs: [
      'Churtern Play is provided for personal entertainment and game-collection '
          'management. Game details, recommendations, randomizers, scores, '
          'statistics, convention information, and third-party content may be '
          'incomplete or inaccurate and should not be treated as professional, '
          'medical, legal, financial, safety, or other expert advice.',
    ],
  ),
  PrivacySection(
    title: '11. Changes and contact',
    paragraphs: [
      'We may update this Policy as the App changes. We will post the revised '
          'Policy with a new effective date and provide additional notice when '
          'required. Material changes affecting consent will not apply '
          'retroactively without any consent required by law.',
      'Questions or privacy requests may be submitted using the developer contact '
          'information on the Churtern Play App Store or Google Play listing. '
          'Please do not include passwords or unnecessary sensitive information '
          'in a request.',
    ],
  ),
];
