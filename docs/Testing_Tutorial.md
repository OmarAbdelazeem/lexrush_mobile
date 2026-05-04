# Manual testing tutorial (emulator, taps, screenshots)

This guide explains how you can **manually test** a mobile Flutter app the way we did in development: run on an **Android emulator** or **physical device**, optionally **iOS Simulator** on macOS, **navigate with taps** (finger or automation), **capture screenshots or recordings**, and use those artifacts to **find bugs** and **document behavior**. You can apply the same workflow to **any** Android or iOS app, not only LexRush.

---

## What is this type of testing called?

Several names overlap depending on what you emphasize:

| Name | What it means |
|------|----------------|
| **Manual testing** | A human decides what to try, observes the app, and judges pass/fail. No test script required. |
| **Exploratory testing** | Manual testing where you learn the product while testing: follow curiosity, try edge cases, note surprises. |
| **Ad hoc testing** | Informal manual runs without a fixed script—good for smoke checks (“does it start?”) or quick checks after a change. |
| **UI / UX verification** | Focusing on layout, readability, animations, and whether the screen matches design intent. |
| **Smoke testing** | A short pass over critical paths to see if the build is “on fire” (crashes, blank screens, broken navigation). |
| **Acceptance / UAT-style checking** | You verify the app against user stories or acceptance criteria (“As a player, I see four options…”). |

**What it is not (by itself):**

- **Automated UI testing** (e.g. integration tests with `integration_test`, Appium, Maestro) — those use code or tools to drive the UI repeatedly.
- **Unit testing** — tests single functions/classes in isolation (`flutter test`).
- **Snapshot / golden tests** — compares rendered widgets to approved images in CI.

The workflow here is **manual testing** with **optional helpers**: emulator, `adb`, and screenshots. Sometimes people say **“manual QA”** or **“hands-on device testing.”**

---

## Prerequisites (one-time setup)

1. **Flutter SDK** installed and on your `PATH`.
2. **Android Studio** (or standalone SDK + emulator) with at least one **AVD** (Android Virtual Device).
3. **adb** (Android Debug Bridge) — usually with Android SDK `platform-tools`. Confirm:

   ```bash
   adb version
   flutter doctor
   ```

