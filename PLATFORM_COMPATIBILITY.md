# Novastar Picture Manager: Platform Compatibility Guide

**Novastar Picture Manager** (`com.novastar.picturemanager`) is designed from the ground up for cross-platform image browsing, batch editing, and interactive batch cropping.

## Platform Support Matrix

| Platform | Support Tier | Package ID / Executable | File System Access | Image Processing Engine | Packaging Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Linux** | Tier 1 (Native) | `com.novastar.picturemanager` / `novastar_picture_manager` | Native file system, `xdg-mime`, `.desktop` | Background Dart Isolates | Standalone Bundle, AppImage, DEB, Flatpak |
| **Windows** | Tier 1 (Native) | `Novastar.PictureManager.Image` / `novastar_picture_manager.exe` | Native Win32 / Explorer ProgID Registry | Background Dart Isolates | MSIX, Inno Setup, Portable EXE |
| **macOS** | Tier 1 (Native) | `com.novastar.picturemanager` / `Novastar Picture Manager.app` | Native Cocoa / Finder | Background Dart Isolates | DMG, Signed App Bundle |
| **Web** | Tier 1 (Browser) | Web PWA (`web/manifest.json`) | In-Memory / Blob / Drag-Drop | Pure Dart / WebAssembly (CanvasKit) | HTML5 / WASM / Client-side ZIP Export |
| **Android** | Tier 2 (Mobile) | `com.novastar.picturemanager` (Gradle) | SAF (Storage Access Framework) | Background Isolates | APK, AAB |
| **iOS** | Tier 2 (Mobile) | `com.novastar.picturemanager` (Runner) | Photo Library / Files App | Background Isolates | IPA |

---

## Architecture & Cross-Platform Abstractions

1. **Pure Dart / Isolate Image Processing**:
   - Uses the pure-Dart `image` engine executed via `compute()`.
   - Eliminates platform-specific C++ binary compilation hassles across differing OS versions.
   - Guaranteed identical pixel calculations across Linux, Windows, macOS, Android, iOS, and Web.

2. **Resolution Independence**:
   - All crop coordinates are stored as `NormalizedRect` with values between `0.0` and `1.0`.
   - Crop framing presets apply seamlessly across images of differing dimensions and aspect ratios.

3. **Offline & Privacy-First**:
   - Zero telemetry or network requests.
   - 100% of processing happens on the user's device.
   - On Web, image processing executes client-side inside the browser sandbox with optional multi-image ZIP archive download.
