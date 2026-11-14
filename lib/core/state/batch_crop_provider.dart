import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crop_settings.dart';
import '../models/image_item.dart';
import '../services/smart_crop_service.dart';
import '../services/file_service.dart';

class BatchCropState {
  final List<ImageItem> images;
  final int currentIndex;
  final Map<String, CropSettings> settingsMap;
  final Map<String, List<CropSettings>> undoStacks;
  final Map<String, List<CropSettings>> redoStacks;
  final CropSettings? copiedSettings;
  final bool isAnalyzingSubject;

  const BatchCropState({
    this.images = const [],
    this.currentIndex = 0,
    this.settingsMap = const {},
    this.undoStacks = const {},
    this.redoStacks = const {},
    this.copiedSettings,
    this.isAnalyzingSubject = false,
  });

  ImageItem? get currentImage =>
      (images.isNotEmpty && currentIndex >= 0 && currentIndex < images.length) ? images[currentIndex] : null;

  CropSettings get currentSettings {
    final cur = currentImage;
    if (cur == null) return CropSettings.initial;
    return settingsMap[cur.id] ?? cur.cropSettings;
  }

  bool get canUndo {
    final cur = currentImage;
    if (cur == null) return false;
    final stack = undoStacks[cur.id];
    return stack != null && stack.isNotEmpty;
  }

  bool get canRedo {
    final cur = currentImage;
    if (cur == null) return false;
    final stack = redoStacks[cur.id];
    return stack != null && stack.isNotEmpty;
  }

  BatchCropState copyWith({
    List<ImageItem>? images,
    int? currentIndex,
    Map<String, CropSettings>? settingsMap,
    Map<String, List<CropSettings>>? undoStacks,
    Map<String, List<CropSettings>>? redoStacks,
    CropSettings? copiedSettings,
    bool? isAnalyzingSubject,
  }) {
    return BatchCropState(
      images: images ?? this.images,
      currentIndex: currentIndex ?? this.currentIndex,
      settingsMap: settingsMap ?? this.settingsMap,
      undoStacks: undoStacks ?? this.undoStacks,
      redoStacks: redoStacks ?? this.redoStacks,
      copiedSettings: copiedSettings ?? this.copiedSettings,
      isAnalyzingSubject: isAnalyzingSubject ?? this.isAnalyzingSubject,
    );
  }
}

class BatchCropNotifier extends Notifier<BatchCropState> {
  @override
  BatchCropState build() => const BatchCropState();

  void init(List<ImageItem> items, {int initialIndex = 0}) {
    final map = <String, CropSettings>{};
    for (final item in items) {
      map[item.id] = item.cropSettings;
    }
    state = BatchCropState(
      images: items,
      currentIndex: initialIndex.clamp(0, items.isEmpty ? 0 : items.length - 1),
      settingsMap: map,
      undoStacks: {},
      redoStacks: {},
    );
  }

