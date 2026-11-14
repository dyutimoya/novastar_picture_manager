import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class SystemIntegrationService {
  static const supportedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/bmp',
    'image/tiff',
    'image/gif',
    'image/x-icon',
  ];

  static const supportedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff', 'tif', 'gif'];

  /// Check if Novastar Picture Manager is currently set as the default viewer on Linux
  static Future<bool> isLinuxDefaultViewer() async {
    if (!Platform.isLinux) return false;
    try {
      final result = await Process.run('xdg-mime', ['query', 'default', 'image/jpeg']);
      if (result.exitCode == 0) {
        final out = result.stdout.toString().trim();
        return out.contains('novastar-picture-manager') ||
            out.contains('picture-manager-pro') ||
            out.contains('img_tool');
      }
    } catch (e) {
      debugPrint('Error querying default mime: $e');
    }
    return false;
  }

  /// Register Novastar Picture Manager as default image viewer on Linux
  static Future<bool> setLinuxAsDefaultViewer() async {
    if (!Platform.isLinux) return false;
    try {
      final exePath = Platform.resolvedExecutable;
      final homeDir = Platform.environment['HOME'] ?? '';
      if (homeDir.isEmpty) return false;

      final appsDir = Directory(p.join(homeDir, '.local', 'share', 'applications'));
      if (!appsDir.existsSync()) {
        appsDir.createSync(recursive: true);
      }

      final iconsDir = Directory(p.join(homeDir, '.local', 'share', 'icons', 'hicolor', '256x256', 'apps'));
      if (!iconsDir.existsSync()) {
        iconsDir.createSync(recursive: true);
      }
      final iconTarget = p.join(iconsDir.path, 'novastar-picture-manager.png');
      final legacyIconTarget = p.join(iconsDir.path, 'picture-manager-pro.png');
      final bundledIcon = p.join(p.dirname(exePath), 'data', 'flutter_assets', 'assets', 'icon', 'app_icon.png');
      if (File(bundledIcon).existsSync()) {
        try {
          await File(bundledIcon).copy(iconTarget);
          await File(bundledIcon).copy(legacyIconTarget);
        } catch (_) {}
      } else if (File('assets/icon/app_icon.png').existsSync()) {
        try {
          await File('assets/icon/app_icon.png').copy(iconTarget);
          await File('assets/icon/app_icon.png').copy(legacyIconTarget);
        } catch (_) {}
      }

      final desktopFilePath = p.join(appsDir.path, 'novastar-picture-manager.desktop');
      final mimeString = supportedMimeTypes.join(';');

      final desktopContent =
          '''[Desktop Entry]
Name=Novastar Picture Manager
Comment=Modern Cross-Platform Image Viewer and Batch Editor
Exec=$exePath %F
Icon=novastar-picture-manager
Terminal=false
Type=Application
Categories=Graphics;Photography;Viewer;2DGraphics;RasterGraphics;
MimeType=$mimeString;
StartupNotify=true
''';

      final desktopFile = File(desktopFilePath);
      await desktopFile.writeAsString(desktopContent);

      // Make executable
      await Process.run('chmod', ['+x', desktopFilePath]);

      // Update desktop database
      try {
        await Process.run('update-desktop-database', [appsDir.path]);
      } catch (_) {}

      // Set default for all mime types
      for (final mime in supportedMimeTypes) {
        await Process.run('xdg-mime', ['default', 'novastar-picture-manager.desktop', mime]);
      }

      return true;
    } catch (e) {
      debugPrint('Error setting Linux default viewer: $e');
      return false;
    }
  }

  /// Generate Windows Registry (.reg) file content to associate image types with Novastar Picture Manager
  static String generateWindowsRegContent() {
    final exePath = Platform.resolvedExecutable.replaceAll(r'\', r'\\');

    final buffer = StringBuffer();
    buffer.writeln('Windows Registry Editor Version 5.00\n');
    buffer.writeln('; Novastar Picture Manager File Associations\n');

    // ProgID definition
    buffer.writeln(r'[HKEY_CURRENT_USER\Software\Classes\Novastar.PictureManager.Image]');
    buffer.writeln('@="Novastar Picture Manager Image"');
    buffer.writeln(r'[HKEY_CURRENT_USER\Software\Classes\Novastar.PictureManager.Image\DefaultIcon]');
    buffer.writeln('@="$exePath,0"');
    buffer.writeln(r'[HKEY_CURRENT_USER\Software\Classes\Novastar.PictureManager.Image\shell\open\command]');
    buffer.writeln('@="\\"$exePath\\" \\"%1\\""\n');

    // Extensions
    for (final ext in supportedExtensions) {
      buffer.writeln('[HKEY_CURRENT_USER\\Software\\Classes\\.$ext]');
      buffer.writeln('@="Novastar.PictureManager.Image"');
      buffer.writeln('[HKEY_CURRENT_USER\\Software\\Classes\\.$ext\\OpenWithProgids]');
      buffer.writeln('"Novastar.PictureManager.Image"=""\n');
    }

    return buffer.toString();
  }

  /// Open OS Default Apps system settings panel
  static Future<void> openSystemDefaultAppsSettings() async {
    if (kIsWeb) return;
    try {
      if (Platform.isWindows) {
        await Process.run('cmd.exe', ['/c', 'start', 'ms-settings:defaultapps']);
      } else if (Platform.isLinux) {
        // Try gnome-control-center or xdg-open
        try {
          await Process.run('gnome-control-center', ['default-apps']);
        } catch (_) {
          await Process.run('xdg-open', ['settings://default-apps']);
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['x-apple.systempreferences:']);
      }
    } catch (e) {
      debugPrint('Error opening system settings: $e');
    }
  }

  /// Save Windows registration .reg file to local directory
  static Future<String?> exportWindowsRegFile(String directoryPath) async {
    try {
      final regContent = generateWindowsRegContent();
      final targetPath = p.join(directoryPath, 'Register_PictureManagerPro_DefaultViewer.reg');
      final file = File(targetPath);
      await file.writeAsString(regContent);
      return targetPath;
    } catch (e) {
      debugPrint('Error exporting .reg file: $e');
      return null;
    }
  }
}
