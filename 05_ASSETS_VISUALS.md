# 🎨 Finderly — Asset & Visual Specification

## 1. Folder Icon Design

The folder icon replicates the **macOS Big Sur folder shape** — a rounded rectangle with a tab on the upper-left. Each color variant is a separate PNG asset rendered at 3 densities.

### Folder Shape Reference
```
    ┌──────┐
    │  tab │
┌───┘      └──────────────┐
│                          │
│     macOS-style folder   │
│     with rounded edges   │
│                          │
└──────────────────────────┘
```

### Asset Files Required

| Asset | Sizes | Format |
|-------|-------|--------|
| `folder_blue.png` | 64, 128, 256px | PNG with transparency |
| `folder_purple.png` | 64, 128, 256px | PNG with transparency |
| `folder_pink.png` | 64, 128, 256px | PNG with transparency |
| `folder_red.png` | 64, 128, 256px | PNG with transparency |
| `folder_orange.png` | 64, 128, 256px | PNG with transparency |
| `folder_yellow.png` | 64, 128, 256px | PNG with transparency |
| `folder_green.png` | 64, 128, 256px | PNG with transparency |
| `folder_gray.png` | 64, 128, 256px | PNG with transparency |

> [!IMPORTANT]
> Since we can't ship real macOS folder PNGs (Apple copyright), we'll **paint the folder shape in code** using `CustomPainter` — a rounded folder body + tab, filled with the selected color and subtle gradients. This looks identical across all platforms and avoids copyright issues.

## 2. Color Palette

### Folder Colors
| Swatch | Name | Primary | Shadow | Highlight |
|--------|------|---------|--------|-----------|
| 🔵 | Blue | `#4A9EF5` | `#3A7EC5` | `#6AB4FF` |
| 🟣 | Purple | `#9B59B6` | `#7D4792` | `#B574D0` |
| 🩷 | Pink | `#E84393` | `#C03578` | `#F06BAF` |
| 🔴 | Red | `#E74C3C` | `#C0392B` | `#F07060` |
| 🟠 | Orange | `#F39C12` | `#D4850F` | `#F5B041` |
| 🟡 | Yellow | `#F1C40F` | `#D4AC0D` | `#F4D03F` |
| 🟢 | Green | `#2ECC71` | `#27AE60` | `#58D68D` |
| ⚫ | Gray | `#95A5A6` | `#7F8C8D` | `#AEB6B7` |

### App Theme Colors
| Element | Light | Dark |
|---------|-------|------|
| Background | `#F5F5F7` | `#1C1C1E` |
| Surface | `#FFFFFF` | `#2C2C2E` |
| Text Primary | `#1D1D1F` | `#F5F5F7` |
| Text Secondary | `#86868B` | `#A1A1A6` |
| Accent | `#007AFF` | `#0A84FF` |
| Divider | `#E5E5EA` | `#38383A` |

## 3. File Type Icons

| File Type | Icon | Color |
|-----------|------|-------|
| PDF | 📄 | `#E74C3C` |
| Image (jpg/png) | 🖼️ | `#3498DB` |
| Video (mp4/mov) | 🎬 | `#9B59B6` |
| Document (doc/txt) | 📝 | `#2ECC71` |
| Spreadsheet (xls) | 📊 | `#27AE60` |
| Archive (zip/rar) | 📦 | `#F39C12` |
| Other | 📎 | `#95A5A6` |

> [!TIP]
> File type icons will use Flutter's built-in `Icons` class with colored containers — no extra assets needed.

## 4. Screen Layouts

### Home Screen (Folder Grid)
```
┌─────────────────────────────────┐
│ 🔍 Search...              [+]  │  ← AppBar
├─────────────────────────────────┤
│                                 │
│  ┌─────┐  ┌─────┐  ┌─────┐    │
│  │ 📁  │  │ 📁  │  │ 📁  │    │  ← Grid of
│  │Blue │  │Pink │  │Green│    │     colored
│  └─────┘  └─────┘  └─────┘    │     folders
│                                 │
│  ┌─────┐  ┌─────┐  ┌─────┐    │
│  │ 📁  │  │ 📁  │  │  +  │    │
│  │Red  │  │Gray │  │ New │    │
│  └─────┘  └─────┘  └─────┘    │
│                                 │
└─────────────────────────────────┘
```

### Folder Detail Screen (File List)
```
┌─────────────────────────────────┐
│ ← Back    Folder Name    [⋮]   │  ← AppBar
├─────────────────────────────────┤
│                                 │
│  ┌──┐ Report.pdf    2.3 MB  ⬇  │
│  ├──┤───────────────────────────│
│  ┌──┐ Photo.jpg     1.1 MB  ✅ │  ← ✅ = offline
│  ├──┤───────────────────────────│
│  ┌──┐ Notes.txt     12 KB   ⬇  │  ← ⬇ = download
│  ├──┤───────────────────────────│
│  ┌──┐ Video.mp4     45 MB   ⬇  │
│  └──┘───────────────────────────│
│                                 │
│              [+ Add File]       │
└─────────────────────────────────┘
```

### Color Picker Dialog
```
┌──────────────────────────┐
│    Choose Folder Color   │
│                          │
│   🔵  🟣  🩷  🔴        │
│   🟠  🟡  🟢  ⚫        │
│                          │
│  [Cancel]      [Apply]   │
└──────────────────────────┘
```

## 5. Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| App title | SF Pro / System | 20sp | Bold |
| Folder name | SF Pro / System | 14sp | Medium |
| File name | SF Pro / System | 16sp | Regular |
| File meta | SF Pro / System | 12sp | Regular |
| Button | SF Pro / System | 14sp | Semibold |

> Uses system font on each platform for native feel.

## 6. Spacing & Layout

| Element | Value |
|---------|-------|
| Grid columns | 3 (phone), 4 (tablet), 5 (desktop) |
| Folder card padding | 12px |
| Grid spacing | 16px |
| Card border radius | 12px |
| AppBar height | 56px (mobile), 48px (desktop) |
