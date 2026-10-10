# Production release checklist

A CI build is a technical gate, not proof of full legal, privacy, backend or device readiness.

## Source and signing

- [ ] Confirm the legal copyright claimant and right to distribute all project-specific content.
- [ ] Review `LICENSE`, `COPYRIGHT.md`, `NOTICE` and generated `THIRD_PARTY_NOTICES.txt`.
- [ ] Audit every image, animation, sound, video, icon, template and media asset for ownership or commercial redistribution rights.
- [ ] Set `version:` to the intended release version and choose a build number higher than any version already uploaded to Google Play. Do not infer store version from a GitHub run number.
- [ ] Confirm this is the correct production signing key, back it up securely offline and keep it only in GitHub Actions secrets.
- [ ] Confirm Git history/artifacts contain no keystore, `key.properties`, service-role key, database credentials or other private credential.

## Cloud build

- [ ] `flutter pub get` succeeds from the committed manifest.
- [ ] Dart analysis and `flutter test` succeed.
- [ ] The signed ARM64 build succeeds without R8 missing-class errors.
- [ ] `apksigner verify` succeeds; APK inspection proves `lib/arm64-v8a/` exists and other ABIs are absent.
- [ ] Save build information, SHA-256 checksum and generated dependency license inventory.
- [ ] Install the exact artifact on a real ARM64 Android device. Smoke-test auth/deep links, chat, media upload/download, profile changes, voice recording, RTC calls, lifecycle and network-loss recovery.

## Backend and security

- [ ] Validate migrations and RLS/grants/RPC/Storage/Edge Function authorization against the intended production Supabase project.
- [ ] Verify Edge Function secrets, Agora token signing, auth redirects, email templates and storage bucket policies.
- [ ] Ensure no privileged secret is embedded in Flutter code, Android resources or the APK.
- [ ] Review permissions, HTTPS-only networking, app links and target SDK against current Play requirements.

## Privacy and legal — release blockers until confirmed

- [ ] Publish an accurate privacy policy at a stable public URL and link it in store listing/in-app UI where required.
- [ ] Complete Google Play Data safety from verified runtime data flows, providers, retention and deletion behavior.
- [ ] Confirm support/privacy contact, legal rights-holder, jurisdictions, retention periods and user-data deletion process.
- [ ] Verify age rating, user-generated-content moderation/reporting/blocking, terms and applicable digital-item disclosures.
- [ ] Obtain owner/legal review. Do not publish the internal privacy worksheet as a finished policy.

## Publish

- [ ] Review checksum and signing certificate fingerprint.
- [ ] Prefer internal testing before production rollout and review Play Console reports/crash logs.
- [ ] Tag a release only after the exact source commit passes all gates; retain the APK, checksum, build metadata and source commit SHA.
