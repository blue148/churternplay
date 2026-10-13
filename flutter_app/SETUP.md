# Flutter Setup — Churtern Play

## 1. Install Flutter

```bash
brew install flutter
flutter doctor   # follow any instructions it gives you
```

## 2. Generate platform folders

Run this once from inside the `flutter_app/` directory:

```bash
flutter create . --org com.churtern_play --project-name churtern_play
```

This generates `ios/`, `android/`, and other platform folders without overwriting
any existing Dart files.

## 3. Install dependencies

```bash
flutter pub get
```

## 4. Camera permission strings (required for barcode scanner)

### iOS — ios/Runner/Info.plist
Add inside the `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>Churtern Play uses your camera to scan game barcodes.</string>
```

### Android — android/app/src/main/AndroidManifest.xml
Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## 5. Run the app

```bash
# iOS Simulator
flutter run -d "iPhone 16 Pro"

# Android Emulator (after creating one in Android Studio)
flutter run -d "Pixel 8"

# Both simultaneously
flutter run -d all
```

## 6. Hot reload

While the app is running, press `r` in the terminal for hot reload, or `R` for
a full restart. Changes to Dart files appear in < 1 second.

## 7. Build for App Store / Play Store

```bash
# iOS production build
flutter build ipa --release

# Android production build
flutter build appbundle --release
```

Submit iOS via Xcode or Transporter. Submit Android via the Play Console.

### Android release signing

Release builds are signed with the Play **upload key**, configured in
`android/key.properties` (gitignored):

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/<you>/keystores/churternplay-upload.jks
```

Without that file, release builds fall back to the debug key (fine for
`flutter run --release`; Play Console rejects debug-signed bundles). Keep the
keystore and its password backed up outside the repo. With Play App Signing
enabled, a lost upload key can be reset through Play Console support.

The Android application ID is `com.churternplay.churternPlay` (matches the iOS
bundle ID) and cannot change after the first Play upload.
