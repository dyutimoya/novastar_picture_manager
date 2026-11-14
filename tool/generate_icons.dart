import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

void main() async {
  print('Generating Master Application Icon for Novastar Picture Manager (1024x1024)...');
  final master = generateMasterIcon(1024);

  // Ensure assets/icon directory exists
  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(master));
  print('Saved assets/icon/app_icon.png');

  // 1. Android Icons
  print('Generating Android icons...');
  final androidSizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  for (final entry in androidSizes.entries) {
    final resized = img.copyResize(
      master,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    File(entry.key).parent.createSync(recursive: true);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
  }

  // 2. iOS Icons
  print('Generating iOS icons...');
  final iosSizes = {
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png': 120,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png': 180,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png': 152,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png': 167,
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in iosSizes.entries) {
    final resized = entry.value == 1024
        ? master
        : img.copyResize(master, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    File(entry.key).parent.createSync(recursive: true);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
  }

  // 3. macOS Icons
  print('Generating macOS icons...');
  final macosSizes = {
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': 16,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': 32,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': 64,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': 128,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': 256,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': 512,
    'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': 1024,
  };
  for (final entry in macosSizes.entries) {
    final resized = entry.value == 1024
        ? master
        : img.copyResize(master, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    File(entry.key).parent.createSync(recursive: true);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
  }

  // 4. Linux Icons
  print('Generating Linux icons...');
  final linuxIconPath = 'linux/runner/resources/app_icon.png';
  File(linuxIconPath).parent.createSync(recursive: true);
  File(linuxIconPath).writeAsBytesSync(
    img.encodePng(img.copyResize(master, width: 256, height: 256, interpolation: img.Interpolation.cubic)),
  );

  // 5. Web Icons & Favicon
  print('Generating Web icons & favicon...');
  final webSizes = {
    'web/favicon.png': 64,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };
  for (final entry in webSizes.entries) {
    final resized = img.copyResize(
      master,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    File(entry.key).parent.createSync(recursive: true);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
  }

  // 6. Windows Multi-Resolution ICO file
  print('Generating Windows app_icon.ico...');
  final icoSizes = [16, 32, 48, 64, 128, 256];
  final icoImages = icoSizes
      .map((s) => img.copyResize(master, width: s, height: s, interpolation: img.Interpolation.cubic))
      .toList();
  final icoBytes = img.IcoEncoder().encodeImages(icoImages);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(icoBytes);

  print('All platform icons generated successfully!');
}

/// Generates a modern, professional, high-resolution app icon for Picture Manager Pro
img.Image generateMasterIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  final cornerRadius = size * 0.22; // Modern squircle rounded corners

  // 1. Draw rounded background squircle with gradient
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Distance from rounded squircle boundary
      final dist = _distanceToRoundedRect(x.toDouble(), y.toDouble(), size.toDouble(), size.toDouble(), cornerRadius);
      if (dist <= 0) {
        // Inside squircle: smooth rich dark navy to cobalt gradient
        final t = (x + y) / (size * 2.0);
        final r = (16 + (32 - 16) * t).round();
        final g = (20 + (45 - 20) * t).round();
        final b = (36 + (75 - 36) * t).round();
        image.setPixelRgba(x, y, r, g, b, 255);
      } else if (dist <= 1.5) {
        // Anti-aliased outer edge
        final alpha = ((1.5 - dist) / 1.5 * 255).round().clamp(0, 255);
        image.setPixelRgba(x, y, 20, 26, 45, alpha);
      }
    }
  }

  // 2. Subtle Outer Border Glow (electric blue)
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dist = _distanceToRoundedRect(x.toDouble(), y.toDouble(), size.toDouble(), size.toDouble(), cornerRadius);
      if (dist <= 0 && dist >= -8) {
        final borderAlpha = ((-dist / 8.0) * 160).round();
        final cur = image.getPixel(x, y);
        image.setPixelRgba(
          x,
          y,
          _blend(cur.r.toInt(), 58, borderAlpha),
          _blend(cur.g.toInt(), 134, borderAlpha),
          _blend(cur.b.toInt(), 255, borderAlpha),
          255,
        );
      }
    }
  }

  // 3. Central Photo Canvas Frame (layered picture)
  final photoInsetX = size * 0.16;
  final photoInsetY = size * 0.18;
  final photoW = size - (photoInsetX * 2);
  final photoH = size - (photoInsetY * 2);
  final photoCorner = size * 0.10;

  for (int y = photoInsetY.round(); y < (photoInsetY + photoH).round(); y++) {
    for (int x = photoInsetX.round(); x < (photoInsetX + photoW).round(); x++) {
      final lx = x - photoInsetX;
      final ly = y - photoInsetY;
      final dist = _distanceToRoundedRect(lx, ly, photoW, photoH, photoCorner);

      if (dist <= 0) {
        // Sunset / Landscape photo gradient (Deep Indigo -> Violet -> Electric Blue)
        final ty = ly / photoH;
        final tx = lx / photoW;

        int pr, pg, pb;
        if (ty < 0.55) {
          // Sky gradient (Deep Twilight to Vibrant Magenta/Orange horizon)
          final skyT = ty / 0.55;
          pr = (28 + (240 - 28) * skyT).round();
          pg = (40 + (100 - 40) * skyT).round();
          pb = (140 + (120 - 140) * skyT).round();
        } else {
          // Ground/Sea gradient (Cyan & Midnight Blue)
          final seaT = (ty - 0.55) / 0.45;
          pr = (20 + (10 - 20) * seaT).round();
          pg = (120 + (30 - 120) * seaT).round();
          pb = (200 + (70 - 200) * seaT).round();
        }

        // Draw glowing golden sun
        final sunDx = lx - (photoW * 0.65);
        final sunDy = ly - (photoH * 0.38);
        final sunDist = sqrt(sunDx * sunDx + sunDy * sunDy);
        final sunRadius = photoW * 0.16;
        if (sunDist < sunRadius) {
          final sunT = 1.0 - (sunDist / sunRadius);
          pr = _blend(pr, 255, (sunT * 255).round());
          pg = _blend(pg, 210, (sunT * 240).round());
          pb = _blend(pb, 100, (sunT * 180).round());
        }

        // Draw geometric mountain in lower photo
        final mountainY = photoH * 0.50 + sin((tx * pi)) * (photoH * -0.22);
        if (ly >= mountainY) {
          final mtnAlpha = 220;
          pr = _blend(pr, 24, mtnAlpha);
          pg = _blend(pg, 45, mtnAlpha);
          pb = _blend(pb, 85, mtnAlpha);
        }

        image.setPixelRgba(x, y, pr, pg, pb, 255);
      }
    }
  }

  // 4. Overlaid Crop Rectangle with Rule-of-Thirds Grid & Corner Handles
  final cropMargin = size * 0.22;
  final cropW = size - (cropMargin * 2);
  final cropH = size - (cropMargin * 2);
  final cropLeft = cropMargin;
  final cropTop = cropMargin;
  final cropRight = cropLeft + cropW;
  final cropBottom = cropTop + cropH;

  // Rule of thirds subtle grid lines
  final gridColor = img.ColorRgba8(255, 255, 255, 75);
  final x1 = (cropLeft + cropW / 3.0).round();
  final x2 = (cropLeft + (cropW * 2.0 / 3.0)).round();
  final y1 = (cropTop + cropH / 3.0).round();
  final y2 = (cropTop + (cropH * 2.0 / 3.0)).round();

  img.drawLine(image, x1: x1, y1: cropTop.round(), x2: x1, y2: cropBottom.round(), color: gridColor);
  img.drawLine(image, x1: x2, y1: cropTop.round(), x2: x2, y2: cropBottom.round(), color: gridColor);
  img.drawLine(image, x1: cropLeft.round(), y1: y1, x2: cropRight.round(), y2: y1, color: gridColor);
  img.drawLine(image, x1: cropLeft.round(), y1: y2, x2: cropRight.round(), y2: y2, color: gridColor);

  // Crop outer rectangle border
  final borderStroke = max(2, (size * 0.008).round());
  _drawRectOutline(
    image,
    cropLeft.round(),
    cropTop.round(),
    cropW.round(),
    cropH.round(),
    borderStroke,
    img.ColorRgba8(255, 255, 255, 210),
  );

  // Corner crop handles (4 chunky white corner brackets)
  final handleLen = (size * 0.08).round();
  final handleThick = max(3, (size * 0.016).round());
  final handleColor = img.ColorRgba8(255, 255, 255, 255);

  // Top-Left Handle
  _fillRect(
    image,
    cropLeft.round() - handleThick ~/ 2,
    cropTop.round() - handleThick ~/ 2,
    handleLen,
    handleThick,
    handleColor,
  );
  _fillRect(
    image,
    cropLeft.round() - handleThick ~/ 2,
    cropTop.round() - handleThick ~/ 2,
    handleThick,
    handleLen,
    handleColor,
  );

  // Top-Right Handle
  _fillRect(
    image,
    cropRight.round() - handleLen + handleThick ~/ 2,
    cropTop.round() - handleThick ~/ 2,
    handleLen,
    handleThick,
    handleColor,
  );
  _fillRect(
    image,
    cropRight.round() - handleThick ~/ 2,
    cropTop.round() - handleThick ~/ 2,
    handleThick,
    handleLen,
    handleColor,
  );

  // Bottom-Left Handle
  _fillRect(
    image,
    cropLeft.round() - handleThick ~/ 2,
    cropBottom.round() - handleThick ~/ 2,
    handleLen,
    handleThick,
    handleColor,
  );
  _fillRect(
    image,
    cropLeft.round() - handleThick ~/ 2,
    cropBottom.round() - handleLen + handleThick ~/ 2,
    handleThick,
    handleLen,
    handleColor,
  );

  // Bottom-Right Handle
  _fillRect(
    image,
    cropRight.round() - handleLen + handleThick ~/ 2,
    cropBottom.round() - handleThick ~/ 2,
    handleLen,
    handleThick,
    handleColor,
  );
  _fillRect(
    image,
    cropRight.round() - handleThick ~/ 2,
    cropBottom.round() - handleLen + handleThick ~/ 2,
    handleThick,
    handleLen,
    handleColor,
  );

  return image;
}

