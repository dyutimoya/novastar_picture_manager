import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/crop_settings.dart';
import '../models/image_adjustments.dart';
import '../models/batch_operations.dart';

class ProcessTaskParams {
  final Uint8List rawBytes;
  final CropSettings? cropSettings;
  final ImageAdjustments? adjustments;
  final ResizeSettings? resizeSettings;
  final ImageOutputFormat format;
  final int quality;

  const ProcessTaskParams({
    required this.rawBytes,
    this.cropSettings,
    this.adjustments,
    this.resizeSettings,
    this.format = ImageOutputFormat.original,
    this.quality = 90,
  });
}

class ThumbnailParams {
  final Uint8List rawBytes;
  final int maxDimension;

  const ThumbnailParams({required this.rawBytes, this.maxDimension = 320});
}

class ImageDimensionsResult {
  final int width;
  final int height;
  final Uint8List thumbnailBytes;

  const ImageDimensionsResult({required this.width, required this.height, required this.thumbnailBytes});
}

class ImageProcessor {
  /// Generate thumbnail and extract dimensions in background isolate
  static Future<ImageDimensionsResult?> extractInfoAndThumbnail(Uint8List bytes, {int maxDimension = 320}) async {
    try {
      return await compute(_extractInfoAndThumbnailTask, ThumbnailParams(rawBytes: bytes, maxDimension: maxDimension));
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  /// Generate crisp high-resolution preview base (up to 2048px) for interactive editor
  static Future<Uint8List?> createHighResPreviewBase(Uint8List bytes, {int maxDimension = 2048}) async {
    try {
      return await compute(_createHighResPreviewBaseTask, ThumbnailParams(rawBytes: bytes, maxDimension: maxDimension));
    } catch (e) {
      debugPrint('Error creating high-res preview base: $e');
      return bytes;
    }
  }

  static Uint8List? _createHighResPreviewBaseTask(ThumbnailParams params) {
    final decoded = img.decodeImage(params.rawBytes);
    if (decoded == null) return null;

    final origW = decoded.width;
    final origH = decoded.height;

    img.Image highRes;
    if (origW > params.maxDimension || origH > params.maxDimension) {
      if (origW >= origH) {
        highRes = img.copyResize(decoded, width: params.maxDimension, interpolation: img.Interpolation.cubic);
      } else {
        highRes = img.copyResize(decoded, height: params.maxDimension, interpolation: img.Interpolation.cubic);
      }
    } else {
      highRes = decoded;
    }

    return Uint8List.fromList(img.encodePng(highRes));
  }

  /// Process full resolution image in background isolate
  static Future<Uint8List?> processImage(ProcessTaskParams params) async {
    try {
      return await compute(_processImageTask, params);
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  /// Synchronous/static isolate task for thumbnail & metadata
  static ImageDimensionsResult? _extractInfoAndThumbnailTask(ThumbnailParams params) {
    final decoded = img.decodeImage(params.rawBytes);
    if (decoded == null) return null;

    final origW = decoded.width;
    final origH = decoded.height;

    img.Image thumb;
    if (origW > params.maxDimension || origH > params.maxDimension) {
      if (origW >= origH) {
        thumb = img.copyResize(decoded, width: params.maxDimension, interpolation: img.Interpolation.linear);
      } else {
        thumb = img.copyResize(decoded, height: params.maxDimension, interpolation: img.Interpolation.linear);
      }
    } else {
      thumb = decoded;
    }

    final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 75));
    return ImageDimensionsResult(width: origW, height: origH, thumbnailBytes: thumbBytes);
  }

  /// Helper to parse hex color (#RRGGBB or #AARRGGBB) to img.ColorRgba8
  static img.ColorRgba8 _parseColor(String hex, double opacity) {
    var clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      clean = 'FF$clean';
    } else if (clean.length != 8) {
      clean = 'FFFFFFFF';
    }
    final intVal = int.tryParse(clean, radix: 16) ?? 0xFFFFFFFF;
    final a = (((intVal >> 24) & 0xFF) * opacity).round().clamp(0, 255);
    final r = (intVal >> 16) & 0xFF;
    final g = (intVal >> 8) & 0xFF;
    final b = intVal & 0xFF;
    return img.ColorRgba8(r, g, b, a);
  }

  /// Draw borders inside the image edges
  static img.Image _drawBorder(img.Image image, int thickness, img.ColorRgba8 color) {
    final t = thickness.clamp(1, min(image.width, image.height) ~/ 2);
    // Draw top & bottom borders
    for (int y = 0; y < t; y++) {
      for (int x = 0; x < image.width; x++) {
        image.setPixel(x, y, color);
        image.setPixel(x, image.height - 1 - y, color);
      }
    }
    // Draw left & right borders
    for (int y = t; y < image.height - t; y++) {
      for (int x = 0; x < t; x++) {
        image.setPixel(x, y, color);
        image.setPixel(image.width - 1 - x, y, color);
      }
    }
    return image;
  }

  /// Draw text watermark on image
  static img.Image _applyWatermark(img.Image image, WatermarkSettings watermark) {
    if (watermark.text.trim().isEmpty) return image;

    img.BitmapFont font = img.arial24;
    int charW = 14;
    int charH = 24;

    if (watermark.fontSize >= 40) {
      font = img.arial48;
      charW = 28;
      charH = 48;
    } else if (watermark.fontSize <= 18) {
      font = img.arial14;
      charW = 8;
      charH = 14;
    }

    final text = watermark.text;
    final textWidth = text.length * charW;
    final textHeight = charH;
    final color = _parseColor(watermark.colorHex, watermark.opacity);

    int posX = 20;
    int posY = 20;

    switch (watermark.position) {
      case WatermarkPosition.topLeft:
        posX = 24;
        posY = 24;
        break;
      case WatermarkPosition.topRight:
        posX = max(10, image.width - textWidth - 24);
        posY = 24;
        break;
      case WatermarkPosition.bottomLeft:
        posX = 24;
        posY = max(10, image.height - textHeight - 24);
        break;
      case WatermarkPosition.bottomRight:
        posX = max(10, image.width - textWidth - 24);
        posY = max(10, image.height - textHeight - 24);
        break;
      case WatermarkPosition.center:
        posX = max(10, (image.width - textWidth) ~/ 2);
        posY = max(10, (image.height - textHeight) ~/ 2);
        break;
    }

    img.drawString(image, text, font: font, x: posX, y: posY, color: color);
    return image;
  }

  /// Synchronous/static isolate task for full image manipulation pipeline
  static Uint8List? _processImageTask(ProcessTaskParams params) {
    var image = img.decodeImage(params.rawBytes);
    if (image == null) return null;

    // 1. Apply Orientation / Rotation & Flip first
    if (params.cropSettings != null) {
      final crop = params.cropSettings!;
      if (crop.flipHorizontal) {
        image = img.copyFlip(image, direction: img.FlipDirection.horizontal);
      }
      if (crop.flipVertical) {
        image = img.copyFlip(image, direction: img.FlipDirection.vertical);
      }
      final totalRotation = crop.totalAngle;
      if (totalRotation != 0.0) {
        image = img.copyRotate(image, angle: totalRotation);
      }

      // 2. Crop
      final normRect = crop.rect.clamp();
      if (normRect != NormalizedRect.full) {
        final pixelX = (normRect.left * image.width).round().clamp(0, image.width - 1);
        final pixelY = (normRect.top * image.height).round().clamp(0, image.height - 1);
        final pixelW = (normRect.width * image.width).round().clamp(1, image.width - pixelX);
        final pixelH = (normRect.height * image.height).round().clamp(1, image.height - pixelY);

        image = img.copyCrop(image, x: pixelX, y: pixelY, width: pixelW, height: pixelH);
      }
    }

    // 3. Adjustments (Brightness, Contrast, Saturation, Hue, Gamma, Temperature)
    if (params.adjustments != null && params.adjustments!.isModified) {
      final adj = params.adjustments!;
      image = img.adjustColor(
        image,
        brightness: 1.0 + adj.brightness,
        contrast: adj.contrast,
        saturation: adj.saturation,
        hue: adj.hue,
        gamma: adj.gamma,
      );

      // Temperature / Tint color tinting
      if (adj.temperature != 0.0 || adj.tint != 0.0) {
        final rDelta = (adj.temperature * 25 + adj.tint * 15).round();
        final gDelta = (-adj.tint * 30).round();
        final bDelta = (-adj.temperature * 25 + adj.tint * 15).round();

        for (final pixel in image) {
          final r = (pixel.r + rDelta).clamp(0, 255);
          final g = (pixel.g + gDelta).clamp(0, 255);
          final b = (pixel.b + bDelta).clamp(0, 255);
          pixel.r = r;
          pixel.g = g;
          pixel.b = b;
        }
      }

      // Filter Effects (Grayscale, Sepia, Vignette, Invert, Sketch, Emboss, Pixelate, Blur, AutoLevels)
      if (adj.filter != ImageFilterType.none) {
        switch (adj.filter) {
          case ImageFilterType.grayscale:
            image = img.grayscale(image);
            break;
          case ImageFilterType.sepia:
            image = img.sepia(image);
            break;
          case ImageFilterType.vignette:
            image = img.vignette(image);
            break;
          case ImageFilterType.invert:
            image = img.invert(image);
            break;
          case ImageFilterType.sketch:
            image = img.sketch(image);
            break;
          case ImageFilterType.emboss:
            image = img.emboss(image);
            break;
          case ImageFilterType.pixelate:
            image = img.pixelate(image, size: 10);
            break;
          case ImageFilterType.blur:
            image = img.gaussianBlur(image, radius: 4);
            break;
          case ImageFilterType.autoLevels:
            image = img.normalize(image, min: 0, max: 255);
            break;
          case ImageFilterType.none:
            break;
        }
      }

      // Borders / Frames
      if (adj.border.enabled && adj.border.thickness > 0) {
        final borderColor = _parseColor(adj.border.colorHex, 1.0);
        image = _drawBorder(image, adj.border.thickness, borderColor);
      }

      // Watermark
      if (adj.watermark.enabled && adj.watermark.text.isNotEmpty) {
        image = _applyWatermark(image, adj.watermark);
      }
    }

    // 4. Resize
    if (params.resizeSettings != null) {
      final (targetW, targetH) = params.resizeSettings!.calculateDimensions(image.width, image.height);
      if (targetW > 0 && targetH > 0 && (targetW != image.width || targetH != image.height)) {
        if (params.resizeSettings!.mode == ResizeMode.fillCrop) {
          image = img.copyResizeCropSquare(image, size: targetW < targetH ? targetW : targetH);
          if (image.width != targetW || image.height != targetH) {
            image = img.copyResize(image, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
          }
        } else {
          image = img.copyResize(image, width: targetW, height: targetH, interpolation: img.Interpolation.cubic);
        }
      }
    }

    // 5. Encode output format
    final quality = params.quality.clamp(1, 100);
    switch (params.format) {
      case ImageOutputFormat.jpg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageOutputFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ImageOutputFormat.webp:
        return Uint8List.fromList(img.encodeWebP(image, quality: quality));
      case ImageOutputFormat.bmp:
        return Uint8List.fromList(img.encodeBmp(image));
      case ImageOutputFormat.tiff:
        return Uint8List.fromList(img.encodeTiff(image));
      case ImageOutputFormat.original:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
  }
}
