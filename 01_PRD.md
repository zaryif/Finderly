# 📋 Finderly — Product Requirements Document (PRD)

## 1. Product Overview

**Finderly** is a cross-platform file organizer app that lets users create, color-code, and manage folders that look identical to macOS Finder folders — across Android, iOS, Windows, and macOS. Files of any type can be stored, organized, searched, synced across devices, and downloaded for offline use.

## 2. Core Features

### 2.1 Folder Management
| Feature | Description |
|---------|-------------|
| Create folder | Tap "+" to create a new folder with a default name |
| Rename folder | Long-press or right-click → Rename |
| Delete folder | Long-press or right-click → Delete (with confirmation) |
| Nested folders | Unlimited depth nesting |
| Color tagging | 7 macOS-style folder colors (see §5) |
| Folder icon | Pixel-perfect macOS Big Sur folder shape |

### 2.2 File Management
| Feature | Description |
|---------|-------------|
| Add files | Import any file type (PDF, DOCX, images, videos, etc.) |
| Rename files | Inline rename |
| Delete files | With confirmation dialog |
| Move files | Drag-and-drop or cut/paste between folders |
| File preview | Thumbnail preview for images/PDFs; icon for others |
| File info | Size, date added, type |

### 2.3 Search
| Feature | Description |
|---------|-------------|
| Global search | Search by file name or folder name |
| Filter | By file type, date, size |
| Instant results | Debounced search, < 200ms response |

### 2.4 Multi-Device Sync
| Feature | Description |
|---------|-------------|
| Cloud sync | Real-time sync across all devices |
| Conflict resolution | Last-write-wins with user notification |
| Auth | Email/password + Google Sign-In |

### 2.5 Offline & Download
| Feature | Description |
|---------|-------------|
| Download button | Per-file and per-folder download for offline |
| Offline indicator | Badge showing "Available Offline" |
| Auto-sync on reconnect | Queue changes, push when online |

## 3. Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Startup time | < 2s cold start |
| Max file size | 500 MB per file |
| Offline storage | Device storage limit |
| Platforms | Android 8+, iOS 14+, Windows 10+, macOS 11+ |
| Accessibility | WCAG 2.1 AA |

## 4. User Stories

1. **As a user**, I can create a folder and assign it a color so I can visually organize my files.
2. **As a user**, I can import any file into a folder so everything is in one place.
3. **As a user**, I can search across all folders and files to find things fast.
4. **As a user**, I can download a folder for offline use so I have access without internet.
5. **As a user**, I can sign in on any device and see the same folders and files.

## 5. Folder Color Palette (macOS-style)

| Color | Hex | Use |
|-------|-----|-----|
| Blue (default) | `#4A9EF5` | Default folder color |
| Purple | `#9B59B6` | Personal |
| Pink | `#E84393` | Creative |
| Red | `#E74C3C` | Urgent |
| Orange | `#F39C12` | Work |
| Yellow | `#F1C40F` | Archive |
| Green | `#2ECC71` | Completed |
| Gray | `#95A5A6` | Inactive |

## 6. Out of Scope (v1)
- File editing inside app
- Sharing/collaboration
- File versioning
- Encryption at rest