int _blend(int bg, int fg, int alpha) {
  final a = alpha / 255.0;
  return ((1.0 - a) * bg + a * fg).round().clamp(0, 255);
}

void _fillRect(img.Image image, int x, int y, int w, int h, img.ColorRgba8 color) {
  for (int cy = y; cy < y + h; cy++) {
    for (int cx = x; cx < x + w; cx++) {
      if (cx >= 0 && cx < image.width && cy >= 0 && cy < image.height) {
        image.setPixel(cx, cy, color);
      }
    }
  }
}

void _drawRectOutline(img.Image image, int x, int y, int w, int h, int stroke, img.ColorRgba8 color) {
  _fillRect(image, x, y, w, stroke, color); // top
  _fillRect(image, x, y + h - stroke, w, stroke, color); // bottom
  _fillRect(image, x, y, stroke, h, color); // left
  _fillRect(image, x + w - stroke, y, stroke, h, color); // right
}

double _distanceToRoundedRect(double x, double y, double w, double h, double r) {
  final cx = w / 2.0;
  final cy = h / 2.0;
  final dx = (x - cx).abs() - (cx - r);
  final dy = (y - cy).abs() - (cy - r);

  if (dx <= 0 && dy <= 0) {
    return -min(-dx, -dy);
  }
  if (dx > 0 && dy <= 0) {
    return dx;
  }
  if (dx <= 0 && dy > 0) {
    return dy;
  }
  return sqrt(dx * dx + dy * dy) - r;
}
