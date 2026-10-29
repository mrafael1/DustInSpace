# Android and iOS test builds

The native game exports through Godot 4.7, not Expo/React Native. Android can be built on Windows;
iOS export and signing need a Mac with Xcode. A friend's Mac or a hosted Mac runner works.
This setup does not publish anything or implement the paid chapter unlock.

## Shared setup

Install the **Godot 4.7 stable editor and matching export templates**, plus Python 3.10 or later.
Use the same Godot version on the Mac. From the repository root:

```sh
python tools/release/mobile.py configure
```

This generates the ignored local `export_presets.cfg` from the checked-in template. Any previous
non-generated presets are preserved once in `output/release/original_export_presets.cfg`.
Changes belong in `tools/release/export_presets.cfg.in`, not the generated file. Do not run
configuration while editing presets in the Godot editor.

`tools/release/mobile.json` is the version/build source for all three targets. Increase `build`
for every upload, and `version` for a new public version. **`com.alonelab.dustinspace` is the
confirmed Android package ID and iOS bundle ID** (approved 2026-10-29). Use it for both store app
records. `--app-id com.owner.dustinspace` overrides it for a local build.
Use `--godot /path/to/Godot` if Godot is not on PATH.

All targets include the balance and art JSON files, and exclude test tooling, scratch outputs,
documentation and the analytics endpoint configuration. Android has no Internet permission and
does have vibration permission. Debug APKs still expose debug tools; Play and iOS use release
exports. The campaign currently remains fully playable without a purchase integration.

## Android APK: direct phone testing

Install Java (Godot recommends JDK 17; newer compatible JDKs work) and Android SDK tools. Set
**Editor Settings > Export > Android > Java SDK Path and Android SDK Path** in Godot.
Install platform 36 and matching build tools in Android Studio's SDK Manager.

```sh
python tools/release/mobile.py android-apk
python tools/release/verify_android.py exports/android/dust-in-space-test.apk
adb install -r exports/android/dust-in-space-test.apk
```

The APK is signed with Godot's local debug keystore. Enable USB debugging and authorize the
computer on the phone before installing. If an installed copy uses a different signing key,
keep its save if needed before removing it; Android cannot update it with another key.
The APK uses the prebuilt template's SDK levels; inspect the resulting manifest before testing
or distributing. The Play target explicitly selects API 36 through Gradle.

The verifier checks packaged runtime data, development/analytics exclusions and native ELF
alignment. Also check the APK with the SDK tools `apksigner verify --verbose`, `aapt dump badging`
and `zipalign -c -P 16 4`; these cover signing, manifest and APK container alignment separately.

## Android AAB: Play internal testing

Create an upload keystore outside the repository, back it up, and configure Play App Signing in
Play Console. Supply these environment variables locally or as CI secrets:

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`: absolute path to the upload keystore
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`: alias
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`: key/store password (Godot requires them to match)

```sh
python tools/release/mobile.py android-aab
```

This installs Godot's matching Android Gradle template and builds
`exports/android/dust-in-space.aab`. The first Gradle run needs Internet access for its build
dependencies. Do not commit signing keys/passwords or generated Android build files. Upload
manually to an internal testing track after checking package ID, signing and version. Verify
16 KB native library page alignment and install behavior using Play's checks and a compatible
device/emulator before production.

## iOS: handoff to a Mac

On the Mac, install Xcode 26 or later with its iOS SDK, accept the license, install command-line
tools, and sign into the owner's Apple Developer team. Clone this branch and install matching
Godot export templates. Find the **10-character Team ID** in Apple Developer membership details.

```sh
python3 tools/release/mobile.py ios --ios-team-id ABC1234567
```

Replace the example with the real Team ID, or set `DUST_IOS_TEAM_ID`. The tool checks the OS and
Team ID before exporting. The `iOS` preset exports an Xcode project only, for iPhone and iPad,
with the same app ID/version/build as Android. Open
`exports/ios/dust_in_space.xcodeproj`. Godot writes the project and its resource folders beside
the configured `.ipa` path; the project-only export does not build an IPA.

In Xcode, select the app target, the correct Team, and automatic signing. Connect an iPhone and
run it; then use **Product > Archive > Distribute App > App Store Connect** for TestFlight.
Create the App Store Connect record with the matching bundle ID first. Share the project or
grant appropriate team access; do not share the owner's Apple password or signing certificates.

## Verification before sharing a build

- Fresh install: title, tutorial, first stage and saved settings work offline.
- Close/reopen: completed stages survive; active runs currently restart after process death.
- Play on a tall/notched phone: counters, pause/options and pack buttons stay usable. Safe-area
  handling still needs a separate device review; export setup alone does not prove it.
- Background/resume during a launch, payout and end sequence: no stuck input or unexpected audio.
- Sound, mute and vibration work; reduced motion remains usable.
- Release builds expose no debug shortcuts/trials and create no playtest logs or network uploads.
- Exercise chapters 1-6 and the current Aries stages. Purchase gating is still a later task.

Build-contract checks: `python -m unittest discover -s tools/release -p test_*.py`.
Export logs go to `output/release/`. Temporary test icons reuse the existing gold star and the
palette at integer scales; regenerate with `python tools/art/build_mobile_icons.py` (Pillow).
They still need final store-art approval.

## Local validation, 2026-10-27

- Godot 4.7 stable, Windows, Java 21 and Android SDK 36.
- Android Test APK exported and signature verified (v2/v3); manifest: min SDK 24, target SDK 36,
  ARM64, vibration permission, no Internet permission. APK size about 29 MB.
- `zipalign -c -P 16 4` passed; both native libraries have 16 KB PT_LOAD alignment.
- A release-mode Gradle AAB built with the existing **debug key solely for validation**;
  `jarsigner` verified it, with self-signed-certificate and JAR manifest-order warnings.
  It is `exports/android/dust-in-space-release-smoke.aab`, **not an upload artifact**.
- APK and release AAB runtime-data/exclusion checks passed. A release runtime started the
  exported resource pack headlessly for 60 frames without script/resource errors (the sandbox
  reported an unrelated Windows certificate-store access error).
- Six Python build-contract checks passed. The full GUT suite passed 1,575 tests before this
  build-configuration change; it was not rerun for this tooling-only work.
- No connected Android phone, Mac or Apple Team ID was available. Native iOS export, device
  behavior, Play upload signing and store acceptance remain unverified. Godot also reported
  a scan-thread/shutdown warning after the Gradle export.

References: [Godot Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html),
[Godot iOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html),
[Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/?id=02032026a).
