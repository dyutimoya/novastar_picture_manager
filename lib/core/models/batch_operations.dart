import 'image_adjustments.dart';

enum ImageOutputFormat {
  original('Keep Original', ''),
  jpg('JPEG', 'jpg'),
  png('PNG', 'png'),
  webp('WebP', 'webp'),
  bmp('BMP', 'bmp'),
  tiff('TIFF', 'tiff');

  final String label;
  final String extension;
  const ImageOutputFormat(this.label, this.extension);
}

enum ResizeMode {
  exact('Exact Dimensions'),
  percentage('Percentage'),
  fitInside('Fit Inside'),
  fillCrop('Fill & Crop'),
  maxWidth('Limit Max Width'),
  maxHeight('Limit Max Height');

  final String label;
  const ResizeMode(this.label);
}

class ResizeSettings {
  final ResizeMode mode;
  final int targetWidth;
  final int targetHeight;
  final int percentage; // 1 to 500%
  final bool maintainAspectRatio;

  const ResizeSettings({
    this.mode = ResizeMode.percentage,
    this.targetWidth = 1920,
    this.targetHeight = 1080,
    this.percentage = 100,
    this.maintainAspectRatio = true,
  });

  (int, int) calculateDimensions(int originalWidth, int originalHeight) {
    if (originalWidth <= 0 || originalHeight <= 0) {
      return (targetWidth, targetHeight);
    }
    switch (mode) {
      case ResizeMode.percentage:
        final factor = percentage / 100.0;
        return ((originalWidth * factor).round(), (originalHeight * factor).round());

      case ResizeMode.exact:
        return (targetWidth, targetHeight);

      case ResizeMode.maxWidth:
        if (originalWidth <= targetWidth) return (originalWidth, originalHeight);
        final ratio = targetWidth / originalWidth;
        return (targetWidth, (originalHeight * ratio).round());

      case ResizeMode.maxHeight:
        if (originalHeight <= targetHeight) return (originalWidth, originalHeight);
        final ratio = targetHeight / originalHeight;
        return ((originalWidth * ratio).round(), targetHeight);

      case ResizeMode.fitInside:
        final widthRatio = targetWidth / originalWidth;
        final heightRatio = targetHeight / originalHeight;
        final factor = widthRatio < heightRatio ? widthRatio : heightRatio;
        return ((originalWidth * factor).round(), (originalHeight * factor).round());

      case ResizeMode.fillCrop:
        return (targetWidth, targetHeight);
    }
  }

  ResizeSettings copyWith({
    ResizeMode? mode,
    int? targetWidth,
    int? targetHeight,
    int? percentage,
    bool? maintainAspectRatio,
  }) {
    return ResizeSettings(
      mode: mode ?? this.mode,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      percentage: percentage ?? this.percentage,
      maintainAspectRatio: maintainAspectRatio ?? this.maintainAspectRatio,
    );
  }
}

enum NamingMode {
  original('Keep Original Name'),
  prefix('Add Prefix'),
  suffix('Add Suffix'),
  sequential('Sequential (e.g. photo_001)'),
  replace('Replace Text'),
  customPattern('Custom Pattern');

  final String label;
  const NamingMode(this.label);
}

class RenameSettings {
  final NamingMode mode;
  final String prefix;
  final String suffix;
  final String baseName;
  final int startNumber;
  final int digitPadding; // e.g. 3 => 001, 002
  final String pattern; // e.g. {name}_{index}_{date}
  final String findText;
  final String replaceText;

  const RenameSettings({
    this.mode = NamingMode.original,
    this.prefix = '',
    this.suffix = '_edited',
    this.baseName = 'image',
    this.startNumber = 1,
    this.digitPadding = 3,
    this.pattern = '{name}_{index}',
    this.findText = '',
    this.replaceText = '',
  });

