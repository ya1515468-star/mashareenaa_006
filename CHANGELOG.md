# Changelog

Entries document source changes; they do not imply an app-store release has shipped.

## Unreleased — production release hardening

- Pin `record` to 6.2.1, the version already resolved successfully in the cloud CI path, instead of rewriting the dependency only during CI.
- Remove two empty garment-category asset declarations missing from the uploaded source tree.
- Narrow ProGuard keep rules so optional Flutter deferred-component classes are not forcibly retained in the minified APK; the previous attempt failed R8 due to unresolved optional Google Play Core classes.
- Explicitly disable cleartext networking, consistent with the existing Android network security configuration.
- Add copyright/ownership notices, full third-party font license text and build/security/release documentation.
- Add build metadata, SHA-256 checksum and a generated dependency-license inventory to ARM64 release artifacts.

The candidate must pass the next CI run and on-device smoke test before being marked released.
