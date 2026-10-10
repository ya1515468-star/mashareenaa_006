# Security policy

## Reporting a vulnerability

Do not publish credentials, personal data, exploit details for an active issue, or production database records in a public issue. Use GitHub private vulnerability reporting for this repository if enabled. If it is unavailable, contact the repository maintainer privately before sharing sensitive details; never paste secrets into commits or Actions logs.

## Secret handling

- Never commit Supabase service-role keys, database connection strings, signing keystores, passwords, access tokens or `.env` files.
- Store the Android release signer only in GitHub Actions secrets/environment secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
- A Supabase publishable key and an Agora App ID are client identifiers, not substitutes for server-side authorization. Keep service-role keys and Agora token-generation secrets on the server only.
- If a signing key or privileged credential is exposed, revoke/rotate it and assess the appropriate signing-key recovery path before release.

## Security checks before release

- Review Supabase RLS policies, grants, RPC execution rights, storage policies and Edge Function authorization in the target production project.
- Confirm there is no service-role credential or private signing material in Git history, release artifacts, logs or application assets.
- Verify HTTPS-only networking and the exact third-party data flows documented for store privacy forms.
- Run current dependency and Android SDK/target-API checks before publishing.
