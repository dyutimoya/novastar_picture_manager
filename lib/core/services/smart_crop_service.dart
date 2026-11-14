import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/crop_settings.dart';

class SmartCropService {
  /// Calculate normalized crop rect based on target aspect ratio and focal point alignment
  static NormalizedRect calculateFocalCrop({
    required double imageWidth,
    required double imageHeight,
    required double targetRatio, // width / height
    required FocalPointAlign align,
    Point<double>? customFocalPoint, // normalized (0..1, 0..1)
  }) {
    if (imageWidth <= 0 || imageHeight <= 0 || targetRatio <= 0) {
      return NormalizedRect.full;
    }

    final originalRatio = imageWidth / imageHeight;

    double cropW;
    double cropH;

    if (targetRatio >= originalRatio) {
      // Crop height
      cropW = 1.0;
      cropH = (originalRatio / targetRatio).clamp(0.01, 1.0);
    } else {
      // Crop width
      cropH = 1.0;
      cropW = (targetRatio / originalRatio).clamp(0.01, 1.0);
    }

    // Determine center of crop
    double centerX = 0.5;
    double centerY = 0.5;

    switch (align) {
      case FocalPointAlign.center:
        centerX = 0.5;
        centerY = 0.5;
        break;
      case FocalPointAlign.top:
        centerX = 0.5;
        centerY = cropH / 2.0;
        break;
      case FocalPointAlign.bottom:
        centerX = 0.5;
        centerY = 1.0 - (cropH / 2.0);
        break;
      case FocalPointAlign.left:
        centerX = cropW / 2.0;
        centerY = 0.5;
        break;
      case FocalPointAlign.right:
        centerX = 1.0 - (cropW / 2.0);
        centerY = 0.5;
        break;
      case FocalPointAlign.auto:
        if (customFocalPoint != null) {
          centerX = customFocalPoint.x;
          centerY = customFocalPoint.y;
        } else {
          // Default rule-of-thirds upper center for portraits / subjects
          centerX = 0.5;
          centerY = 0.4;
        }
        break;
    }

    // Clamp coordinates so rectangle stays inside [0, 1]
    double left = centerX - (cropW / 2.0);
    double top = centerY - (cropH / 2.0);

    if (left < 0.0) left = 0.0;
    if (left + cropW > 1.0) left = 1.0 - cropW;
    if (top < 0.0) top = 0.0;
    if (top + cropH > 1.0) top = 1.0 - cropH;

    return NormalizedRect(
      left: left.clamp(0.0, 1.0),
      top: top.clamp(0.0, 1.0),
      width: cropW.clamp(0.01, 1.0),
      height: cropH.clamp(0.01, 1.0),
    );
  }

  /// Detects the visual center-of-energy / focal point of an image using edge gradients
  static Future<Point<double>> detectSubjectFocalPoint(Uint8List imageBytes) async {
    try {
      return await compute(_detectFocalPointTask, imageBytes);
    } catch (e) {
      return const Point(0.5, 0.45);
    }
  }

  static Point<double> _detectFocalPointTask(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const Point(0.5, 0.5);

    // Downscale for fast gradient analysis
    final small = img.copyResize(decoded, width: 80, interpolation: img.Interpolation.linear);
    final w = small.width;
    final h = small.height;

    double weightedX = 0;
    double weightedY = 0;
    double totalWeight = 0;

    // Luminance and gradient energy
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final p = small.getPixel(x, y);
        final pRight = small.getPixel(x + 1, y);
        final pDown = small.getPixel(x, y + 1);

        // Simple gradient magnitude
        final lum = img.getLuminance(p);
        final dx = (img.getLuminance(pRight) - lum).abs();
        final dy = (img.getLuminance(pDown) - lum).abs();
        final grad = dx + dy;

        // Weight center bias slightly
        final normX = x / w;
        final normY = y / h;
        final centerBias = 1.0 - (pow(normX - 0.5, 2) + pow(normY - 0.45, 2));

        final weight = grad * max(0.1, centerBias);
        weightedX += normX * weight;
        weightedY += normY * weight;
        totalWeight += weight;
      }
    }

    if (totalWeight <= 0) return const Point(0.5, 0.5);

    return Point((weightedX / totalWeight).clamp(0.1, 0.9), (weightedY / totalWeight).clamp(0.1, 0.9));
  }
}