  void selectImage(int index) {
    if (index >= 0 && index < state.images.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void nextImage() {
    if (state.currentIndex < state.images.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void previousImage() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void _pushUndo(String id, CropSettings current) {
    final currentUndos = List<CropSettings>.from(state.undoStacks[id] ?? []);
    currentUndos.add(current);
    if (currentUndos.length > 50) currentUndos.removeAt(0);

    final newUndoStacks = Map<String, List<CropSettings>>.from(state.undoStacks);
    newUndoStacks[id] = currentUndos;

    final newRedoStacks = Map<String, List<CropSettings>>.from(state.redoStacks);
    newRedoStacks.remove(id); // Clear redos on new action

    state = state.copyWith(undoStacks: newUndoStacks, redoStacks: newRedoStacks);
  }

  void updateCurrentCrop(CropSettings newSettings) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = newSettings;
    state = state.copyWith(settingsMap: newMap);
  }

  void updateCropRectOnly(NormalizedRect newRect) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    final updated = current.copyWith(rect: newRect.clamp());
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void commitCropRect(NormalizedRect finalRect) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final updated = current.copyWith(rect: finalRect.clamp());
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void setAspectRatio(CropAspectRatio ratio, {double? customRatio}) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    double? targetRatio = ratio.ratioValue;
    if (ratio == CropAspectRatio.original) {
      targetRatio = cur.aspectRatio;
    } else if (ratio == CropAspectRatio.custom && customRatio != null) {
      targetRatio = customRatio;
    }

    NormalizedRect newRect = current.rect;
    if (targetRatio != null && targetRatio > 0) {
      newRect = SmartCropService.calculateFocalCrop(
        imageWidth: cur.width.toDouble(),
        imageHeight: cur.height.toDouble(),
        targetRatio: targetRatio,
        align: current.focalAlign,
      );
    }

    final updated = current.copyWith(
      aspectRatio: ratio,
      customRatio: customRatio ?? current.customRatio,
      rect: newRect,
    );

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void rotateCurrent(int deltaDegrees) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final newDeg = (current.rotationDegrees + deltaDegrees) % 360;
    final updated = current.copyWith(rotationDegrees: newDeg);

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void setFineAngle(double angle) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    final updated = current.withFineAngle(angle);

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void stepFineRotation(double delta) {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final updated = current.withSteppedRotation(delta);

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void resetRotation() {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final updated = current.withResetRotation();

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void flipHorizontal() {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final updated = current.copyWith(flipHorizontal: !current.flipHorizontal);
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void flipVertical() {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    _pushUndo(cur.id, current);

    final updated = current.copyWith(flipVertical: !current.flipVertical);
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void resetCurrent() {
    final cur = state.currentImage;
    if (cur == null) return;

    _pushUndo(cur.id, state.currentSettings);
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = CropSettings.initial;
    state = state.copyWith(settingsMap: newMap);
  }

  void resetAll() {
    final newMap = <String, CropSettings>{};
    for (final img in state.images) {
      newMap[img.id] = CropSettings.initial;
    }
    state = state.copyWith(settingsMap: newMap);
  }

  /// Copy current image's crop settings to clipboard
  void copySettings() {
    state = state.copyWith(copiedSettings: state.currentSettings);
  }

  /// Paste copied crop settings to current image
  void pasteSettings() {
    if (state.copiedSettings == null) return;
    final cur = state.currentImage;
    if (cur == null) return;

    _pushUndo(cur.id, state.currentSettings);
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = state.copiedSettings!;
    state = state.copyWith(settingsMap: newMap);
  }

  /// Apply current crop settings (or common aspect ratio) to ALL images in batch
  void applyCurrentToAll() {
    final curSettings = state.currentSettings;
    final newMap = Map<String, CropSettings>.from(state.settingsMap);

    for (final img in state.images) {
      double? targetRatio = curSettings.targetRatioValue;
      if (curSettings.aspectRatio == CropAspectRatio.original) {
        targetRatio = img.aspectRatio;
      }

      NormalizedRect rect = curSettings.rect;
      if (targetRatio != null && targetRatio > 0) {
        rect = SmartCropService.calculateFocalCrop(
          imageWidth: img.width.toDouble(),
          imageHeight: img.height.toDouble(),
          targetRatio: targetRatio,
          align: curSettings.focalAlign,
        );
      }

      newMap[img.id] = curSettings.copyWith(rect: rect);
    }
    state = state.copyWith(settingsMap: newMap);
  }

  /// Center crop all images with given aspect ratio
  void centerCropAll(CropAspectRatio ratio) {
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    for (final img in state.images) {
      double? targetRatio = ratio.ratioValue;
      if (ratio == CropAspectRatio.original) {
        targetRatio = img.aspectRatio;
      }
      if (targetRatio != null && targetRatio > 0) {
        final rect = SmartCropService.calculateFocalCrop(
          imageWidth: img.width.toDouble(),
          imageHeight: img.height.toDouble(),
          targetRatio: targetRatio,
          align: FocalPointAlign.center,
        );
        newMap[img.id] = (newMap[img.id] ?? CropSettings.initial).copyWith(
          aspectRatio: ratio,
          rect: rect,
          focalAlign: FocalPointAlign.center,
        );
      }
    }
    state = state.copyWith(settingsMap: newMap);
  }

  /// Smart focal align for current image (Center, Top, Auto Subject, etc.)
  Future<void> applyFocalAlign(FocalPointAlign align) async {
    final cur = state.currentImage;
    if (cur == null) return;

    final current = state.currentSettings;
    double? targetRatio = current.targetRatioValue ?? cur.aspectRatio;

    NormalizedRect newRect;
    if (align == FocalPointAlign.auto) {
      state = state.copyWith(isAnalyzingSubject: true);
      final bytes = await FileService.getImageBytes(cur) ?? cur.thumbnailBytes;
      state = state.copyWith(isAnalyzingSubject: false);

      if (bytes != null) {
        final focalPoint = await SmartCropService.detectSubjectFocalPoint(bytes);
        newRect = SmartCropService.calculateFocalCrop(
          imageWidth: cur.width.toDouble(),
          imageHeight: cur.height.toDouble(),
          targetRatio: targetRatio,
          align: FocalPointAlign.auto,
          customFocalPoint: focalPoint,
        );
      } else {
        newRect = SmartCropService.calculateFocalCrop(
          imageWidth: cur.width.toDouble(),
          imageHeight: cur.height.toDouble(),
          targetRatio: targetRatio,
          align: FocalPointAlign.center,
        );
      }
    } else {
      newRect = SmartCropService.calculateFocalCrop(
        imageWidth: cur.width.toDouble(),
        imageHeight: cur.height.toDouble(),
        targetRatio: targetRatio,
        align: align,
      );
    }

    _pushUndo(cur.id, current);
    final updated = current.copyWith(rect: newRect, focalAlign: align);
    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = updated;
    state = state.copyWith(settingsMap: newMap);
  }

  void undo() {
    final cur = state.currentImage;
    if (cur == null) return;

    final undos = state.undoStacks[cur.id];
    if (undos == null || undos.isEmpty) return;

    final previous = undos.last;
    final newUndos = List<CropSettings>.from(undos)..removeLast();

    final current = state.currentSettings;
    final redos = List<CropSettings>.from(state.redoStacks[cur.id] ?? [])..add(current);

    final newUndoStacks = Map<String, List<CropSettings>>.from(state.undoStacks);
    newUndoStacks[cur.id] = newUndos;

    final newRedoStacks = Map<String, List<CropSettings>>.from(state.redoStacks);
    newRedoStacks[cur.id] = redos;

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = previous;

    state = state.copyWith(settingsMap: newMap, undoStacks: newUndoStacks, redoStacks: newRedoStacks);
  }

  void redo() {
    final cur = state.currentImage;
    if (cur == null) return;

    final redos = state.redoStacks[cur.id];
    if (redos == null || redos.isEmpty) return;

    final next = redos.last;
    final newRedos = List<CropSettings>.from(redos)..removeLast();

    final current = state.currentSettings;
    final undos = List<CropSettings>.from(state.undoStacks[cur.id] ?? [])..add(current);

    final newUndoStacks = Map<String, List<CropSettings>>.from(state.undoStacks);
    newUndoStacks[cur.id] = undos;

    final newRedoStacks = Map<String, List<CropSettings>>.from(state.redoStacks);
    newRedoStacks[cur.id] = newRedos;

    final newMap = Map<String, CropSettings>.from(state.settingsMap);
    newMap[cur.id] = next;

    state = state.copyWith(settingsMap: newMap, undoStacks: newUndoStacks, redoStacks: newRedoStacks);
  }
}

final batchCropProvider = NotifierProvider<BatchCropNotifier, BatchCropState>(BatchCropNotifier.new);
