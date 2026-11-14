import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/image_item.dart';
import 'image_processor.dart';

class FileService {
  static const supportedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff', 'tif', 'gif'};

  static const _uuid = Uuid();

  /// Pick one or multiple image files
  static Future<List<ImageItem>> pickImages() async {
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions.toList(),
      );

      if (pickedFiles.isEmpty) return [];

      final items = <ImageItem>[];
      for (final file in pickedFiles) {
        final item = await _createItemFromPlatformFile(file);
        if (item != null) items.add(item);
      }
      return items;
    } catch (e) {
      debugPrint('Error picking images: $e');
      return [];
    }
  }

  /// Pick a directory and scan for image files
  static Future<List<ImageItem>> pickFolder() async {
    if (kIsWeb) return []; // Web doesn't support direct path directory pick

    try {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath == null || dirPath.isEmpty) return [];

      return await scanDirectory(dirPath);
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return [];
    }
  }

  /// Scan directory for images
  static Future<List<ImageItem>> scanDirectory(String dirPath, {bool recursive = false}) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final items = <ImageItem>[];
    try {
      final entities = dir.listSync(recursive: recursive, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase().replaceFirst('.', '');
          if (supportedExtensions.contains(ext)) {
            final item = await loadItemFromFile(entity.path);
            if (item != null) items.add(item);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning directory $dirPath: $e');
    }
    return items;
  }

  /// Load an ImageItem from a file path
  static Future<ImageItem?> loadItemFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
      final name = p.basename(filePath);

      // Read initial bytes for thumbnail generation
      final bytes = await file.readAsBytes();
      final thumbResult = await ImageProcessor.extractInfoAndThumbnail(bytes);

      return ImageItem(
        id: _uuid.v4(),
        path: filePath,
        name: name,
        extension: ext,
        fileSizeBytes: stat.size,
        width: thumbResult?.width ?? 0,
        height: thumbResult?.height ?? 0,
        dateModified: stat.modified,
        thumbnailBytes: thumbResult?.thumbnailBytes,
      );
    } catch (e) {
      debugPrint('Error loading item from file $filePath: $e');
      return null;
    }
  }

  /// Helper to convert a PlatformFile from FilePicker to an ImageItem
  static Future<ImageItem?> _createItemFromPlatformFile(PlatformFile file) async {
    try {
      Uint8List bytes;
      if (file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        bytes = await file.xFile.readAsBytes();
      }
      if (bytes.isEmpty) return null;

      final thumbResult = await ImageProcessor.extractInfoAndThumbnail(bytes);
      final ext = (file.extension ?? p.extension(file.name)).toLowerCase().replaceFirst('.', '');
      final fileSize = file.lengthSync() ?? bytes.length;

      return ImageItem(
        id: _uuid.v4(),
        path: file.path ?? file.name,
        name: file.name,
        extension: ext,
        fileSizeBytes: fileSize,
        width: thumbResult?.width ?? 0,
        height: thumbResult?.height ?? 0,
        dateModified: DateTime.now(),
        bytes: kIsWeb ? bytes : null,
        thumbnailBytes: thumbResult?.thumbnailBytes,
      );
    } catch (e) {
      debugPrint('Error creating item from platform file: $e');
      return null;
    }
  }

  /// Read full bytes of an ImageItem (from disk or memory)
  static Future<Uint8List?> getImageBytes(ImageItem item) async {
    if (item.bytes != null) return item.bytes;
    if (kIsWeb) return null;

    try {
      final file = File(item.path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('Error reading image bytes: $e');
    }
    return null;
  }

  /// Ensure a unique file path if overwrite is disabled
  static String getUniqueFilePath(String targetPath) {
    if (!File(targetPath).existsSync()) return targetPath;

    final dir = p.dirname(targetPath);
    final ext = p.extension(targetPath);
    final nameWithoutExt = p.basenameWithoutExtension(targetPath);

    int counter = 1;
    while (true) {
      final candidate = p.join(dir, '$nameWithoutExt ($counter)$ext');
      if (!File(candidate).existsSync()) {
        return candidate;
      }
      counter++;
    }
  }

  /// Reveal file in system file manager
  static Future<void> openInFileManager(String filePath) async {
    if (kIsWeb) return;
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(filePath)]);
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      }
    } catch (e) {
      debugPrint('Error revealing file: $e');
    }
  }

  /// Delete file from disk
  static Future<bool> deleteFile(String filePath) async {
    if (kIsWeb) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
    return false;
  }

  /// Rename file on disk
  static Future<String?> renameFile(String oldPath, String newName) async {
    if (kIsWeb) return null;
    try {
      final file = File(oldPath);
      if (await file.exists()) {
        final newPath = p.join(p.dirname(oldPath), newName);
        await file.rename(newPath);
        return newPath;
      }
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
    return null;
  }

  /// Create a ZIP archive of images for web or bulk export
  static Uint8List createZipArchive(Map<String, Uint8List> filesMap) {
    final archive = Archive();
    filesMap.forEach((filename, bytes) {
      archive.addFile(ArchiveFile(filename, bytes.length, bytes));
    });
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    return Uint8List.fromList(zipData);
  }
}
