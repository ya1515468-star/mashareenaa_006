# Architecture overview

## Client

The Android client is a Flutter application. `lib/` contains UI, routing, state management, auth/session handling, media features, chat/community features and service integrations. Android platform settings and release signing are maintained under `android/`.

## Backend boundary

Supabase provides authentication, PostgreSQL, storage and Edge Functions. Database migrations are under `supabase/migrations/`; Edge Functions are under `supabase/functions/`. Authorization-sensitive operations must be enforced on the backend using RLS, database grants and validated RPCs. The Flutter client must not contain service-role credentials.

Agora RTC is integrated for real-time voice/video; token generation must remain on the backend. Google/Apple sign-in should only be enabled when provider settings, redirect URIs and release signing fingerprints are configured for the correct environments.

## Build boundary

GitHub Actions runs Java 17 and the configured Flutter stable version, resolves dependencies, analyzes Dart code, runs tests, validates signing secrets, creates a signed ARM64 APK, verifies architecture/signature and uploads the APK with build metadata/checksum/license inventory. Temporary signing files are removed in an always-run cleanup step.

## Deployment separation

Use separate development/staging/production Supabase projects or equally strict environment boundaries. Before deployment, verify production migrations, storage buckets, RLS policies, auth redirect URLs, email settings, Edge Function secrets, CORS and logging/retention. A successful APK build does not deploy or validate backend policies.