  String generateName({required String originalNameWithoutExtension, required int index, required DateTime date}) {
    switch (mode) {
      case NamingMode.original:
        return originalNameWithoutExtension;
      case NamingMode.prefix:
        return '$prefix$originalNameWithoutExtension';
      case NamingMode.suffix:
        return '$originalNameWithoutExtension$suffix';
      case NamingMode.sequential:
        final numStr = (startNumber + index).toString().padLeft(digitPadding, '0');
        return '${baseName}_$numStr';
      case NamingMode.replace:
        if (findText.isEmpty) return originalNameWithoutExtension;
        return originalNameWithoutExtension.replaceAll(findText, replaceText);
      case NamingMode.customPattern:
        final numStr = (startNumber + index).toString().padLeft(digitPadding, '0');
        final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        return pattern
            .replaceAll('{name}', originalNameWithoutExtension)
            .replaceAll('{index}', numStr)
            .replaceAll('{date}', dateStr);
    }
  }

  RenameSettings copyWith({
    NamingMode? mode,
    String? prefix,
    String? suffix,
    String? baseName,
    int? startNumber,
    int? digitPadding,
    String? pattern,
    String? findText,
    String? replaceText,
  }) {
    return RenameSettings(
      mode: mode ?? this.mode,
      prefix: prefix ?? this.prefix,
      suffix: suffix ?? this.suffix,
      baseName: baseName ?? this.baseName,
      startNumber: startNumber ?? this.startNumber,
      digitPadding: digitPadding ?? this.digitPadding,
      pattern: pattern ?? this.pattern,
      findText: findText ?? this.findText,
      replaceText: replaceText ?? this.replaceText,
    );
  }
}

class ExportSettings {
  final ImageOutputFormat format;
  final int quality; // 1 - 100
  final String outputDirectory;
  final bool createSubfolder;
  final String subfolderName;
  final bool overwriteExisting;
  final ResizeSettings resizeSettings;
  final RenameSettings renameSettings;
  final bool applyCrop;
  final bool applyAdjustments;
  final bool exportAsZip; // for Web or portable package
  final WatermarkSettings? batchWatermark;
  final ImageFilterType? batchFilter;
  final BorderSettings? batchBorder;

  const ExportSettings({
    this.format = ImageOutputFormat.original,
    this.quality = 90,
    this.outputDirectory = '',
    this.createSubfolder = false,
    this.subfolderName = 'PictureManager_Export',
    this.overwriteExisting = false,
    this.resizeSettings = const ResizeSettings(),
    this.renameSettings = const RenameSettings(),
    this.applyCrop = true,
    this.applyAdjustments = true,
    this.exportAsZip = false,
    this.batchWatermark,
    this.batchFilter,
    this.batchBorder,
  });

  ExportSettings copyWith({
    ImageOutputFormat? format,
    int? quality,
    String? outputDirectory,
    bool? createSubfolder,
    String? subfolderName,
    bool? overwriteExisting,
    ResizeSettings? resizeSettings,
    RenameSettings? renameSettings,
    bool? applyCrop,
    bool? applyAdjustments,
    bool? exportAsZip,
    WatermarkSettings? batchWatermark,
    ImageFilterType? batchFilter,
    BorderSettings? batchBorder,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      createSubfolder: createSubfolder ?? this.createSubfolder,
      subfolderName: subfolderName ?? this.subfolderName,
      overwriteExisting: overwriteExisting ?? this.overwriteExisting,
      resizeSettings: resizeSettings ?? this.resizeSettings,
      renameSettings: renameSettings ?? this.renameSettings,
      applyCrop: applyCrop ?? this.applyCrop,
      applyAdjustments: applyAdjustments ?? this.applyAdjustments,
      exportAsZip: exportAsZip ?? this.exportAsZip,
      batchWatermark: batchWatermark ?? this.batchWatermark,
      batchFilter: batchFilter ?? this.batchFilter,
      batchBorder: batchBorder ?? this.batchBorder,
    );
  }
}
