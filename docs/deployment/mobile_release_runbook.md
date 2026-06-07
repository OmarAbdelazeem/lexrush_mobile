# LexRush Mobile Release Runbook

Reference for building and releasing the LexRush Flutter app for staging and production.

---

## Flutter environment

```bash
flutter --version   # confirm installed version
flutter doctor      # confirm toolchain health
```

No `.flutter-version` or FVM config file exists. The team should agree on and document the specific Flutter version in use; `sdk: ^3.11.5` is the current Dart SDK constraint in `pubspec.yaml`. Consider adding an `.fvmrc` or `.flutter-version` file to pin the version across machines.

---

## Dependencies

```bash
flutter pub get
```

---

## Static analysis

```bash
flutter analyze
```

Must report **no issues** before any build. Fix all errors and warnings before promoting a build.

---

## Test suite

Run the core suites before any release build:

```bash
flutter test test/backend_api_test.dart
flutter test test/auth_cubit_test.dart
flutter test test/profile_cubit_test.dart
flutter test test/backend_result_sync_service_test.dart
flutter test test/offline_result_retry_queue_test.dart
flutter test test/antonym_rush_cubit_test.dart
flutter test test/association_cubit_test.dart
flutter test test/sequencing_memory_cubit_test.dart
flutter test test/commas_cubit_test.dart
flutter test test/commas_text_area_widget_test.dart
```

Or run the full suite (slower due to game simulations):

```bash
flutter test
```

All tests must pass before promoting a build.

---

## Android app identifiers

| Field | Value | Notes |
|---|---|---|
| `applicationId` | `com.lexrush.app` | Final production ID — permanent once app is on Play Store |
| `namespace` | `com.lexrush.app` | Matches applicationId |
| `android:label` | `LexRush` | App display name shown on device launcher |
| Debug `applicationId` | `com.lexrush.app.debug` | Debug builds append `.debug` suffix — coexists with release on device |
| `versionName` | `0.1.0` | Set in `android/local.properties` |
| `versionCode` | `1` | Set in `android/local.properties` |
| `minSdk` | Flutter default | Inherits from `flutter.minSdkVersion` |
| `targetSdk` | Flutter default | Inherits from `flutter.targetSdkVersion` |

To update version for a release, edit `android/local.properties`:

```properties
flutter.versionName=1.0.0
flutter.versionCode=2
```

---

## Build commands

### Debug (local emulator / device)

Debug builds use `applicationId = com.lexrush.app.debug` and do **not** require `android/key.properties`.

```bash
flutter build apk --debug \
  --dart-define=LEXRUSH_API_BASE_URL=http://10.0.2.2:3000
```

Or run directly on a connected device:

```bash
flutter run --debug \
  --dart-define=LEXRUSH_API_BASE_URL=http://10.0.2.2:3000
```

### Staging APK

```bash
flutter build apk --debug \
  --dart-define=LEXRUSH_API_BASE_URL=https://staging.api.lexrush.example.com
```

Use a debug build for staging. Profile mode (`--profile`) is appropriate for performance checks; profile builds also require `android/key.properties` if signed release signing is configured.

### Production APK

```bash
flutter build apk --release \
  --dart-define=LEXRUSH_API_BASE_URL=https://api.lexrush.example.com
```

### Production App Bundle (Play Store)

```bash
flutter build appbundle --release \
  --dart-define=LEXRUSH_API_BASE_URL=https://api.lexrush.example.com
```

**Replace the placeholder URLs above with real values before use.**

---

## API base URL — required dart-define

`LEXRUSH_API_BASE_URL` is consumed by `lib/core/network/api_config.dart` via `String.fromEnvironment()`.

**If the dart-define is omitted, the app silently falls back to `http://10.0.2.2:3000`** (Android emulator host). There is no build error or visible warning. A staging or production build that forgets `--dart-define` will silently point at the emulator host and fail to connect.

**Rule: always supply `--dart-define=LEXRUSH_API_BASE_URL=<env-url>` for every staging and production build. Never promote a build without verifying the URL was set.**

### Open hardening item

Add a fail-fast mechanism (assertion or startup log warning) in release mode when `LEXRUSH_API_BASE_URL` is still the emulator default. This makes the misconfiguration visible immediately rather than silently misbehaving. Not implemented yet.

---

## Signing

`android/app/build.gradle.kts` is configured to read release signing from `android/key.properties`. `android/.gitignore` already excludes `key.properties`, `*.jks`, and `*.keystore` from version control.

**Behavior:**
- **Debug builds** — work without `android/key.properties`. No signing config is needed.
- **Release builds** (`--release`) — **fail with a clear Gradle error** if `android/key.properties` is absent. There is no silent fallback to debug signing.

### Setting up release signing (done once per machine)

1. Generate a release keystore (stored securely **outside** the repository):
   ```bash
   keytool -genkey -v \
     -keystore ~/lexrush-release.jks \
     -alias lexrush \
     -keyalg RSA -keysize 2048 \
     -validity 10000
   ```

2. Store the keystore file and passwords in a password manager. **Losing the keystore permanently blocks Play Store updates for this app.**

3. Create `android/key.properties` (gitignored, never committed):
   ```properties
   storePassword=<store-password>
   keyPassword=<key-password>
   keyAlias=lexrush
   storeFile=/Users/<you>/lexrush-release.jks
   ```

4. Verify the file is gitignored:
   ```bash
   git status android/key.properties   # must not appear as untracked
   ```

Do not add the keystore or `key.properties` to this repository.

---

## Secure storage

Auth tokens are stored using `flutter_secure_storage ^10.0.0-beta.4` via `lib/core/auth/secure_token_store.dart`.

