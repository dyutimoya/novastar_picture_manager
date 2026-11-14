# Novastar Picture Manager

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.13-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2?logo=dart)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Linux%20%7C%20Windows%20%7C%20macOS%20%7C%20Android%20%7C%20iOS%20%7C%20Web-brightgreen)](PLATFORM_COMPATIBILITY.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**A professional, open-source, cross-platform Microsoft Office Picture Manager alternative.**

*High-performance multi-image batch cropping, lossless/lossy processing, color adjustments, and desktop-grade image management.*

</div>

---

## 📌 Project Overview

**Novastar Picture Manager** is built to revive and modernize the beloved workflow of Microsoft Office Picture Manager. Designed for photographers, content creators, designers, and everyday users who need to organize, crop, adjust, resize, and convert hundreds of photos with speed, simplicity, and precision.

- **Package Identifier:** `com.novastar.picturemanager`
- **Application Binary:** `novastar_picture_manager`
- **Architecture:** Clean Architecture + Feature-Based Modular Architecture with Riverpod & Isolates.
- **Privacy First:** 100% offline, local-first image processing with zero telemetry and no cloud dependencies.

---

## ✨ Key Features

### 1. 🎯 Interactive Multi-Image Batch Cropping (Core Engine)
- **Batch & Individual Cropping**: Load dozens or hundreds of images and visually adjust the crop frame for **each image independently**, or apply unified dimensions across the entire set.
- **8-Point Responsive Crop Rect**: 4 corner handles + 4 edge midpoint handles with rule-of-thirds alignment grid.
- **Aspect Ratio Locking**:
  - `Freeform`
  - `Original Ratio`
  - `1:1 Square`
  - `4:3 Standard`
  - `3:2 Classic Photo`
  - `16:9 Widescreen`
  - `9:16 Story / Reel`
  - `5:4` / `4:5`
  - `Custom W × H` ratio inputs
- **Smart Crop & Focal Alignment**: One-click framing presets for Center, Top/Face-bias, and Bottom focal positioning.
- **Batch Framing Tools**: Apply common crop, center-crop all, copy/paste framing parameters between images.
- **Pre-Export Review Workspace**: Side-by-side inspection of original vs cropped previews, dimension validation, and warning indicators before committing exports.

### 2. 🎨 Studio-Grade Image Adjustments & Viewer
- **High-Resolution Interactive Viewer**: Pan, zoom up to 1000%, and inspect pixel-accurate high-resolution previews.
- **Fine Rotation & Straightening**: 90° Clockwise/Counter-clockwise flips, plus smooth continuous angle rotation with ±1° stepper buttons for precise alignment.
- **Color & Tone Adjustments**:
  - Brightness, Contrast, Saturation
  - Warmth / Temperature & Tint
  - Hue & Gamma
- **Batch Watermarking**: Configurable text watermark overlays with opacity and sizing controls.
- **One-Click Auto Correct**: Intelligent automatic histogram optimization.

### 3. ⚡ High-Throughput Batch Operations
- **Batch Resize**: Exact pixel dimensions, proportional percentage scaling (e.g. 50%, 200%), or fit-inside bounding boxes with presets for 4K UHD, Full HD, Instagram, and web thumbnails.
- **Batch Format Conversion**: Convert between `JPG`, `PNG`, `WebP`, `BMP`, and `TIFF` with configurable quality compression sliders.
- **Batch Renaming Engine**: Custom prefix/suffix, sequential counter padding (`#`, `##`, `###`), search & replace, and non-destructive overwrite guards.

### 4. 🖥️ OS Default Viewer & System Integration
- **Linux Integration**: One-click registration as the default system image viewer via XDG MIME database and desktop entry integration (`~/.local/share/applications/novastar-picture-manager.desktop`).
- **Windows Integration**: Generates ready-to-run Windows Registry (`.reg`) scripts registering `Novastar.PictureManager.Image` ProgID and file association handlers in Windows Explorer.
- **Double-Click Launch Support**: Directly opens individual files passed via command line arguments into the dedicated full-screen image viewer.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.13.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.0.0`)
- C/C++ build tools (for Desktop targets: `clang`/`gcc` on Linux, Visual Studio on Windows, Xcode on macOS)

### Installation & Run

```bash
# 1. Clone the repository
git clone https://github.com/novastar/novastar-picture-manager.git
cd novastar-picture-manager

# 2. Install dependencies
flutter pub get

# 3. Run on your platform of choice:
flutter run -d linux      # Linux Desktop
flutter run -d windows    # Windows Desktop
flutter run -d macos      # macOS Desktop
flutter run -d chrome     # Flutter Web
flutter run -d <device>   # Android / iOS device or emulator
```

### Running Automated Test Suite

```bash
# Run unit & widget tests
flutter test

# Run static code analysis
flutter analyze --no-fatal-infos
```

---

## 📦 Building Production Binaries

### Linux
```bash
flutter build linux --release
# Bundle output: build/linux/x64/release/bundle/
```

### Windows
```bash
flutter build windows --release
# Executable output: build/windows/x64/runner/Release/
```

### macOS
```bash
flutter build macos --release
# Application bundle: build/macos/Build/Products/Release/Novastar Picture Manager.app
```

### Web
```bash
flutter build web --release
# Output: build/web/ (CanvasKit, WASM, PWA manifest)
```

### Android
```bash
flutter build apk --release
# APK output: build/app/outputs/flutter-apk/app-release.apk
```

---

## ⌨️ Desktop Keyboard Shortcuts

| Shortcut | Description |
| :--- | :--- |
| `Ctrl + O` / `Cmd + O` | Open directory / folder |
| `Ctrl + A` / `Cmd + A` | Select all images |
| `C` | Launch Batch Crop on selected images |
| `R` | Rotate current image 90° clockwise |
| `Left Arrow` | Previous image in batch workspace |
| `Right Arrow` | Next image in batch workspace |
| `Ctrl + Z` / `Cmd + Z` | Undo crop / framing change |
| `Ctrl + Y` / `Cmd + Shift + Z` | Redo crop / framing change |
| `Delete` | Remove selected image |
| `Escape` | Exit fullscreen viewer / close dialog |

---

## 🏛️ Architecture & Project Structure

The project strictly follows **Clean Architecture** with a feature-based folder organization:

```
lib/
├── app/                  # Application root, routing (GoRouter), theme configuration
├── core/
│   ├── models/           # Domain entities (ImageItem, CropSettings, ImageAdjustments)
│   ├── services/         # Isolates image processing, smart crop heuristics, system integration
│   ├── state/            # Riverpod state notifiers & providers
│   └── theme/            # Obsidian dark theme and styling tokens
└── features/
    ├── browser/          # Folder navigation, thumbnail grid, filtering & sorting
    ├── batch_crop/       # Multi-image batch crop workspace, interactive canvas, review dialog
    ├── editing/          # High-resolution editor, adjustments sliders, fine rotation steppers
    ├── viewer/           # Dedicated image viewer screen with zoom & pan
    ├── batch_tools/      # Batch resize, convert, compress, and rename dialogs
    └── export/           # Safe export dialog with conflict resolution & progress tracking
```

For detailed architectural patterns, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## 🤝 Contributing & Community

We welcome contributions from the community! To keep the project robust, secure, and clean, our `master` / `main` branch is protected.

Please review our:
- 📖 [Contributing Guidelines](CONTRIBUTING.md)
- 🛡️ [Code of Conduct](CODE_OF_CONDUCT.md)
- 🔒 [Security Policy](SECURITY.md)

---

## 📄 License

Novastar Picture Manager is released under the [MIT License](LICENSE).
