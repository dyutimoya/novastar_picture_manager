import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/models/image_item.dart';
import 'core/services/file_service.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  ImageItem? initialImage;
  List<ImageItem>? siblingImages;

  if (args.isNotEmpty && !kIsWeb) {
    try {
      final filePath = args.first;
      final file = File(filePath);
      if (await file.exists()) {
        initialImage = await FileService.loadItemFromFile(filePath);
        if (initialImage != null) {
          final parentDir = file.parent.path;
          siblingImages = await FileService.scanDirectory(parentDir);
        }
      }
    } catch (e) {
      debugPrint('Error loading CLI image argument: $e');
    }
  }

  runApp(
    ProviderScope(
      child: PictureManagerApp(initialImage: initialImage, initialFolderImages: siblingImages),
    ),
  );
}
