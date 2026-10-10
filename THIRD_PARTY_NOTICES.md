# Third-party notices

This file records known third-party material. It is not a substitute for the generated release inventory or a complete rights audit of binary, image, icon, sound, video and template assets.

## Bundled Arabic fonts

- **Noto Kufi Arabic** — Copyright © 2019 Google LLC; SIL Open Font License 1.1 (OFL-1.1). Bundled as `assets/fonts/decorative/MashareenaKufi-Regular.ttf`.
- **Noto Naskh Arabic** — Copyright © 2019–2020 Google LLC; SIL Open Font License 1.1 (OFL-1.1). Bundled as `assets/fonts/decorative/MashareenaNaskh-Regular.ttf`.
- **Amiri** — Copyright © 2010–2022 The Amiri Project Authors; SIL Open Font License 1.1 (OFL-1.1). Bundled as `assets/fonts/decorative/MashareenaAmiri-Regular.ttf`.

The original font family names remain in font metadata. Applicable notices and the full license text are in `assets/fonts/decorative/OFL.txt`; the font directory is already included by `pubspec.yaml`.

## Runtime and build dependencies

The application uses Flutter/Dart packages listed in `pubspec.yaml`, Android Gradle/AndroidX components, Supabase services and Agora RTC integration. Each package keeps its own copyright and license; the MASHAREENA proprietary notice does not relicense them.

The ARM64 workflow generates `THIRD_PARTY_NOTICES.txt` from the resolved dependency package cache and attaches it to the build artifact. Review entries marked as missing a conventional license file and verify all non-code media and commercial assets have documented distribution rights before publishing.

## Asset review requirement

A final media/assets audit is still required for every image, animation, sound, video, icon, name template and store item under `assets/`. Preserve original creator notices and license conditions. Do not publish content with unclear rights.
