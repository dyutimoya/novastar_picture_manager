import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/batch_operations.dart';
import '../models/crop_settings.dart';
import '../models/image_adjustments.dart';
import '../models/image_item.dart';
import '../services/file_service.dart';
import '../services/image_processor.dart';

class ExportState {
  final bool isExporting;
  final double progress;
  final String currentProcessingName;
  final int processedCount;
  final int totalCount;
  final bool isCancelled;
  final int errorCount;
  final List<String> exportedPaths;
  final String? completionMessage;

  const ExportState({
    this.isExporting = false,
    this.progress = 0.0,
    this.currentProcessingName = '',
    this.processedCount = 0,
    this.totalCount = 0,
    this.isCancelled = false,
    this.errorCount = 0,
    this.exportedPaths = const [],
    this.completionMessage,
  });

  ExportState copyWith({
    bool? isExporting,
    double? progress,
    String? currentProcessingName,
    int? processedCount,
    int? totalCount,
    bool? isCancelled,
    int? errorCount,
    List<String>? exportedPaths,
    String? completionMessage,
  }) {
    return ExportState(
      isExporting: isExporting ?? this.isExporting,
      progress: progress ?? this.progress,
      currentProcessingName: currentProcessingName ?? this.currentProcessingName,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      isCancelled: isCancelled ?? this.isCancelled,
      errorCount: errorCount ?? this.errorCount,
      exportedPaths: exportedPaths ?? this.exportedPaths,
      completionMessage: completionMessage ?? this.completionMessage,
    );
  }
}

class ExportNotifier extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  bool _cancelRequested = false;

  void cancel() {
    _cancelRequested = true;
    state = state.copyWith(isCancelled: true);
  }

  void reset() {
    _cancelRequested = false;
    state = const ExportState();
  }

  Future<bool> runBatchExport({
    required List<ImageItem> items,
    required Map<String, CropSettings> cropSettingsMap,
    required ExportSettings settings,
  }) async {
    if (items.isEmpty) return false;

    _cancelRequested = false;
    state = ExportState(
      isExporting: true,
      totalCount: items.length,
      processedCount: 0,
      progress: 0.0,
      exportedPaths: [],
    );

    // Target directory
    String targetDir = settings.outputDirectory;
    if (targetDir.isEmpty && !kIsWeb && items.first.path.isNotEmpty) {
      targetDir = p.dirname(items.first.path);
    }
    if (settings.createSubfolder && !kIsWeb && targetDir.isNotEmpty) {
      targetDir = p.join(targetDir, settings.subfolderName);
      final dir = Directory(targetDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }

    final exportedPaths = <String>[];
    final zipFilesMap = <String, Uint8List>{};
    int errors = 0;

    for (int i = 0; i < items.length; i++) {
      if (_cancelRequested) {
        state = state.copyWith(
          isExporting: false,
          isCancelled: true,
          completionMessage: 'Export cancelled after $i of ${items.length} images.',
        );
        return false;
      }

      final item = items[i];
      state = state.copyWith(
        currentProcessingName: item.name,
        processedCount: i,
        progress: items.isEmpty ? 1.0 : i / items.length,
      );

      try {
        final rawBytes = await FileService.getImageBytes(item);
        if (rawBytes == null) {
          errors++;
          continue;
        }

        final crop = settings.applyCrop ? (cropSettingsMap[item.id] ?? item.cropSettings) : null;
        var adjustments = settings.applyAdjustments ? item.adjustments : ImageAdjustments.initial;

        // Apply batch operations if configured
        if (settings.batchFilter != null && settings.batchFilter != ImageFilterType.none) {
          adjustments = adjustments.copyWith(filter: settings.batchFilter);
        }
        if (settings.batchWatermark != null && settings.batchWatermark!.enabled) {
          adjustments = adjustments.copyWith(watermark: settings.batchWatermark);
        }
        if (settings.batchBorder != null && settings.batchBorder!.enabled) {
          adjustments = adjustments.copyWith(border: settings.batchBorder);
        }

        // Determine output extension and format
        ImageOutputFormat outFormat = settings.format;
        String ext;
        if (outFormat == ImageOutputFormat.original) {
          ext = item.extension.toLowerCase();
          switch (ext) {
            case 'png':
              outFormat = ImageOutputFormat.png;
              break;
            case 'webp':
              outFormat = ImageOutputFormat.webp;
              break;
            case 'bmp':
              outFormat = ImageOutputFormat.bmp;
              break;
            case 'tiff':
            case 'tif':
              outFormat = ImageOutputFormat.tiff;
              break;
            default:
              outFormat = ImageOutputFormat.jpg;
              ext = 'jpg';
          }
        } else {
          ext = outFormat.extension;
        }

        final processedBytes = await ImageProcessor.processImage(
          ProcessTaskParams(
            rawBytes: rawBytes,
            cropSettings: crop,
            adjustments: adjustments,
            resizeSettings: settings.resizeSettings,
            format: outFormat,
            quality: settings.quality,
          ),
        );

        if (processedBytes == null) {
          errors++;
          continue;
        }

        // Generate output filename
        final baseName = p.basenameWithoutExtension(item.name);
        final newBaseName = settings.renameSettings.generateName(
          originalNameWithoutExtension: baseName,
          index: i,
          date: item.dateModified,
        );
        final outFileName = '$newBaseName.$ext';

        if (settings.exportAsZip || kIsWeb) {
          zipFilesMap[outFileName] = processedBytes;
          exportedPaths.add(outFileName);
        } else {
          var destPath = p.join(targetDir, outFileName);
          if (!settings.overwriteExisting) {
            destPath = FileService.getUniqueFilePath(destPath);
          }
          final destFile = File(destPath);
          await destFile.writeAsBytes(processedBytes);
          exportedPaths.add(destPath);
        }
      } catch (e) {
        debugPrint('Error exporting ${item.name}: $e');
        errors++;
      }
    }

    // If zip mode
    if ((settings.exportAsZip || kIsWeb) && zipFilesMap.isNotEmpty && !kIsWeb) {
      try {
        final zipBytes = FileService.createZipArchive(zipFilesMap);
        final zipPath = p.join(targetDir, '${settings.subfolderName}.zip');
        await File(zipPath).writeAsBytes(zipBytes);
        exportedPaths.add(zipPath);
      } catch (e) {
        debugPrint('Error creating zip: $e');
      }
    }

    state = state.copyWith(
      isExporting: false,
      progress: 1.0,
      processedCount: items.length,
      errorCount: errors,
      exportedPaths: exportedPaths,
      completionMessage:
          'Successfully exported ${exportedPaths.length} images.' + (errors > 0 ? ' ($errors failed)' : ''),
    );

    return errors == 0;
  }
}

final exportProvider = NotifierProvider<ExportNotifier, ExportState>(ExportNotifier.new);
