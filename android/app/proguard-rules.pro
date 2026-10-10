# MASHAREENA release baseline.
# Keep Flutter plugin registrants/platform channel plugins discoverable without
# forcing every optional Flutter embedding class (including deferred Play Store APIs)
# to remain in the minified APK.
-keep class io.flutter.plugins.** { *; }

-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
