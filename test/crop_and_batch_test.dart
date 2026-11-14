import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novastar_picture_manager/core/models/batch_operations.dart';
import 'package:novastar_picture_manager/core/models/crop_settings.dart';
import 'package:novastar_picture_manager/core/models/image_adjustments.dart';
import 'package:novastar_picture_manager/core/models/image_item.dart';
import 'package:novastar_picture_manager/core/services/image_processor.dart';
import 'package:novastar_picture_manager/core/services/smart_crop_service.dart';
import 'package:novastar_picture_manager/core/services/system_integration_service.dart';
import 'package:novastar_picture_manager/core/state/batch_crop_provider.dart';

void main() {
  group('1. Normalized Rect & Crop Coordinate Calculations', () {
    test('Normalized rect clamps correctly within bounds [0, 1]', () {
      const rect = NormalizedRect(left: -0.2, top: 0.1, width: 1.5, height: 0.8);
      final clamped = rect.clamp();

      expect(clamped.left, greaterThanOrEqualTo(0.0));
      expect(clamped.top, greaterThanOrEqualTo(0.0));
      expect(clamped.right, lessThanOrEqualTo(1.0));
      expect(clamped.bottom, lessThanOrEqualTo(1.0));
    });

    test('Converts between pixel rect and normalized rect accurately', () {
      const imgW = 1920.0;
      const imgH = 1080.0;

      final norm = const NormalizedRect(left: 0.25, top: 0.25, width: 0.5, height: 0.5);
      final pixelRect = norm.toPixelRect(imgW, imgH);

      expect(pixelRect.left, 480.0);
      expect(pixelRect.top, 270.0);
      expect(pixelRect.width, 960.0);
      expect(pixelRect.height, 540.0);

      final backToNorm = NormalizedRect.fromPixelRect(pixelRect, imgW, imgH);
      expect(backToNorm.left, closeTo(0.25, 1e-4));
      expect(backToNorm.top, closeTo(0.25, 1e-4));
      expect(backToNorm.width, closeTo(0.5, 1e-4));
      expect(backToNorm.height, closeTo(0.5, 1e-4));
    });

    test('Aspect ratio preservation in focal crop calculation', () {
      final crop1x1 = SmartCropService.calculateFocalCrop(
        imageWidth: 1920,
        imageHeight: 1080,
        targetRatio: 1.0,
        align: FocalPointAlign.center,
      );

      final pixelW = crop1x1.width * 1920;
      final pixelH = crop1x1.height * 1080;
      expect((pixelW / pixelH), closeTo(1.0, 1e-3));
      expect(crop1x1.left, closeTo((1.0 - crop1x1.width) / 2.0, 1e-3));
    });

    test('Focal point top align positions crop rectangle at top', () {
      final cropTop = SmartCropService.calculateFocalCrop(
        imageWidth: 1000,
        imageHeight: 2000,
        targetRatio: 1.0,
        align: FocalPointAlign.top,
      );

      expect(cropTop.top, 0.0);
    });
  });

  group('2. Batch Resize Calculations', () {
    test('Percentage resize scales dimensions proportionally', () {
      const resize = ResizeSettings(mode: ResizeMode.percentage, percentage: 50);
      final (w, h) = resize.calculateDimensions(1920, 1080);
      expect(w, 960);
      expect(h, 540);
    });

    test('Fit inside maintains aspect ratio within maximum bounds', () {
      const resize = ResizeSettings(mode: ResizeMode.fitInside, targetWidth: 1000, targetHeight: 1000);
      final (w, h) = resize.calculateDimensions(1920, 1080);
      expect(w, 1000);
      expect(h, 563);
    });
  });

  group('3. Export Naming & File Overwrite Prevention', () {
    test('Sequential naming generates proper padded numbering', () {
      const rename = RenameSettings(mode: NamingMode.sequential, baseName: 'holiday', startNumber: 1, digitPadding: 3);

      final name0 = rename.generateName(
        originalNameWithoutExtension: 'IMG_4821',
        index: 0,
        date: DateTime(2026, 11, 14),
      );
      final name9 = rename.generateName(
        originalNameWithoutExtension: 'IMG_4822',
        index: 9,
        date: DateTime(2026, 11, 14),
      );

      expect(name0, 'holiday_001');
      expect(name9, 'holiday_010');
    });

    test('Prefix and suffix naming works cleanly', () {
      const rename = RenameSettings(mode: NamingMode.suffix, suffix: '_watermarked');
      final result = rename.generateName(originalNameWithoutExtension: 'profile', index: 0, date: DateTime.now());
      expect(result, 'profile_watermarked');
    });
  });

  group('4. Batch Crop Provider: Individual Crop Settings & Undo/Redo', () {
    late List<ImageItem> mockImages;
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      mockImages = List.generate(
        5,
        (i) => ImageItem(
          id: 'img_$i',
          path: '/mock/path/img_$i.jpg',
          name: 'img_$i.jpg',
          extension: 'jpg',
          fileSizeBytes: 1024 * 100,
          width: 1000,
          height: 800,
          dateModified: DateTime.now(),
        ),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Stores separate crop settings for each image', () {
      final notifier = container.read(batchCropProvider.notifier);
      notifier.init(mockImages);

      notifier.selectImage(0);
      notifier.updateCurrentCrop(
        const CropSettings(
          rect: NormalizedRect(left: 0.1, top: 0.1, width: 0.5, height: 0.5),
          aspectRatio: CropAspectRatio.square,
        ),
      );

      notifier.selectImage(1);
      notifier.updateCurrentCrop(
        const CropSettings(
          rect: NormalizedRect(left: 0.2, top: 0.2, width: 0.6, height: 0.6),
          aspectRatio: CropAspectRatio.ratio16_9,
        ),
      );

      notifier.selectImage(0);
      expect(container.read(batchCropProvider).currentSettings.aspectRatio, CropAspectRatio.square);
      expect(container.read(batchCropProvider).currentSettings.rect.left, 0.1);

      notifier.selectImage(1);
      expect(container.read(batchCropProvider).currentSettings.aspectRatio, CropAspectRatio.ratio16_9);
      expect(container.read(batchCropProvider).currentSettings.rect.left, 0.2);
    });

    test('Common batch cropping applies framing to all images', () {
      final notifier = container.read(batchCropProvider.notifier);
      notifier.init(mockImages);

      notifier.centerCropAll(CropAspectRatio.ratio16_9);

      for (final img in mockImages) {
        final settings = container.read(batchCropProvider).settingsMap[img.id];
        expect(settings, isNotNull);
        expect(settings!.aspectRatio, CropAspectRatio.ratio16_9);
      }
    });

    test('Fine rotation stepping (+1° and -1°) and reset functionality', () {
      final notifier = container.read(batchCropProvider.notifier);
      notifier.init(mockImages);
      notifier.selectImage(0);

      expect(container.read(batchCropProvider).currentSettings.fineAngle, 0.0);

      // Increment by 1° (1+++)
      notifier.stepFineRotation(1.0);
      expect(container.read(batchCropProvider).currentSettings.fineAngle, 1.0);
      expect(container.read(batchCropProvider).currentSettings.totalAngle, 1.0);

      notifier.stepFineRotation(1.0);
      expect(container.read(batchCropProvider).currentSettings.fineAngle, 2.0);

      // Decrement by 1°
      notifier.stepFineRotation(-1.0);
      expect(container.read(batchCropProvider).currentSettings.fineAngle, 1.0);

      // Set direct fine angle
      notifier.setFineAngle(15.5);
      expect(container.read(batchCropProvider).currentSettings.fineAngle, 15.5);

      // Reset
      notifier.resetRotation();
      expect(container.read(batchCropProvider).currentSettings.fineAngle, 0.0);
      expect(container.read(batchCropProvider).currentSettings.totalAngle, 0.0);
    });

    test('Undo and redo restores previous crop states', () {
      final notifier = container.read(batchCropProvider.notifier);
      notifier.init(mockImages);

      notifier.selectImage(0);
      final initialRect = container.read(batchCropProvider).currentSettings.rect;

      const newSettings = CropSettings(rect: NormalizedRect(left: 0.2, top: 0.2, width: 0.4, height: 0.4));
      notifier.updateCurrentCrop(newSettings);
      expect(container.read(batchCropProvider).currentSettings.rect.left, 0.2);
      expect(container.read(batchCropProvider).canUndo, isTrue);

      notifier.undo();
      expect(container.read(batchCropProvider).currentSettings.rect, initialRect);
      expect(container.read(batchCropProvider).canRedo, isTrue);

      notifier.redo();
      expect(container.read(batchCropProvider).currentSettings.rect.left, 0.2);
    });
  });

  group('5. Extended Image Operations: Filters, Watermark, Borders', () {
    late Uint8List testBytes;

    setUp(() {
      final testImg = img.Image(width: 200, height: 100);
      img.fill(testImg, color: img.ColorRgb8(200, 50, 50));
      testBytes = Uint8List.fromList(img.encodePng(testImg));
    });

    test('Applies Grayscale filter effect correctly', () async {
      final processed = await ImageProcessor.processImage(
        ProcessTaskParams(
          rawBytes: testBytes,
          adjustments: const ImageAdjustments(filter: ImageFilterType.grayscale),
          format: ImageOutputFormat.png,
        ),
      );

      expect(processed, isNotNull);
      final decoded = img.decodeImage(processed!);
      expect(decoded, isNotNull);
      // Grayscale pixel should have r == g == b
      final pixel = decoded!.getPixel(50, 50);
      expect(pixel.r, equals(pixel.g));
      expect(pixel.g, equals(pixel.b));
    });

    test('Applies Watermark and Outer Border correctly', () async {
      final processed = await ImageProcessor.processImage(
        ProcessTaskParams(
          rawBytes: testBytes,
          adjustments: const ImageAdjustments(
            watermark: WatermarkSettings(enabled: true, text: 'TEST_COPYRIGHT', position: WatermarkPosition.center),
            border: BorderSettings(enabled: true, thickness: 6, colorHex: '#FFFFFF'),
          ),
          format: ImageOutputFormat.png,
        ),
      );

      expect(processed, isNotNull);
      final decoded = img.decodeImage(processed!);
      expect(decoded, isNotNull);
      // Top border pixel at (0, 0) should be white (r=255, g=255, b=255)
      final borderPixel = decoded!.getPixel(0, 0);
      expect(borderPixel.r, 255);
      expect(borderPixel.g, 255);
      expect(borderPixel.b, 255);
    });
  });

  group('6. Default Viewer & System Integration', () {
    test('Windows Registry script contains all supported image extensions', () {
      final reg = SystemIntegrationService.generateWindowsRegContent();
      expect(reg, contains('.jpg'));
      expect(reg, contains('.png'));
      expect(reg, contains('.webp'));
      expect(reg, contains('.bmp'));
      expect(reg, contains('.tiff'));
      expect(reg, contains('Novastar.PictureManager.Image'));
    });
  });
}
