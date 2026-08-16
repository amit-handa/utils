# Mobile profile

The **mobile** profile is optional and layers on top of [base](base.md). It points to the existing Android and iOS setup notes and may install mobile-toolchain prerequisites, but it **does not restore simulator or device state**.

## Included catalog IDs

From [`references/tool-catalog.tsv`](../references/tool-catalog.tsv), the mobile profile includes:

- **Android tooling:** `android` — command candidates `adb`, `gradlew`; app candidate Android Studio; config root `.android`.
- **Xcode and simulators:** `xcode` — command candidates `xcodebuild`, `simctl`; app candidate Xcode; config root `Library/Developer`.

## Existing notes (read these instead of duplicating)

The detailed workflows live in the vault already. This profile links to them:


## Platform prerequisites

- **macOS:** Xcode (from the App Store or `xcode-install`), Android Studio, and the Android SDK. `simctl` ships with Xcode; `adb` ships with the Android SDK platform-tools. See [macOS profile](macos.md).
- **Debian/Ubuntu:** Android SDK and `adb` are available via `apt`/SDK manager. There is no Xcode on Linux; iOS simulator work requires a Mac. See [Debian/Ubuntu profile](linux-debian.md).

## Manual authentication and licensing handoffs

- **Xcode:** sign in with your Apple ID in Xcode → Settings → Accounts; accept the Apple Developer license (`xcodebuild -license`). Provisioning profiles come from fastlane `match` (see the iOS note) and require a shared `MATCH_PASSWORD` — ask the team, never store it here.
- **Android Studio / SDK:** accept the Android SDK licenses (`sdkmanager --licenses`); sign in to Google services as your workflow requires.
- **Bazel (mobile builds):** mobile builds use Bazel; any remote-cache or signing credentials are project-scoped, not stored by this kit.

## What this profile does not restore

- No simulator state: no booted simulators, installed apps, simulator screenshots, or `~/Library/Developer/CoreSimulator/Devices` contents.
- No device state: no connected-device profiles, device screen recordings, or device-level keychain material.
- No provisioning profiles or signing identities from `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (the iOS note documents how to bootstrap them with `match`).
- No `MATCH_PASSWORD`, keystore passwords, or signing secrets.
- No `local.properties` files (they are git-ignored and machine-specific; the Android note explains the `ANDROID_HOME` fix).
- Nothing from [base](base.md)'s "does not restore" list is restored here either.

Private Android/iOS workflow notes remain in the private notes vault; see `../references/related-notes.md`.
