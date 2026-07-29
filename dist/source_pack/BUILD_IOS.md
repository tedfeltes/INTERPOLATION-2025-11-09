# Building StakeDXF for iOS

This guide covers a **ground-up** build of the Flutter app in `mobile/stakedxf`
on a Mac, from this source pack through a device install or IPA.

App version in this pack: **1.26.2** (`pubspec.yaml`).

---

## 1. What iOS can run today

StakeDXF’s Flutter UI (home rails **CONVERT / PLOT / BASE**) builds on iOS, but
native DWG recovery is **Android-only** right now:

| Home action | On iOS |
|---|---|
| **02 PLOT** | Supported — import points CSV/TXT + DXF linework, style layers, export staking PDF / CSV |
| **01 CONVERT** | UI present; on-device LibreDWG + Chaquopy recover is **not** linked for iOS |
| **03 BASE** | UI present; multi-DWG combine uses Android Python — **not** available on iOS |

Plan field Convert/Base on the TSC5 APK. Use the iPhone build for Plot, review,
and file share workflows.

---

## 2. Prerequisites (Mac)

Install all of the following before the first build:

1. **macOS** (Sonoma / Sequoia recommended)
2. **Xcode 15+** from the Mac App Store  
   - Open Xcode once → accept license  
   - Settings → Platforms → install an **iOS** SDK matching your device
3. **Xcode command-line tools**
   ```bash
   xcode-select --install
   sudo xcodebuild -license accept
   ```
4. **CocoaPods**
   ```bash
   sudo gem install cocoapods
   # or: brew install cocoapods
   pod --version
   ```
5. **Flutter stable 3.32.x** (Dart 3.8) — matches this project’s SDK constraint  
   ```bash
   git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
   export PATH="$HOME/flutter/bin:$PATH"
   flutter doctor
   ```
   Resolve anything `flutter doctor` flags for **Xcode** and **CocoaPods**.
6. **Apple ID / Developer Program**  
   - Free Apple ID: run on your own iPhone with a 7-day personal team profile  
   - Paid Apple Developer Program: Ad Hoc / TestFlight / App Store distribution

Bundle ID in the project: `com.stakedxf.stakedxf`  
Display name in `Info.plist`: **StakeDXF**

---

## 3. Unpack and first configure

```bash
# From the unzipped pack root (StakeDXF-source-v1.26.2/)
cd mobile/stakedxf

flutter pub get
```

Generated iOS files (`Pods/`, `Podfile.lock`, `Flutter/Generated.xcconfig`,
plugin registrants) are **not** in the zip — Flutter recreates them:

```bash
# Creates Podfile if missing, installs pods, prepares Xcode workspace
flutter precache --ios
flutter build ios --config-only
cd ios && pod install && cd ..
```

Always open the **workspace**, not the bare project:

```bash
open ios/Runner.xcworkspace
```

---

## 4. Signing in Xcode

1. Open `ios/Runner.xcworkspace`
2. Select the **Runner** target → **Signing & Capabilities**
3. Check **Automatically manage signing**
4. Choose your **Team**
5. If the bundle ID `com.stakedxf.stakedxf` is taken on your account, change it to
   something unique (e.g. `com.yourcompany.stakedxf`) in:
   - Xcode → Runner target → Signing → Bundle Identifier  
   - Keep the Flutter side in sync if you also change Android `applicationId`
     (not required for an iOS-only build)

Connect an iPhone with a cable (or use a simulator for UI-only smoke tests).

Trust the developer certificate on the device the first time:  
**Settings → General → VPN & Device Management**.

---

## 5. Privacy keys (`Info.plist`)

This pack’s `ios/Runner/Info.plist` already includes usage strings needed for
file picking / sharing on device. If you regenerate the iOS folder with
`flutter create`, re-add at least:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>StakeDXF needs photo library access when you attach images or export plots.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>StakeDXF may save exported plots to your photo library when you choose Save Image.</string>
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>UISupportsDocumentBrowser</key>
<true/>
```

Without these, `file_picker` / share sheets can crash or be rejected at App Store review.

---

## 6. Run on simulator or device

```bash
cd mobile/stakedxf

# List devices / simulators
flutter devices

# Simulator (Plot UI smoke test)
flutter run -d "iPhone 16"

# Physical device (replace with your device id from `flutter devices`)
flutter run -d <device-id> --release
```

Or press **Run** in Xcode with the Runner scheme.

---

## 7. Build an IPA (distribution)

### Development / Ad Hoc (Xcode Archive)

1. In Xcode: Product → **Destination** → **Any iOS Device (arm64)**
2. Product → **Archive**
3. Organizer → **Distribute App**
   - **Ad Hoc** — install on registered devices  
   - **Development** — debug installs  
   - **App Store Connect** — TestFlight / App Store

### CLI (Flutter)

```bash
cd mobile/stakedxf

# Requires signing set up in Xcode first
flutter build ipa --release

# Output (typical):
# build/ios/ipa/*.ipa
```

For App Store Connect upload you can also use:

```bash
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey <KEY> --apiIssuer <ISSUER>
# or Transporter.app / Xcode Organizer
```

---

## 8. Version numbers

Flutter maps `pubspec.yaml` → iOS:

```yaml
version: 1.26.2+34
#         │       └─ CFBundleVersion (build)
#         └─ CFBundleShortVersionString (marketing)
```

Bump `version:` before shipping a new IPA. Keep Android and iOS marketing
versions aligned when you release both.

---

## 9. Common failures

| Symptom | Fix |
|---|---|
| `No Podfile` / CocoaPods errors | `cd ios && pod install` after `flutter pub get` |
| `Signing for Runner requires a development team` | Set Team under Signing & Capabilities |
| Device “Untrusted Developer” | Settings → General → VPN & Device Management → Trust |
| `file_picker` crash on pick | Confirm privacy keys in `Info.plist` (section 5) |
| CONVERT / BASE errors on iOS | Expected — use Android APK for DWG recover / combine |
| Wrong Flutter version / Dart SDK | Install Flutter 3.32.x stable; `flutter --version` |
| `Generated.xcconfig` missing | Run `flutter pub get` then `flutter build ios --config-only` |

---

## 10. Optional: keep Android CONVERT working on iOS later

Not included in this pack’s iOS target. A future iOS Convert path would need
something like:

- Static LibreDWG (or equivalent) linked into the Runner target + Dart FFI, and  
- A non-Chaquopy recover implementation (Dart or embedded Python/WASM),

plus MethodChannel parity with Android `MainActivity` / `linework.py`.

Until then, ship Plot on iOS and Convert/Base on the TSC5 APK from
`BUILD_ANDROID.md`.
