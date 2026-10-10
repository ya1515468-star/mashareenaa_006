# MASHAREENA | مشاريعنا

**Flutter + Supabase mobile application** · Android ARM64 release workflow

MASHAREENA is a mobile social/community application. The repository contains Flutter/Dart client code, Android build/signing configuration, Supabase migrations and Edge Functions, and automated tests.

A successful CI build is a technical gate, not proof of full legal, privacy, backend or on-device readiness. Follow [the production release checklist](docs/PRODUCTION_RELEASE_CHECKLIST.md) before public distribution.

## Main components

- `lib/` — Flutter application, UI, state management, auth, media, chat and service integrations.
- `android/` — Android manifest, Gradle configuration, release shrinker rules and signing configuration.
- `supabase/migrations/` — database migrations and authorization policies.
- `supabase/functions/` — Supabase Edge Functions.
- `test/` and `test_support/` — automated tests and test helpers.
- `assets/` — application assets and bundled Arabic fonts.

## Local setup

Requirements: the Flutter stable version configured in `.github/workflows/build-android.yml`, Java 17, Android SDK/NDK accepted by the Android Gradle Plugin, and access to the intended Supabase environment for runtime testing.

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Expected ARM64 output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

Do not commit `android/key.properties`, `.jks`/`.keystore` files, service-role keys, access tokens, or production credentials. The release workflow gets signing material only from GitHub Actions secrets.

## Cloud signing secrets

Configure these repository or `production` environment secrets in GitHub Actions:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Their values must never appear in source code or project archives. Temporary signing files are removed at job end.

## Build and release

A push to `main`/`master` starts the Android ARM64 workflow. A manual run is available from GitHub Actions → **MASHAREENA Android ARM64 Release** → **Run workflow**. Confirm versioning, signing-key continuity, privacy disclosures, third-party rights and the release checklist before distributing publicly.

## Documentation and legal notices

- [`COPYRIGHT.md`](COPYRIGHT.md) and [`LICENSE`](LICENSE) — ownership notice and proprietary-use terms.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — known third-party components and generated license inventory.
- [`SECURITY.md`](SECURITY.md) — security reporting and secret handling.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — repository layout and system boundaries.
- [`docs/PRODUCTION_RELEASE_CHECKLIST.md`](docs/PRODUCTION_RELEASE_CHECKLIST.md) — release gates.
- [`docs/PRIVACY_AND_DATA_SAFETY.md`](docs/PRIVACY_AND_DATA_SAFETY.md) — internal data-disclosure review; not a final public privacy policy.

## License

Original project-specific source code, branding and designs are reserved by the project rights-holder unless a file states otherwise. Third-party dependencies, fonts and other assets remain under their own copyright and licenses. See `LICENSE`, `COPYRIGHT.md` and `THIRD_PARTY_NOTICES.md`.
