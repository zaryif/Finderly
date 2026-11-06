# 🛠️ Finderly Multi-Platform Packaging, Diagnostics & Resolution Guide

This document provides a root-cause breakdown and resolution guide for all target platforms: **macOS (DMG)**, **Windows (EXE & ZIP)**, **iOS (IPA)**, and **Android (APK)**.

---

## 📊 Platform Matrix & Status

| Platform | Artifact | Target Specs | Status | Distribution Format |
| :--- | :--- | :--- | :--- | :--- |
| **Android** | `finderly-android.apk` | Android 8.0+ (API 26–35) |  **Resolved & Verified** | Standalone APK |
| **macOS** | `finderly-macos.dmg` | macOS 12+ (Universal: x86_64 + arm64) |  **Resolved & Universal** | Drag-to-Applications DMG |
| **Windows** | `finderly-windows.zip` | Windows 10 & 11 (64-bit) |  **Resolved & Packaged** | Portable Self-Contained ZIP |
| **iOS** | `finderly-ios.ipa` | iOS 14.0+ |  **Ready for Sideload** | AltStore / Sideloadly IPA |

---

## 1. 🍏 macOS DMG Diagnosis & Fix

### Problem Statement
When opening `finderly-macos.dmg` or launching the installed `Finderly.app`, macOS displayed:
> *"Finderly is damaged and can't be opened. You should move it to the Trash."* or crashed silently on Intel Macs.

### Root Causes
1. **CPU Architecture Mismatch (`arm64` vs `x86_64`)**:
   - GitHub Actions `macos-latest` runners execute on Apple Silicon (`arm64`).
   - Building with default flags on GitHub produced an `arm64`-only Mach-O executable.
   - When opened on an **Intel Mac (`x86_64`)** (e.g. Intel Core i5/i7/i9), macOS cannot execute ARM64 instructions and throws `Bad CPU type in executable`.
2. **Gatekeeper Extended Quarantine Attributes**:
   - macOS automatically applies the `com.apple.quarantine` extended attribute to any DMG or app downloaded through a web browser.
   - For apps that are not notarized through an active Apple Developer Program account, Gatekeeper blocks execution with the *"damaged"* warning.

### Solution Implemented
1. **Universal 2 Binary**:
   - Built with dual architecture targeting: **Intel (`x86_64`) + Apple Silicon (`arm64`)**.
   - Verified binary Mach-O header:
     ```bash
     Mach-O universal binary with 2 architectures: [x86_64] [arm64]
     ```
2. **Ad-Hoc Signing & Clean Packaging**:
   - The `.app` bundle is signed ad-hoc (`codesign --force --deep --sign -`).
   - Packaged into a clean read-only compressed UDZO `.dmg` containing a direct symlink to `/Applications`.
3. **How to Run on macOS**:
   - **Method A (Right-Click Open)**: Right-click `Finderly.app` in Applications, hold **Option/Control**, and click **Open**. Click **Open** on the prompt.
   - **Method B (Terminal One-Liner)**:
     ```bash
     xattr -cr /Applications/Finderly.app
     ```

---

## 2. 🪟 Windows Diagnosis & Fix

### Problem Statement
When users download only `finderly-windows.exe` from GitHub Releases and double-click it, Windows throws an error:
> *"The code execution cannot proceed because flutter_windows.dll was not found. Reinstalling the program may fix this problem."*

### Root Cause
- Flutter Windows desktop apps are **not single-file monolithic executables**.
- `finderly.exe` dynamically loads:
  1. `flutter_windows.dll` (Flutter engine)
  2. `data/` directory (contains `icudtl.dat`, Flutter asset bundle, fonts)
  3. Plugin binaries (e.g. `sqlite3.dll`, `url_launcher_windows.dll`, etc.)
- Downloading `finderly.exe` in isolation strips all companion libraries and prevents the app from booting.

### Solution Implemented
- The **authoritative and complete distribution** for Windows is **`finderly-windows.zip`**.
- Users simply download `finderly-windows.zip`, extract it to any folder or Desktop, and launch `finderly.exe`.
- All DLLs and assets are bundled in the exact relative directory layout expected by the Flutter Windows runtime.

---

## 3. 📱 iOS IPA Diagnosis & Installation

### Problem Statement
Users cannot install an `.ipa` directly by double-clicking it on an iPhone or through standard file browsers without an enterprise distribution profile or App Store TestFlight.

### Root Cause
- Apple restricts iOS app installation strictly to:
  1. Official App Store / TestFlight
  2. Apple Developer provisioned devices
  3. Sideloading with free personal Apple ID credentials (re-signing)

### Solution Implemented
`finderly-ios.ipa` is built ready for personal device sideloading.
- **Option 1 (AltStore - Recommended)**:
  1. Install [AltStore](https://altstore.io/) on your Mac or PC.
  2. Connect your iPhone via USB / Wi-Fi sync.
  3. In AltStore on your phone, tap **+ (My Apps)** and select `finderly-ios.ipa`.
  4. AltStore re-signs the app with your Apple ID and installs it directly to your home screen!
- **Option 2 (Sideloadly)**:
  1. Open [Sideloadly](https://sideloadly.io/) on your Mac/PC.
  2. Drag and drop `finderly-ios.ipa`.
  3. Enter your Apple ID and click **Start**.

---

## 4. 🤖 Android APK Crash on Android 10 Diagnosis & Fix

### Problem Statement
The app crashed immediately upon launch on Android 10 (API 29).

### Root Causes
1. **Missing `MainActivity.kt`**:
   - The Kotlin source tree was missing the entry activity `com.example.finderly.MainActivity`.
2. **R8 Class Stripping**:
   - Android Gradle Plugin R8 minifier stripped and obfuscated classes into single-letter packages (`LA/a;`, etc.), deleting `io.flutter.embedding.android.FlutterActivity`.
3. **Storage Scoping Incompatibility**:
   - Incompatible `MANAGE_EXTERNAL_STORAGE` declaration crashed on Android 10 devices which mandate Scoped Storage or legacy external storage flags.

### Solutions Implemented
1. **Created `MainActivity.kt`**:
   ```kotlin
   package com.example.finderly
   import io.flutter.embedding.android.FlutterActivity
   class MainActivity: FlutterActivity()
   ```
2. **Configured `proguard-rules.pro`**:
   - Added explicit rules keeping `io.flutter.**`, `com.example.finderly.**`, `com.tekartik.sqflite.**`, and all Flutter plugins.
3. **Build Hardening**:
   - Enabled `multiDexEnabled true`.
   - Set `minifyEnabled false` and `shrinkResources false` in `build.gradle` for release stability.
   - Added `android:requestLegacyExternalStorage="true"` for seamless Android 10 media access.
4. **Verification**:
   - Inspected compiled `classes.dex` using DexParser to verify that `MainActivity`, `FlutterActivity`, and Flutter embedding symbols are present and unstripped.