4. **USB debugging** — required only for a **physical** Android phone (see [Physical Android device (USB)](#physical-android-device-usb) below). The emulator uses the local `adb` bridge without USB.

---

## Step 1: See available devices

```bash
flutter devices
```

You should see something like `sdk gphone64 arm64 • emulator-5554 • android-arm64`. The **`emulator-5554`** part is the **device serial** you pass to `adb -s`.

---

## Step 2: Start the emulator (if not running)

- From Android Studio: **Device Manager** → play button on an AVD.
- Or list and launch from CLI:

  ```bash
  flutter emulators
  flutter emulators --launch <emulator_id>
  ```

Wait until the home screen is ready.

---

## Physical Android device (USB)

Use a real phone when you care about **performance**, **touch/gestures**, **manufacturer-specific bugs**, or **store-like** conditions.

1. On the phone: **Settings → About phone** → tap **Build number** seven times to enable **Developer options**.
2. **Settings → Developer options** → enable **USB debugging**.
3. Connect USB (or wireless debugging if you have it set up).
4. On the computer:

   ```bash
   adb devices
   ```

   If the device shows `unauthorized`, unlock the phone and **Allow USB debugging** when prompted.

5. Run Flutter against that device id (example: `ZY22ABC123`):

   ```bash
   flutter devices
   flutter run -d ZY22ABC123
   ```

6. Use the same **`adb -s <device_id> ...`** commands as with the emulator (`screencap`, `input tap`, `logcat`).

**When to prefer a physical device over the emulator:** jank or frame drops, sensor/camera, production GPU drivers, background limits, or “it works on emulator only” reports.

---

## Step 3: Run your app in debug mode

From your project root:

```bash
cd /path/to/your_project
flutter run -d emulator-5554
```

Replace `emulator-5554` with whatever `flutter devices` shows.

**Why debug mode for manual testing?**

- **Hot reload** (`r` in the terminal) after small code changes.
- **Logs** (`print`, `debugPrint`) appear in the terminal.
- **DevTools** link is printed for profiling later if needed.

Leave this terminal open while you test, or use **Run and Debug** in your IDE—same idea.

---

## Step 4: Interact like a user

### Option A: Use the emulator with your mouse

Click, scroll, type in text fields. This is the most natural **manual test**.

### Option B: Use `adb` to simulate taps (helper, not full automation)

When the emulator window is awkward or you want **scriptable coordinates** (as in our LexRush sessions):

1. **Screen size** (logical pixels the shell uses can match the device):

   ```bash
   adb -s emulator-5554 shell wm size
   ```

   Example: `Physical size: 1280x2856` — width × height.

2. **Tap** at pixel coordinates `(x, y)` (origin top-left):

   ```bash
   adb -s emulator-5554 shell input tap 640 1600
   ```

3. **Back** gesture / key:

   ```bash
   adb -s emulator-5554 shell input keyevent KEYCODE_BACK
   ```

4. **Relaunch** the app:

   ```bash
   adb -s emulator-5554 shell am start -n your.package.id/.MainActivity
   ```

   Replace with your real **package/activity** from `AndroidManifest.xml`.

**Caveat:** `input tap` uses **screen coordinates**. Different themes, fonts, or layouts change where buttons are. Prefer **Option A** for learning; use **Option B** when you have **mapped** coordinates from a screenshot or UI hierarchy dump.

### Option C: `adb` UI hierarchy dump (advanced)

You can dump the view tree to XML to find bounds (useful for automation or accessibility checks):

```bash
adb -s emulator-5554 shell uiautomator dump /sdcard/window_dump.xml
adb -s emulator-5554 pull /sdcard/window_dump.xml .
```

Open the XML and search for `bounds="[left,top][right,bottom]"` for a widget; the **center** of that rectangle is a reasonable tap target.

---

## Step 5: Capture screenshots

### From host (recommended — easy to open and attach)

```bash
adb -s emulator-5554 exec-out screencap -p > ~/Desktop/my_screen.png
```

- **`exec-out`** streams raw PNG bytes to your machine (fewer encoding issues than `adb pull` of a raw file on older setups).
- Use a **fixed path** per session, e.g. `screenshots/TC01_open_app.png`, so you can compare runs.

### What screenshots are *for*

1. **Evidence** — proves what you saw at a given moment (for bugs, PRs, design review).
2. **Regression comparison** — before/after images when UI changes.
3. **Coordinate reference** — open the PNG in an image viewer that shows cursor position, or an editor, to estimate `(x, y)` for `adb shell input tap`.
4. **Documentation** — user-facing or internal wiki steps.

Screenshots are **not** a substitute for automated tests; they complement **manual** and **automated** checks.

### Screen recording (Android)

Short videos help for **animations**, **timing bugs**, and repro steps that are awkward in still images.

```bash
# On device; max ~3 minutes per file on many builds — keep clips short
adb -s emulator-5554 shell screenrecord /sdcard/demo.mp4
# Ctrl+C in terminal to stop, then:
adb -s emulator-5554 pull /sdcard/demo.mp4 .
```

Use a **physical device** serial instead of `emulator-5554` when needed. For **iOS Simulator**, see below.

---

## Step 6: Read logs while testing

With `flutter run`, logs print in the terminal. For a **released** APK or when Flutter isn’t attached:

```bash
adb -s emulator-5554 logcat
```

Filter (example, noisy → quieter):

```bash
adb -s emulator-5554 logcat *:S flutter:V
```

Use logs to see **crashes**, **route changes**, **custom telemetry** (e.g. `[AssociationTelemetry] round_start ...`), and **timing**.

---

## Step 7: A structured manual test (recommended template)

1. **Objective** — e.g. “Player can finish one 60s Association session and reach results.”
2. **Environment** — emulator model, API level, app version / git commit.
3. **Steps** — numbered, exact taps or routes (Mode → Game → …).
4. **Expected result** — e.g. “Results screen shows score, accuracy, review list.”
5. **Actual result** — pass/fail + screenshot + log snippet if fail.
6. **Notes** — performance, jank, confusing copy.

Repeat for **critical paths**: first launch, login, paywall, offline, rotation (if supported), etc.

---

## How do you detect issues from screenshots and sessions?

You are doing **visual + behavioral** triage:

1. **Layout** — clipping, overflow yellow stripes in debug, misaligned cards, touch targets too small.
2. **State** — wrong score/timer, stale data after navigation, “Paused” overlay stuck.
3. **Visual regressions** — colors, icons, fonts differ from design or last release.
4. **Animation feel** — a single screenshot cannot show motion; use short **screen recordings** or **observe live** for “stutter” or “wrong timing.”
5. **Cross-check with logs** — if the UI shows “Missed” but logs say `outcome=correct`, you found a **desync bug** (logic vs presentation).
6. **Reproduce** — note exact steps; if it only happens after fast tapping or low storage, mention that.

**False positives to watch for:** emulator scaling, GPU bugs on specific API levels, and **`adb tap` missing** widgets because coordinates were wrong—always confirm with a **manual tap** once.

---

## Reset app data / clean install (Android)

Manual tests should sometimes start from a **known state** so old cache or onboarding flags do not hide bugs.

**Clear app data** (app still installed; user data wiped):

```bash
adb -s emulator-5554 shell pm clear your.package.id
```

**Uninstall** completely:

```bash
adb -s emulator-5554 uninstall your.package.id
```

After uninstall, run `flutter run` again to install the debug build. Replace the serial for a physical device.

---

## iOS Simulator (Flutter, macOS)

You need **Xcode** and a **Simulator** runtime. Flutter will list simulators as devices.

1. **List simulators:**

   ```bash
   xcrun simctl list devices available
   ```

2. **Boot one** (optional; Flutter can boot when you run)—use the **exact** device name from the list (examples differ by Xcode version):

   ```bash
   xcrun simctl boot "iPhone 16"
   ```

3. **Run the app:**

   ```bash
   flutter devices
   flutter run -d <simulator_device_id>
   ```

   The device id looks like a long UUID in `flutter devices` output.

4. **Screenshot** — Simulator menu **File → Save Screen Shot**, or from host:

   ```bash
   xcrun simctl io booted screenshot ~/Desktop/ios_screen.png
   ```

   (`booted` targets the currently booted simulator.)

5. **Recording** — Simulator **File → Record Screen** for a video, or use macOS screen capture tools.

6. **Logs** — Flutter prints from `flutter run`; for native noise use **Console.app** filtering by your app.

Accessibility hierarchy: Xcode **Accessibility Inspector** while Simulator is focused.

---

## Flutter debug aids for manual testing

These help during **live** sessions; they do not replace screenshots or tests.

- **Performance overlay** — In your app (debug), enable the FPS/CPU overlay (often via MaterialApp’s debug flags or Flutter tooling). Official guide: [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance).
- **Debug banner** — The small **DEBUG** ribbon confirms you are not looking at a release build by mistake.
- **Profile mode** — For closer-to-release performance without full release stripping:

  ```bash
  flutter run --profile -d emulator-5554
  ```

  Then open **DevTools** from the printed link to inspect frames and memory.
- **Slow animations** — Some teams toggle animation speed in dev to verify motion; keep this in mind when judging “snappy” behavior.

---

## Manual testing vs automated tests

They solve different problems; use **both** on serious projects.

| Layer | Tooling | Best for |
|-------|---------|----------|
| Static analysis | `flutter analyze`, lints | Typos, dead code, many logic smells |
| Unit / widget tests | `flutter test`, mocks | Cubits, parsers, formatting, single widgets |
| Integration tests | `integration_test` package | Full flows in a test driver; can run on device/CI |
| Manual / exploratory | Emulator, device, adb | Feel, ambiguity, “is this fun?”, one-off edge cases |

**Rule of thumb:** automate what is **frequent and deterministic**; keep manual passes for **new features**, **releases**, and **UX** before you invest in another integration test.

---

## Bug report template (copy-paste)

Use this when filing an issue (GitHub, Jira, Slack) so others can reproduce quickly.

```text
Title: [Platform] Short description (e.g. Association: results show 0% after correct round)

Environment:
- App version / git commit: 
- Device: (e.g. Pixel 7 API 36, or iPhone 16 Simulator)
- Flutter: flutter --version (paste)

Steps to reproduce:
1. 
2. 
3. 

Expected:
Actual:

Attachments:
- Screenshot(s): 
- Screen recording (if animation/timing): 
- Log excerpt (logcat / Xcode console / flutter run): 

Notes:
- Always happens vs intermittent:
- Workaround if any:
```

---

## Mapping this to “other projects”

| Piece | Same idea elsewhere |
|-------|---------------------|
| `flutter run -d <device>` | `npm run ios`, Xcode run, Android Studio run |
| `adb` | iOS: **Simulator** + `xcrun simctl` — see [iOS Simulator](#ios-simulator-flutter-macos) above |
| Screenshots | Essential for any mobile or web manual QA |
| Structured test cases | Same template for web: browser, URL, steps, expected DOM/screenshot |

---

## Quick reference — commands used in LexRush-style sessions

```bash
# Devices & run
flutter doctor
flutter devices
flutter run -d emulator-5554
flutter run --profile -d emulator-5554

# Android: interaction & capture
adb devices
adb -s emulator-5554 shell wm size
adb -s emulator-5554 shell input tap X Y
adb -s emulator-5554 exec-out screencap -p > screenshot.png
adb -s emulator-5554 shell screenrecord /sdcard/demo.mp4   # Ctrl+C to stop, then pull
adb -s emulator-5554 pull /sdcard/demo.mp4 .
adb -s emulator-5554 shell input keyevent KEYCODE_BACK
adb -s emulator-5554 shell am force-stop your.package.id
adb -s emulator-5554 shell pm clear your.package.id
adb -s emulator-5554 uninstall your.package.id

# Android: launch main activity (replace package/activity from AndroidManifest)
adb -s emulator-5554 shell am start -n your.package.id/.MainActivity

# iOS Simulator
xcrun simctl list devices available
xcrun simctl io booted screenshot ~/Desktop/ios_screen.png
```

---

## Summary

- **Name of this activity:** primarily **manual testing** (often **exploratory** or **smoke** testing); screenshots support **visual verification** and **bug reporting**.
- **Core flow:** devices → run app → interact (mouse or `adb`) → screenshot + logs → compare to expected behavior.
- **Screenshots help** document reality, estimate tap positions, and catch UI/state bugs; **logs** catch logic and lifecycle issues **behind** the pixels.

**LexRush:** keep **deterministic checks** in **`flutter test`** and **`flutter analyze`**. Use **manual** passes on emulator or device for **feel**, **real hardware**, and **whole-session flow**; use the [bug report template](#bug-report-template-copy-paste) when something breaks.

Optional deeper automation (not covered step-by-step here): [**integration_test**](https://docs.flutter.dev/testing/integration-tests), [**Maestro**](https://maestro.mobile.dev/), or Appium for repeatable UI drives.
