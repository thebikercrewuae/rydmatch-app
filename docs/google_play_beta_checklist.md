# Google Play Beta Readiness

## Build Settings

- Package name: `com.rydmatch.app`
- Build output: Android App Bundle (`.aab`)
- Minimum SDK: 24
- Target SDK: 35
- Compile SDK: 36
- Version source: `pubspec.yaml`
- Cleartext HTTP traffic: disabled

Before every Play upload, increase the build number in `pubspec.yaml`.

Example:

```yaml
version: 1.0.15+15
```

## Internal Testing Release Notes

Suggested release name:

```text
RydMatch 1.0.14 Internal Beta
```

Suggested release notes:

```text
Internal beta release for RydMatch.

Includes improvements to profile photo reliability, premium entitlement syncing, live ride stability, diagnostics logging, Android target SDK readiness, and app bundle release preparation.
```

## Short Description

```text
Find compatible riders, plan routes, join group rides, and ride safer together.
```

## Full Description Draft

```text
RydMatch helps motorcycle and bicycle riders connect with compatible riding partners, plan routes, create ride groups, and stay connected during live rides.

Key features:
- Discover riders based on riding style, skill level, ride preferences, distance, and community settings.
- Match and chat with riders before planning a ride.
- Create ride groups and invite matched riders.
- Plan routes with map support and ride details.
- Join live rides with shared rider locations.
- Use premium features such as voice chat, ride analytics, route weather, and visibility boosts where available.
- Add an emergency contact for safety alerts during rides.
- Submit verification requests so trusted riders can stand out.

RydMatch is built for riders who want safer, better-matched, and more social rides.
```

## Data Safety Notes

Use these as the basis for Google Play Data Safety answers.

- Personal info: name, email, date of birth, gender, profile bio, emergency contact details.
- Photos and videos: profile photos, bike photos, verification images, post/chat images.
- Location: approximate location for discovery, precise location for route planning, live ride tracking, and emergency alerts.
- Messages: chat messages and ride group/live ride messages.
- App activity: swipes, matches, ride groups, route planning, live ride activity, diagnostics events.
- Purchases: premium subscription status and entitlement state.
- Audio: microphone access is used only for premium live ride voice chat.
- Diagnostics: app error logs may include feature/action context to help debug beta issues.

## Permission Explanations

- `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`: rider discovery, route planning, live ride tracking, and emergency alerts.
- `CAMERA`: profile photos, bike photos, and rider verification.
- `READ_MEDIA_IMAGES` / legacy storage read: selecting profile, bike, chat, post, or verification images.
- `RECORD_AUDIO`: premium live ride voice chat.
- `MODIFY_AUDIO_SETTINGS` and `BLUETOOTH_CONNECT`: voice chat audio routing and Bluetooth headset support.
- `INTERNET`: Supabase, maps, messaging, purchases, diagnostics, and media loading.

## Pre-Launch Smoke Test

Run these before promoting the beta:

1. Fresh install and sign up.
2. Create/edit profile with profile photo and bike photos.
3. Confirm discovery and matches show profile photos.
4. Match two test users and open match profile.
5. Create a ride group.
6. Start a live ride and join from another account.
7. Confirm planned route and rider locations appear in live ride.
8. Test premium subscription unlock or restore on a tester account.
9. Test premium voice button visibility and connection.
10. Trigger an app error intentionally only if needed, then confirm Admin Diagnostics shows it.
11. Confirm sign out/sign in keeps profile photos and premium state.

## Known External Dependency

Emergency SOS SMS delivery depends on the SMS provider account being approved for live traffic and UAE/international delivery. Keep SOS delivery validation separate from the Google Play beta upload until the provider setup is complete.
