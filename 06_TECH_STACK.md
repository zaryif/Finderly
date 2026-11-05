# 🔧 Finderly — Tech Stack Decision

## 1. Why Flutter + Dart?

| Criteria | Flutter | React Native | Kotlin MM | .NET MAUI |
|----------|---------|-------------|-----------|-----------|
| Android ✅ | ✅ | ✅ | ✅ | ✅ |
| iOS ✅ | ✅ | ✅ | ✅ | ✅ |
| Windows ✅ | ✅ | ❌ | ❌ | ✅ |
| macOS ✅ | ✅ | ✅* | ✅* | ✅ |
| Pixel-perfect UI | ✅ Custom painting | ❌ Native widgets | ❌ | ❌ |
| Single codebase | ✅ 100% shared | ~90% | ~70% | ~85% |
| Desktop maturity | ✅ Stable | ⚠️ | ⚠️ | ⚠️ |
| Offline-first | ✅ sqflite/Hive | ✅ | ✅ | ✅ |

**Winner: Flutter** — only framework where the folder icon `CustomPainter` renders identically on all 4 platforms with zero platform-specific code.

## 2. Recommended Dart Version

> [!IMPORTANT]
> **Dart 3.6+ (ships with Flutter 3.29+)**

### Why Dart 3.6?
- **Null safety** — no null crashes
- **Pattern matching** — cleaner file type handling
- **Records** — lightweight data passing
- **Sealed classes** — exhaustive state handling
- **Extension types** — zero-cost wrappers for IDs

## 3. Essential Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1 | State management |
| `sqflite` | ^2.3 | Local SQLite database |
| `path_provider` | ^2.1 | Platform-specific file paths |
| `file_picker` | ^8.0 | Import files from device |
| `uuid` | ^4.4 | Unique IDs for folders/files |
| `open_file` | ^3.5 | Open files with system viewer |
| `share_plus` | ^9.0 | Share files |
| `mime` | ^2.0 | Detect file MIME types |
| `intl` | ^0.19 | Date formatting |
| `flutter_slidable` | ^3.1 | Swipe-to-delete on file list |

### Future (Phase 3-4)
| Package | Version | Purpose |
|---------|---------|---------|
| `firebase_core` | ^3.0 | Firebase initialization |
| `firebase_auth` | ^5.0 | Authentication |
| `cloud_firestore` | ^5.0 | Cloud database sync |
| `firebase_storage` | ^12.0 | Cloud file storage |
| `connectivity_plus` | ^6.0 | Online/offline detection |

## 4. Development Tools

| Tool | Purpose |
|------|---------|
| VS Code + Flutter extension | IDE |
| Flutter DevTools | Debugging |
| GitHub Actions | CI/CD |
| Codemagic | Mobile builds |

## 5. Minimum Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| Android | API 21 (Android 5.0) |
| iOS | iOS 14.0 |
| Windows | Windows 10 (64-bit) |
| macOS | macOS 11 (Big Sur) |

## 6. What We're NOT Using (and Why)

| Skipped | Why |
|---------|-----|
| BLoC | Over-engineered for this scope; Provider is enough |
| Riverpod | More boilerplate than Provider for no gain here |
| GetX | Magic globals, hard to debug |
| Hive/Isar | sqflite gives SQL search which we need |
| Supabase | Firebase has better Flutter support + free tier |
| Realm | Overkill, vendor lock-in |
