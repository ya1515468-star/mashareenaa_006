# Contributing to MASHAREENA

## Change scope

Keep changes focused. Avoid mixing UI behavior with Android signing/build changes unless necessary. Never commit generated build output or secret files.

## Validation

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

For changes affecting chat, uploads, storage, RPC/RLS or voice/video, run targeted tests and validate against a non-production environment. Unit tests alone do not prove backend policy correctness or real-device behavior.

## Database changes

Add new Supabase migrations rather than editing previously deployed migrations unless the deployment process explicitly authorizes it. Review grants, RLS policies, SECURITY DEFINER functions, function search paths and execute permissions. Never put service-role credentials in Flutter code.

## Release signing

Release signing is performed by GitHub Actions. Never add `android/key.properties`, `android/app/*.jks`, or `*.keystore` files to a commit.