**Note:** `flutter_secure_storage` is currently at a beta version. Review and decide whether to pin to a stable release before production distribution.

Behavior:
- Tokens are written on successful login or register.
- Tokens persist across app restarts (Keystore on Android, Keychain on iOS).
- Tokens are cleared on explicit logout, on `INVALID_REFRESH_TOKEN`, and on `REFRESH_TOKEN_REUSE_DETECTED`.

---

## Auth token persistence

- Access token and refresh token are stored in secure storage.
- On app start, stored tokens are read. If present, `GET /me` is called to validate the session.
- Refresh token rotation is handled client-side: a single-flight refresh call is made on `401 UNAUTHORIZED`; the new token pair replaces the stored pair.
- If refresh fails with `INVALID_REFRESH_TOKEN` or `REFRESH_TOKEN_REUSE_DETECTED`, tokens are cleared and the user is signed out automatically.
- `RATE_LIMITED` during refresh is treated as a transient network condition — tokens are preserved and the app shows the offline-authenticated state.

---

## Logout behavior

Explicit logout calls `POST /auth/logout` on the backend. If that call fails (network error or server error), local tokens are still cleared. The user is always signed out locally regardless of backend response.

---

## Offline result retry queue

Results that fail to submit after a backend session is created are stored in a local queue (SharedPreferences):

- Queue items are scoped per user — a different user's results are never submitted.
- Queue is drained on the next authenticated app launch or profile load.
- Successful submit or `SESSION_ALREADY_COMPLETED` removes the item from the queue.
- Retryable failures (network, server 5xx) keep the item queued.
- Non-retryable failures (400 validation errors, contract violations) discard the item.
- No new backend sessions are created during retry — only existing `sessionId` values are reused.

---

## Analytics and crash reporting posture

No analytics or crash reporting vendor is configured. `AnalyticsPort` and `CrashReporter` are interfaces with no-op implementations for production calls. All analytics and crash calls are no-ops until a real adapter (e.g. Firebase, Sentry) is wired up and configured.

The foundation is in place to add a vendor without touching game or auth logic.

---

## Backend dependency

Before promoting a mobile build to staging or production:

```bash
npm run smoke:prod   # run from the LexRush backend repo
```

The backend must pass its production smoke test before a mobile build is promoted. A mobile release on a broken backend will surface as auth or result sync failures.

---

## Manual QA checklist

Perform this checklist on a physical device (Android or iOS) for each release candidate. See also [`docs/testing/Testing_Tutorial.md`](../testing/Testing_Tutorial.md) for emulator/device setup.

### Auth
- [ ] Register a new account — lands on Today screen
- [ ] Log out — returns to sign-in screen
- [ ] Log in with existing account — loads progress, Today screen shows correctly
- [ ] Log in with wrong password — shows error, does not crash
- [ ] Force-expire access token (or wait) — app refreshes silently and continues
- [ ] Use an invalid refresh token — app signs out cleanly, sign-in screen appears

### Today / Daily Training
- [ ] Today screen loads recommended games
- [ ] Completing a game marks it done on Today screen
- [ ] Streak and XP display correctly

### Games — smoke each mode
- [ ] Antonym Rush: starts, plays one round, ends, result syncs
- [ ] Association: starts, plays one round, ends, result syncs
- [ ] Sequencing Memory: starts, plays one route, ends, result syncs *(see TTS caveat below)*
- [ ] Commas: starts, plays one prompt, ends, result syncs

### Profile
- [ ] Profile screen loads progress and skills
- [ ] Achievements screen loads and shows earned achievements

### Offline / sync
- [ ] Kill backend mid-session — result submission fails gracefully, "Couldn't sync progress" shown
- [ ] Restart app with backend online — pending result is retried and synced

### API URL
- [ ] Confirm the build was assembled with the correct `--dart-define=LEXRUSH_API_BASE_URL` before starting QA

---

## Known emulator caveats

### Sequencing Memory — TTS (text-to-speech)

`flutter_tts` requires a TTS engine installed on the device. Stock AOSP emulator images often ship without Google TTS. Symptoms on an unprepared emulator:

- Audio does not play.
- A failsafe timer fires and the game continues silently.

**Resolution:** Use a physical device or an emulator with Google TTS installed (Google Play system image or manually installed TTS APK). Do not treat missing TTS as a build or logic bug.

---

## Open release questions

These items must be resolved before a public production release:

1. **Release keystore** — generate keystore, create `key.properties` locally (see Signing section). `applicationId` and signing config are already wired; only the keystore file itself remains.
2. **Flutter version pinning** — add `.fvmrc` or `.flutter-version` to ensure all developers and CI use the same Flutter version.
3. **iOS configuration** — Bundle ID, provisioning profiles, entitlements, and App Store Connect setup not yet documented.
4. **Play Store / TestFlight setup** — store listings, screenshots, content rating, privacy policy URL not yet prepared.
5. **Analytics / crash vendor** — decide on vendor (Firebase, Sentry, etc.) and wire up the existing `AnalyticsPort` / `CrashReporter` adapters. Firebase requires the `com.lexrush.app` applicationId registered in the Firebase console; the `.debug` suffix variant needs a separate Firebase app entry.
6. **flutter_secure_storage beta** — review `^10.0.0-beta.4` and decide whether to move to a stable version before production.
7. **Fail-fast on missing API URL** — add a visible warning or assertion in release mode when `LEXRUSH_API_BASE_URL` is still the emulator default (`http://10.0.2.2:3000`).
8. **CI/CD pipeline** — no automated build or test pipeline exists; consider GitHub Actions or equivalent.
9. **Installed debug app rename** — devices with the old `com.example.lexrush` debug build installed must manually uninstall it; Android treats the new `com.lexrush.app.debug` as a different app.
