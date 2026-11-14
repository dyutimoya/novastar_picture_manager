import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'crop_settings.dart';
import 'image_adjustments.dart';

class ImageItem {
  final String id;
  final String path;
  final String name;
  final String extension;
  final int fileSizeBytes;
  final int width;
  final int height;
  final DateTime dateModified;
  final Uint8List? bytes;
  final Uint8List? thumbnailBytes;
  final bool isFavorite;
  final CropSettings cropSettings;
  final ImageAdjustments adjustments;

  const ImageItem({
    required this.id,
    required this.path,
    required this.name,
    required this.extension,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
    required this.dateModified,
    this.bytes,
    this.thumbnailBytes,
    this.isFavorite = false,
    this.cropSettings = CropSettings.initial,
    this.adjustments = ImageAdjustments.initial,
  });

  double get aspectRatio => (width > 0 && height > 0) ? width / height : 1.0;

  String get humanReadableSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get dimensionsText => width > 0 && height > 0 ? '${width}x$height' : 'Unknown';

  int get effectiveWidth {
    if (cropSettings.rotationDegrees == 90 || cropSettings.rotationDegrees == 270) {
      return (height * cropSettings.rect.width).round();
    }
    return (width * cropSettings.rect.width).round();
  }

  int get effectiveHeight {
    if (cropSettings.rotationDegrees == 90 || cropSettings.rotationDegrees == 270) {
      return (width * cropSettings.rect.height).round();
    }
    return (height * cropSettings.rect.height).round();
  }

  ImageItem copyWith({
    String? id,
    String? path,
    String? name,
    String? extension,
    int? fileSizeBytes,
    int? width,
    int? height,
    DateTime? dateModified,
    Uint8List? bytes,
    Uint8List? thumbnailBytes,
    bool? isFavorite,
    CropSettings? cropSettings,
    ImageAdjustments? adjustments,
  }) {
    return ImageItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      extension: extension ?? this.extension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      dateModified: dateModified ?? this.dateModified,
      bytes: bytes ?? this.bytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      isFavorite: isFavorite ?? this.isFavorite,
      cropSettings: cropSettings ?? this.cropSettings,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'extension': extension,
    'fileSizeBytes': fileSizeBytes,
    'width': width,
    'height': height,
    'dateModified': dateModified.toIso8601String(),
    'isFavorite': isFavorite,
    'cropSettings': cropSettings.toJson(),
    'adjustments': adjustments.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageItem && runtimeType == other.runtimeType && id == other.id && path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;
}
