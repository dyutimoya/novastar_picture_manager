enum ImageFilterType {
  none('None'),
  grayscale('Black & White'),
  sepia('Sepia Vintage'),
  vignette('Vignette'),
  invert('Negative Invert'),
  sketch('Pencil Sketch'),
  emboss('Emboss Relief'),
  pixelate('Pixelate'),
  blur('Soft Blur'),
  autoLevels('Auto Levels (Stretch)');

  final String label;
  const ImageFilterType(this.label);
}

enum WatermarkPosition {
  bottomRight('Bottom Right'),
  bottomLeft('Bottom Left'),
  topRight('Top Right'),
  topLeft('Top Left'),
  center('Center');

  final String label;
  const WatermarkPosition(this.label);
}

class WatermarkSettings {
  final bool enabled;
  final String text;
  final int fontSize; // 14, 24, 48
  final String colorHex;
  final double opacity; // 0.1 to 1.0
  final WatermarkPosition position;

  const WatermarkSettings({
    this.enabled = false,
    this.text = 'Novastar Picture Manager',
    this.fontSize = 24,
    this.colorHex = '#FFFFFF',
    this.opacity = 0.8,
    this.position = WatermarkPosition.bottomRight,
  });

  WatermarkSettings copyWith({
    bool? enabled,
    String? text,
    int? fontSize,
    String? colorHex,
    double? opacity,
    WatermarkPosition? position,
  }) {
    return WatermarkSettings(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      colorHex: colorHex ?? this.colorHex,
      opacity: opacity ?? this.opacity,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'text': text,
    'fontSize': fontSize,
    'colorHex': colorHex,
    'opacity': opacity,
    'position': position.name,
  };

  factory WatermarkSettings.fromJson(Map<String, dynamic> json) => WatermarkSettings(
    enabled: json['enabled'] as bool? ?? false,
    text: json['text'] as String? ?? 'Novastar Picture Manager',
    fontSize: json['fontSize'] as int? ?? 24,
    colorHex: json['colorHex'] as String? ?? '#FFFFFF',
    opacity: (json['opacity'] as num?)?.toDouble() ?? 0.8,
    position: WatermarkPosition.values.firstWhere(
      (e) => e.name == json['position'],
      orElse: () => WatermarkPosition.bottomRight,
    ),
  );
}

class BorderSettings {
  final bool enabled;
  final int thickness; // 0 to 100 px
  final String colorHex;

  const BorderSettings({this.enabled = false, this.thickness = 16, this.colorHex = '#FFFFFF'});

  BorderSettings copyWith({bool? enabled, int? thickness, String? colorHex}) {
    return BorderSettings(
      enabled: enabled ?? this.enabled,
      thickness: thickness ?? this.thickness,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'thickness': thickness, 'colorHex': colorHex};

  factory BorderSettings.fromJson(Map<String, dynamic> json) => BorderSettings(
    enabled: json['enabled'] as bool? ?? false,
    thickness: json['thickness'] as int? ?? 16,
    colorHex: json['colorHex'] as String? ?? '#FFFFFF',
  );
}

class ImageAdjustments {
  final double brightness; // -1.0 to +1.0 (default 0.0)
  final double contrast; // 0.0 to 2.0 (default 1.0)
  final double saturation; // 0.0 to 2.0 (default 1.0)
  final double hue; // -180.0 to +180.0 (default 0.0)
  final double temperature; // -1.0 (cool) to +1.0 (warm) (default 0.0)
  final double tint; // -1.0 (green) to +1.0 (magenta) (default 0.0)
  final double highlights; // -1.0 to +1.0 (default 0.0)
  final double shadows; // -1.0 to +1.0 (default 0.0)
  final double sharpness; // 0.0 to 2.0 (default 0.0)
  final double gamma; // 0.2 to 3.0 (default 1.0)
  final ImageFilterType filter;
  final WatermarkSettings watermark;
  final BorderSettings border;

  const ImageAdjustments({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.hue = 0.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.sharpness = 0.0,
    this.gamma = 1.0,
    this.filter = ImageFilterType.none,
    this.watermark = const WatermarkSettings(),
    this.border = const BorderSettings(),
  });

  static const initial = ImageAdjustments();

  bool get isModified =>
      brightness != 0.0 ||
      contrast != 1.0 ||
      saturation != 1.0 ||
      hue != 0.0 ||
      temperature != 0.0 ||
      tint != 0.0 ||
      highlights != 0.0 ||
      shadows != 0.0 ||
      sharpness != 0.0 ||
      gamma != 1.0 ||
      filter != ImageFilterType.none ||
      watermark.enabled ||
      border.enabled;

  ImageAdjustments copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? temperature,
    double? tint,
    double? highlights,
    double? shadows,
    double? sharpness,
    double? gamma,
    ImageFilterType? filter,
    WatermarkSettings? watermark,
    BorderSettings? border,
  }) {
    return ImageAdjustments(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      sharpness: sharpness ?? this.sharpness,
      gamma: gamma ?? this.gamma,
      filter: filter ?? this.filter,
      watermark: watermark ?? this.watermark,
      border: border ?? this.border,
    );
  }

  Map<String, dynamic> toJson() => {
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
    'hue': hue,
    'temperature': temperature,
    'tint': tint,
    'highlights': highlights,
    'shadows': shadows,
    'sharpness': sharpness,
    'gamma': gamma,
    'filter': filter.name,
    'watermark': watermark.toJson(),
    'border': border.toJson(),
  };

  factory ImageAdjustments.fromJson(Map<String, dynamic> json) => ImageAdjustments(
    brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
    contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
    saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
    hue: (json['hue'] as num?)?.toDouble() ?? 0.0,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
    tint: (json['tint'] as num?)?.toDouble() ?? 0.0,
    highlights: (json['highlights'] as num?)?.toDouble() ?? 0.0,
    shadows: (json['shadows'] as num?)?.toDouble() ?? 0.0,
    sharpness: (json['sharpness'] as num?)?.toDouble() ?? 0.0,
    gamma: (json['gamma'] as num?)?.toDouble() ?? 1.0,
    filter: ImageFilterType.values.firstWhere((e) => e.name == json['filter'], orElse: () => ImageFilterType.none),
    watermark: json['watermark'] != null
        ? WatermarkSettings.fromJson(json['watermark'] as Map<String, dynamic>)
        : const WatermarkSettings(),
    border: json['border'] != null
        ? BorderSettings.fromJson(json['border'] as Map<String, dynamic>)
        : const BorderSettings(),
  );
}
