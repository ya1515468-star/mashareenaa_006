# Privacy and store Data safety review — owner action required

**This is an internal review worksheet, not a final user-facing privacy policy. Do not publish it as the app's privacy policy until the rights-holder/data controller verifies every statement and supplies contact and retention details.** Source code shows integration points but cannot prove which services are enabled in production or what they retain.

## Data categories indicated by the codebase

Verify every item against the shipped app and production environment before completing store forms:

- Account/authentication identifiers, sign-in provider results, email verification and session state.
- User profile information, usernames and user-generated content.
- Chat/community data, messages and uploaded attachments.
- Media selected/captured through camera and file-picker APIs, voice recordings and RTC voice/video sessions where users use those features.
- Approximate/precise device location when location features are used and permission is granted.
- Technical diagnostics, network state, device/platform metadata and logs that app code or third-party SDKs may collect; confirm exact collection.

## Service/provider review

The source integrates Supabase, Agora RTC, and Google/Apple sign-in packages. Confirm actual production configuration, each provider's role, processing locations, contracts, retention and subprocessors before describing them in a public policy or Play Data safety form. Do not assume every dependency sends personal data merely because it is installed.

## Required answers before policy publication

1. Legal name and contact of the data controller/privacy contact.
2. Countries/jurisdictions served and age restrictions/children's-data approach.
3. Data-by-data purposes, lawful basis where applicable, optional versus required fields, recipients, and whether data is shared or sold.
4. Retention schedule, backup/log retention, deletion/closure workflow and time required to complete requests.
5. Security safeguards, international transfers and privacy-request/incident handling process.
6. Public policy URL and in-app entry point; matching Google Play Data safety, permissions, content rating and account-deletion requirements.

No placeholder contact or unsupported guarantee has been invented. These are release blockers, not tasks that a build can settle automatically.
