import 'dart:ui';

enum CropAspectRatio {
  free('Free', null),
  original('Original', -1),
  square('1:1 Square', 1.0),
  ratio4_3('4:3', 4.0 / 3.0),
  ratio3_2('3:2', 3.0 / 2.0),
  ratio16_9('16:9', 16.0 / 9.0),
  ratio9_16('9:16', 9.0 / 16.0),
  ratio5_4('5:4', 5.0 / 4.0),
  ratio4_5('4:5', 4.0 / 5.0),
  custom('Custom', 0.0);

  final String label;
  final double? ratioValue; // width / height

  const CropAspectRatio(this.label, this.ratioValue);
}

enum FocalPointAlign {
  center('Center'),
  top('Top'),
  bottom('Bottom'),
  left('Left'),
  right('Right'),
  auto('Smart Auto');

  final String label;
  const FocalPointAlign(this.label);
}

class NormalizedRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormalizedRect({required this.left, required this.top, required this.width, required this.height});

  static const full = NormalizedRect(left: 0.0, top: 0.0, width: 1.0, height: 1.0);

  double get right => (left + width).clamp(0.0, 1.0);
  double get bottom => (top + height).clamp(0.0, 1.0);

  NormalizedRect clamp() {
    final cLeft = left.clamp(0.0, 1.0);
    final cTop = top.clamp(0.0, 1.0);
    final cWidth = width.clamp(0.05, 1.0 - cLeft);
    final cHeight = height.clamp(0.05, 1.0 - cTop);
    return NormalizedRect(left: cLeft, top: cTop, width: cWidth, height: cHeight);
  }

  Rect toPixelRect(double imgWidth, double imgHeight) {
    return Rect.fromLTWH(left * imgWidth, top * imgHeight, width * imgWidth, height * imgHeight);
  }

  static NormalizedRect fromPixelRect(Rect rect, double imgWidth, double imgHeight) {
    if (imgWidth <= 0 || imgHeight <= 0) return full;
    return NormalizedRect(
      left: (rect.left / imgWidth).clamp(0.0, 1.0),
      top: (rect.top / imgHeight).clamp(0.0, 1.0),
      width: (rect.width / imgWidth).clamp(0.01, 1.0),
      height: (rect.height / imgHeight).clamp(0.01, 1.0),
    ).clamp();
  }

  Map<String, dynamic> toJson() => {'left': left, 'top': top, 'width': width, 'height': height};

  factory NormalizedRect.fromJson(Map<String, dynamic> json) => NormalizedRect(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  NormalizedRect copyWith({double? left, double? top, double? width, double? height}) {
    return NormalizedRect(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NormalizedRect &&
          runtimeType == other.runtimeType &&
          (left - other.left).abs() < 1e-5 &&
          (top - other.top).abs() < 1e-5 &&
          (width - other.width).abs() < 1e-5 &&
          (height - other.height).abs() < 1e-5;

  @override
  int get hashCode =>
      Object.hash(left.toStringAsFixed(4), top.toStringAsFixed(4), width.toStringAsFixed(4), height.toStringAsFixed(4));
}

class CropSettings {
  final NormalizedRect rect;
  final CropAspectRatio aspectRatio;
  final double customRatio; // e.g. 1.777 if custom
  final int rotationDegrees; // 0, 90, 180, 270
  final double fineAngle; // -45 to +45
  final bool flipHorizontal;
  final bool flipVertical;
  final FocalPointAlign focalAlign;

  const CropSettings({
    this.rect = NormalizedRect.full,
    this.aspectRatio = CropAspectRatio.free,
    this.customRatio = 1.0,
    this.rotationDegrees = 0,
    this.fineAngle = 0.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.focalAlign = FocalPointAlign.center,
  });

  static const initial = CropSettings();

  /// Total rotation angle in degrees combining 90-degree steps and fine rotation
  double get totalAngle => (rotationDegrees + fineAngle);

  bool get isModified =>
      rect != NormalizedRect.full ||
      aspectRatio != CropAspectRatio.free ||
      rotationDegrees != 0 ||
      fineAngle != 0.0 ||
      flipHorizontal ||
      flipVertical;

  double? get targetRatioValue {
    if (aspectRatio == CropAspectRatio.free) return null;
    if (aspectRatio == CropAspectRatio.custom) return customRatio;
    return aspectRatio.ratioValue;
  }

  CropSettings withFineAngle(double angle) {
    return copyWith(fineAngle: double.parse(angle.toStringAsFixed(1)));
  }

  CropSettings withSteppedRotation(double delta) {
    final newAngle = double.parse((fineAngle + delta).toStringAsFixed(1));
    return copyWith(fineAngle: newAngle);
  }

  CropSettings withResetRotation() {
    return copyWith(rotationDegrees: 0, fineAngle: 0.0);
  }

  CropSettings copyWith({
    NormalizedRect? rect,
    CropAspectRatio? aspectRatio,
    double? customRatio,
    int? rotationDegrees,
    double? fineAngle,
    bool? flipHorizontal,
    bool? flipVertical,
    FocalPointAlign? focalAlign,
  }) {
    return CropSettings(
      rect: rect ?? this.rect,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      customRatio: customRatio ?? this.customRatio,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      fineAngle: fineAngle ?? this.fineAngle,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      focalAlign: focalAlign ?? this.focalAlign,
    );
  }

  Map<String, dynamic> toJson() => {
    'rect': rect.toJson(),
    'aspectRatio': aspectRatio.name,
    'customRatio': customRatio,
    'rotationDegrees': rotationDegrees,
    'fineAngle': fineAngle,
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
    'focalAlign': focalAlign.name,
  };

  factory CropSettings.fromJson(Map<String, dynamic> json) {
    return CropSettings(
      rect: NormalizedRect.fromJson(json['rect'] as Map<String, dynamic>),
      aspectRatio: CropAspectRatio.values.firstWhere(
        (e) => e.name == json['aspectRatio'],
        orElse: () => CropAspectRatio.free,
      ),
      customRatio: (json['customRatio'] as num?)?.toDouble() ?? 1.0,
      rotationDegrees: json['rotationDegrees'] as int? ?? 0,
      fineAngle: (json['fineAngle'] as num?)?.toDouble() ?? 0.0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
      focalAlign: FocalPointAlign.values.firstWhere(
        (e) => e.name == json['focalAlign'],
        orElse: () => FocalPointAlign.center,
      ),
    );
  }
}
