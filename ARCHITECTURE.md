# Novastar Picture Manager Architecture Guide

This document describes the architectural philosophy, system components, state flow, and cross-platform native abstractions of **Novastar Picture Manager**.

---

## 🏛️ Architectural Principles

1. **Clean Architecture & Feature-First**: Separation of presentation, business logic, domain models, and platform services.
2. **Local-First & Privacy-Focused**: All file operations, decoding, filtering, and writing occur directly on the client machine without external API dependencies.
3. **Non-Blocking UI (Isolate Offloading)**: All CPU-intensive raster image operations (decoding, bicubic scaling, convolution, format encoding) run in Dart background `Isolate`s to ensure a consistent 60/120 FPS UI loop.
4. **Desktop-First Ergonomics**: Designed from the ground up for desktop mouse, keyboard navigation, and file system interactions, while remaining compatible with mobile touch gestures and web sandboxes.

---

## 📂 Codebase Directory Layout

```
lib/
├── app/
│   ├── app.dart              # MaterialApp.router configuration, AppTheme
│   └── routes.dart           # GoRouter route declarations & navigation paths
│
├── core/
│   ├── models/               # Pure domain models (ImageItem, CropSettings, ImageAdjustments, BatchOperations)
│   ├── services/             # Platform services, Isolates processing, Smart Crop, OS integration
│   │   ├── image_processor.dart       # Heavy background isolate execution (crop, resize, filter, encode)
│   │   ├── smart_crop_service.dart    # Focal point calculation & normalized bounds clamping
│   │   └── system_integration_service.dart # Linux XDG / desktop file & Windows Registry generation
│   ├── state/                # Riverpod StateNotifiers and Providers
│   │   ├── image_browser_provider.dart  # Folder navigation, image sorting, multi-selection
│   │   ├── batch_crop_provider.dart     # Multi-image independent crop states, presets, undo/redo
│   │   ├── image_editor_provider.dart   # Color adjustments, fine rotation steppers, filters
│   │   └── export_provider.dart         # Export pipeline orchestration, conflict resolution
│   └── theme/
│       └── app_theme.dart    # Obsidian dark palette, custom styling tokens
│
└── features/
    ├── browser/              # Folder tree, image grid, status bar, toolbar
    │   └── widgets/          # Default viewer dialog, thumbnail cards, sort popups
    ├── batch_crop/           # The primary batch crop workspace
    │   └── widgets/          # Interactive 8-point crop canvas, review dialog, preset selector
    ├── editing/              # High-resolution image editor with live zoom & pan
    ├── viewer/               # Clean, minimalist standalone image viewer screen
    ├── batch_tools/          # Resize, convert, compress, and rename dialog modals
    └── export/               # Safe export dialog with conflict checks & ZIP compression
```

---

## 🔄 State Management Architecture (Riverpod)

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   (BrowserScreen, BatchCropScreen, EditorScreen, etc.) │
└──────────────────────▲─────────────────────────────────┘
                       │ Watches / Dispatches Actions
┌──────────────────────┴─────────────────────────────────┐
│               Riverpod StateNotifier Layer             │
│   • ImageBrowserNotifier  • BatchCropNotifier          │
│   • ImageEditorNotifier   • ExportNotifier             │
└──────────────────────▲─────────────────────────────────┘
                       │ Calls async services
┌──────────────────────┴─────────────────────────────────┐
│                   Core Service Layer                   │
│   • ImageProcessor (Dart Isolates / compute)           │
│   • SmartCropService (Normalized rect geometry)        │
│   • SystemIntegrationService (XDG mime / Registry)     │
└────────────────────────────────────────────────────────┘
```

### Key Providers:
- **`imageBrowserProvider`**: Manages the currently scanned directory, loaded `ImageItem` list, search query, active format filters, and multi-selection set.
- **`batchCropProvider`**: Stores individual `CropSettings` for every image in the batch. Maintains an undo/redo stack of actions so users can revert adjustments per image.
- **`imageEditorProvider`**: Holds live adjustment parameters (`ImageAdjustments`: brightness, contrast, saturation, fine rotation angle, horizontal/vertical flips, watermark).
- **`exportProvider`**: Orchestrates exporting hundreds of images sequentially or concurrently, calculating progress percentages, elapsed time, and conflict resolution (Overwrite vs. Auto-Rename).

---

## ⚡ Background Isolate Processing Pipeline

Flutter's UI thread must never freeze while resizing or encoding high-resolution 24MP+ images. All heavy tasks use Dart's `compute()` or `Isolate.run()`:

```
[UI Thread]
   │
   ├─► Dispatches BatchJob(imageBytes, cropRect, resizeSpec, adjustments)
   │
   ▼
[Background Worker Isolate]
   │
   ├─ 1. Decode Raw Image Bytes (JPEG / PNG / WebP / BMP / TIFF)
   ├─ 2. Apply Spatial Transforms (Normalized Crop Rect -> Pixel Rect)
   ├─ 3. Apply Rotation (90° steps + fine angle continuous interpolation)
   ├─ 4. Apply Color Adjustments (Brightness, Contrast, Saturation, Warmth, Hue)
   ├─ 5. Apply Resize Algorithm (Bicubic / Bilinear proportional scaling)
   ├─ 6. Apply Text Watermark Overlay
   ├─ 7. Encode Target Format (JPG with quality, PNG compressed, WebP lossy/lossless)
   │
   ▼
[Return Result] ──► UI Thread updates preview or writes output file safely
```

---

## 🖥️ Cross-Platform Native Integrations

### Linux (XDG & Desktop Integration)
- Implemented in [`lib/core/services/system_integration_service.dart`](file:///home/dyutimoya/Desktop/img_tool/lib/core/services/system_integration_service.dart).
- Writes desktop entry to `~/.local/share/applications/novastar-picture-manager.desktop`.
- Installs 256x256 application icon to `~/.local/share/icons/hicolor/256x256/apps/novastar-picture-manager.png`.
- Associates MIME types (`image/jpeg`, `image/png`, `image/webp`, `image/bmp`, `image/tiff`, `image/gif`) using `xdg-mime default`.

### Windows (ProgID & Registry Association)
- Automatically outputs a Windows Registry (`.reg`) script.
- Configures `HKEY_CURRENT_USER\Software\Classes\Novastar.PictureManager.Image` ProgID.
- Associates file extensions (`.jpg`, `.png`, `.webp`, etc.) in `OpenWithProgids`.
- Configures command line arguments (`"%1"`) so double-clicking an image opens it in the standalone viewer screen.

### Web (Flutter WebAssembly & CanvasKit)
- Browser sandbox file handling via `FileReader` and memory byte streams.
- Direct client-side ZIP packaging via `archive` package without server roundtrips.

---

## 🧪 Testing Strategy

1. **Geometry & Crop Math**: Verify normalized bounding boxes remain strictly clamped in `[0.0, 1.0]` across arbitrary image dimensions and rotations.
2. **Naming & File Safety**: Test collision avoidance so existing user files are never silently overwritten.
3. **State Integrity**: Verify independent crop maps retain individual image coordinates during batch operations.
4. **Widget Smoke Tests**: Verify app boots smoothly with GoRouter and Riverpod `ProviderScope`.
