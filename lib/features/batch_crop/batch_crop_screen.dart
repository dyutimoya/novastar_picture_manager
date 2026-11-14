import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/crop_settings.dart';
import '../../core/models/image_item.dart';
import '../../core/services/file_service.dart';
import '../../core/state/batch_crop_provider.dart';
import '../../core/state/library_provider.dart';
import 'widgets/batch_crop_review_dialog.dart';
import 'widgets/interactive_crop_view.dart';
import '../export/export_dialog.dart';

class BatchCropScreen extends ConsumerStatefulWidget {
  const BatchCropScreen({super.key});

  @override
  ConsumerState<BatchCropScreen> createState() => _BatchCropScreenState();
}

class _BatchCropScreenState extends ConsumerState<BatchCropScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();
  final _customWController = TextEditingController(text: '16');
  final _customHController = TextEditingController(text: '9');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _customWController.dispose();
    _customHController.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final notifier = ref.read(batchCropProvider.notifier);

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ) {
      notifier.undo();
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      notifier.redo();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      notifier.previousImage();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      notifier.nextImage();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      notifier.rotateCurrent(90);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.pop();
    }
  }

  void _openReview() {
    showDialog(
      context: context,
      builder: (ctx) => BatchCropReviewDialog(onProceedToExport: _openExport),
    );
  }

  void _openExport() {
    final state = ref.read(batchCropProvider);
    showDialog(
      context: context,
      builder: (ctx) =>
          ExportDialog(images: state.images, cropSettingsMap: state.settingsMap, isBatchCropWorkflow: true),
    );
  }

  ImageProvider _getImageProvider(ImageItem item) {
    if (item.bytes != null) {
      return MemoryImage(item.bytes!);
    }
    if (!kIsWeb && File(item.path).existsSync()) {
      return FileImage(File(item.path));
    }
    if (item.thumbnailBytes != null) {
      return MemoryImage(item.thumbnailBytes!);
    }
    return const AssetImage('assets/placeholder.png');
  }

  @override
  Widget build(BuildContext context) {
    final batchState = ref.watch(batchCropProvider);
    final curImage = batchState.currentImage;
    final curSettings = batchState.currentSettings;

    if (batchState.images.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF141419),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C1C24),
          title: const Text('Batch Crop'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.crop_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('No images loaded for batch cropping', style: TextStyle(color: Colors.white60, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Return to Library'),
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF141419),
        body: Row(
          children: [
            // Left sidebar: Filmstrip list & back button
            _buildLeftSidebar(context, batchState),

            // Center: Large Interactive Crop Workspace + Bottom Filmstrip
            Expanded(
              child: Column(
                children: [
                  // Top Editor Toolbar
                  _buildTopToolbar(context, batchState, curImage),

                  // Center Preview Area
                  Expanded(
                    child: Container(
                      color: const Color(0xFF101014),
                      padding: const EdgeInsets.all(16),
                      child: curImage != null
                          ? InteractiveCropView(
                              key: ValueKey(
                                '${curImage.id}_${curSettings.rotationDegrees}_${curSettings.fineAngle}_${curSettings.flipHorizontal}_${curSettings.flipVertical}',
                              ),
                              imageProvider: _getImageProvider(curImage),
                              imageWidth: curImage.width.toDouble(),
                              imageHeight: curImage.height.toDouble(),
                              settings: curSettings,
                              onRectChanged: (newRect) {
                                ref.read(batchCropProvider.notifier).updateCropRectOnly(newRect);
                              },
                              onRectChangeEnd: (finalRect) {
                                ref.read(batchCropProvider.notifier).commitCropRect(finalRect);
                              },
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  ),

                  // Bottom Filmstrip bar
                  _buildBottomFilmstrip(batchState),
                ],
              ),
            ),

            // Right panel: Crop & Transform sidebar
            _buildRightControlPanel(batchState, curSettings, curImage),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSidebar(BuildContext context, BatchCropState state) {
    return Container(
      width: 220,
      color: const Color(0xFF1B1B22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                  onPressed: () => context.pop(),
                  tooltip: 'Back to Library',
                ),
                const SizedBox(width: 4),
                const Text(
                  'Batch Photos',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.images.length}',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Photos list
          Expanded(
            child: ListView.builder(
              itemCount: state.images.length,
              itemBuilder: (context, index) {
                final item = state.images[index];
                final isSelected = index == state.currentIndex;
                final isCropped = (state.settingsMap[item.id] ?? item.cropSettings).isModified;

                return InkWell(
                  onTap: () => ref.read(batchCropProvider.notifier).selectImage(index),
                  child: Container(
                    color: isSelected ? Colors.blueAccent.withOpacity(0.18) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: item.thumbnailBytes != null
                                ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                                : Container(color: Colors.white10, child: const Icon(Icons.image, size: 16)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(item.dimensionsText, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ),
                        if (isCropped) const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: const Text('Add Images', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final newItems = await FileService.pickImages();
                      if (newItems.isNotEmpty) {
                        ref.read(libraryProvider.notifier).addImages(newItems);
                        ref.read(batchCropProvider.notifier).init([
                          ...state.images,
                          ...newItems,
                        ], initialIndex: state.currentIndex);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, BatchCropState state, ImageItem? curImage) {
    final notifier = ref.read(batchCropProvider.notifier);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1E1E26),
      child: Row(
        children: [
          // Current image label
          if (curImage != null) ...[
            Text(
              curImage.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              '${curImage.width} × ${curImage.height} px',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          const Spacer(),

          // Undo / Redo
          IconButton(
            icon: const Icon(Icons.undo, size: 18),
            color: state.canUndo ? Colors.white : Colors.white24,
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: state.canUndo ? notifier.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 18),
            color: state.canRedo ? Colors.white : Colors.white24,
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: state.canRedo ? notifier.redo : null,
          ),
          const SizedBox(width: 12),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
          const SizedBox(width: 12),

          // Copy / Paste settings
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            color: Colors.white70,
            tooltip: 'Copy Framing Settings',
            onPressed: () {
              notifier.copySettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Framing settings copied to clipboard'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.paste, size: 18),
            color: state.copiedSettings != null ? Colors.white70 : Colors.white24,
            tooltip: 'Paste Framing Settings',
            onPressed: state.copiedSettings != null ? notifier.pasteSettings : null,
          ),
          const SizedBox(width: 12),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
          const SizedBox(width: 12),

          // Reset button
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reset Frame', style: TextStyle(fontSize: 12)),
            onPressed: notifier.resetCurrent,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomFilmstrip(BatchCropState state) {
    final notifier = ref.read(batchCropProvider.notifier);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1B1B22),
      child: Row(
        children: [
          // Nav Prev
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: state.currentIndex > 0 ? notifier.previousImage : null,
          ),
          const SizedBox(width: 8),

          // Filmstrip thumbnails
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.images.length,
              itemBuilder: (context, index) {
                final item = state.images[index];
                final isSelected = index == state.currentIndex;

                return GestureDetector(
                  onTap: () => notifier.selectImage(index),
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSelected ? Colors.blueAccent : Colors.transparent, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        item.thumbnailBytes != null
                            ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                            : Container(color: Colors.white10),
                        if (isSelected) Container(color: Colors.blueAccent.withOpacity(0.15)),
                        Positioned(
                          bottom: 2,
                          left: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            color: Colors.black87,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 8),
          // Nav Next
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: state.currentIndex < state.images.length - 1 ? notifier.nextImage : null,
          ),

          const SizedBox(width: 16),
          // Counter info
          Text(
            '${state.currentIndex + 1} / ${state.images.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRightControlPanel(BatchCropState state, CropSettings settings, ImageItem? curImage) {
    final notifier = ref.read(batchCropProvider.notifier);

    return Container(
      width: 320,
      color: const Color(0xFF1E1E26),
      child: Column(
        children: [
          // Panel Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.crop, color: Colors.blueAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Crop & Transform',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
                  tooltip: 'Reset Frame',
                  onPressed: notifier.resetCurrent,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Controls Scrollable View
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Aspect Ratio Presets
                  const Text(
                    'Aspect Ratio',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildAspectChip('Free', CropAspectRatio.free, settings.aspectRatio == CropAspectRatio.free),
                      _buildAspectChip(
                        'Original',
                        CropAspectRatio.original,
                        settings.aspectRatio == CropAspectRatio.original,
                      ),
                      _buildAspectChip('1:1', CropAspectRatio.square, settings.aspectRatio == CropAspectRatio.square),
                      _buildAspectChip(
                        '4:3',
                        CropAspectRatio.ratio4_3,
                        settings.aspectRatio == CropAspectRatio.ratio4_3,
                      ),
                      _buildAspectChip(
                        '3:2',
                        CropAspectRatio.ratio3_2,
                        settings.aspectRatio == CropAspectRatio.ratio3_2,
                      ),
                      _buildAspectChip(
                        '16:9',
                        CropAspectRatio.ratio16_9,
                        settings.aspectRatio == CropAspectRatio.ratio16_9,
                      ),
                      _buildAspectChip(
                        '9:16',
                        CropAspectRatio.ratio9_16,
                        settings.aspectRatio == CropAspectRatio.ratio9_16,
                      ),
                      _buildAspectChip(
                        '5:4',
                        CropAspectRatio.ratio5_4,
                        settings.aspectRatio == CropAspectRatio.ratio5_4,
                      ),
                      _buildAspectChip(
                        '4:5',
                        CropAspectRatio.ratio4_5,
                        settings.aspectRatio == CropAspectRatio.ratio4_5,
                      ),
                      _buildAspectChip(
                        'Custom',
                        CropAspectRatio.custom,
                        settings.aspectRatio == CropAspectRatio.custom,
                      ),
                    ],
                  ),

                  // Custom ratio input
                  if (settings.aspectRatio == CropAspectRatio.custom) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customWController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Width',
                              labelStyle: const TextStyle(color: Colors.white60),
                              filled: true,
                              fillColor: const Color(0xFF2B2B36),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onChanged: (_) => _applyCustomRatio(),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('×', style: TextStyle(color: Colors.white54, fontSize: 18)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _customHController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: 'Height',
                              labelStyle: const TextStyle(color: Colors.white60),
                              filled: true,
                              fillColor: const Color(0xFF2B2B36),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onChanged: (_) => _applyCustomRatio(),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),

                  // Section: Smart Alignment & Focal Point
                  const Text(
                    'Smart Framing & Focal Point',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFocalChip(
                        'Auto Subject',
                        FocalPointAlign.auto,
                        settings.focalAlign == FocalPointAlign.auto,
                        Icons.center_focus_strong,
                      ),
                      _buildFocalChip(
                        'Center',
                        FocalPointAlign.center,
                        settings.focalAlign == FocalPointAlign.center,
                        Icons.filter_center_focus,
                      ),
                      _buildFocalChip(
                        'Top',
                        FocalPointAlign.top,
                        settings.focalAlign == FocalPointAlign.top,
                        Icons.vertical_align_top,
                      ),
                      _buildFocalChip(
                        'Bottom',
                        FocalPointAlign.bottom,
                        settings.focalAlign == FocalPointAlign.bottom,
                        Icons.vertical_align_bottom,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),

                  // Section: Fine Rotation & Tools
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rotation',
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      // Reset Button
                      IconButton(
                        icon: const Icon(Icons.restart_alt, size: 18),
                        color: (settings.rotationDegrees != 0 || settings.fineAngle != 0.0)
                            ? Colors.amberAccent
                            : Colors.white24,
                        tooltip: 'Reset Rotation to 0.0°',
                        onPressed: (settings.rotationDegrees != 0 || settings.fineAngle != 0.0)
                            ? () => notifier.resetRotation()
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Rotation Value Display with Up & Down Arrow Steppers
                  Row(
                    children: [
                      // Value Box (tap to edit exact degrees)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showCustomAngleDialog(context, notifier, settings.totalAngle),
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262632),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.screen_rotation, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${settings.totalAngle >= 0 ? '+' : ''}${settings.totalAngle.toStringAsFixed(1)}°',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      settings.totalAngle == 0 ? '0°' : (settings.totalAngle > 0 ? 'CW' : 'CCW'),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 12, color: Colors.white30),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Up and Down arrow buttons side of the value (1+++ / -1---)
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF262632),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Down Arrow (decrease 1°)
                            Tooltip(
                              message: 'Decrease 1° (-1°)',
                              child: InkWell(
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                onTap: () => notifier.stepFineRotation(-1.0),
                                child: const SizedBox(
                                  width: 36,
                                  height: 40,
                                  child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 24, color: Colors.white12),
                            // Up Arrow (increase 1° -> 1+++)
                            Tooltip(
                              message: 'Increase 1° (+1°)',
                              child: InkWell(
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                onTap: () => notifier.stepFineRotation(1.0),
                                child: const SizedBox(
                                  width: 36,
                                  height: 40,
                                  child: Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Slider for smooth continuous rotation across full angle spectrum (-180° to +180°)
                  Slider(
                    value: settings.fineAngle.clamp(-180.0, 180.0),
                    min: -180.0,
                    max: 180.0,
                    divisions: 360,
                    label: '${settings.fineAngle >= 0 ? '+' : ''}${settings.fineAngle.toStringAsFixed(1)}°',
                    onChanged: (val) => notifier.setFineAngle(val),
                  ),
                  const SizedBox(height: 4),

                  // Quick Step Increments: -90°, -5°, -1°, 0°, +1°, +5°, +90°
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildAngleStepChip(notifier, -90, '-90°'),
                      _buildAngleStepChip(notifier, -5, '-5°'),
                      _buildAngleStepChip(notifier, -1, '-1°'),
                      _buildAngleStepChip(notifier, 0, '0°', isReset: true),
                      _buildAngleStepChip(notifier, 1, '+1°'),
                      _buildAngleStepChip(notifier, 5, '+5°'),
                      _buildAngleStepChip(notifier, 90, '+90°'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Transform Tool Buttons (Rotate L/R, Flip H/V)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.rotate_left, size: 16),
                          label: const Text('90° L', style: TextStyle(fontSize: 11)),
                          onPressed: () => notifier.rotateCurrent(-90),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.rotate_right, size: 16),
                          label: const Text('90° R', style: TextStyle(fontSize: 11)),
                          onPressed: () => notifier.rotateCurrent(90),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: settings.flipHorizontal ? Colors.blueAccent : Colors.white24),
                            foregroundColor: settings.flipHorizontal ? Colors.blueAccent : Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.flip, size: 16),
                          label: const Text('Flip H', style: TextStyle(fontSize: 11)),
                          onPressed: notifier.flipHorizontal,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: settings.flipVertical ? Colors.blueAccent : Colors.white24),
                            foregroundColor: settings.flipVertical ? Colors.blueAccent : Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.flip, size: 16),
                          label: const Text('Flip V', style: TextStyle(fontSize: 11)),
                          onPressed: notifier.flipVertical,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),

                  // Section: Common Batch Cropping
                  const Text(
                    'Common Batch Actions',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E2E3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.copy_all, size: 16, color: Colors.blueAccent),
                      label: const Text('Apply Current Framing to All', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        notifier.applyCurrentToAll();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Applied framing to all ${state.images.length} images'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Reset All Frames', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        notifier.resetAll();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer action buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1B1B22),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueAccent),
                      foregroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Review Batch', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openReview,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: const Text('Export Batch Images', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _openExport,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyCustomRatio() {
    final w = double.tryParse(_customWController.text);
    final h = double.tryParse(_customHController.text);
    if (w != null && h != null && w > 0 && h > 0) {
      ref.read(batchCropProvider.notifier).setAspectRatio(CropAspectRatio.custom, customRatio: w / h);
    }
  }

  Widget _buildAspectChip(String label, CropAspectRatio ratio, bool isSelected) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: const Color(0xFF2A2A34),
      side: BorderSide.none,
      onSelected: (selected) {
        if (selected) {
          if (ratio == CropAspectRatio.custom) {
            _applyCustomRatio();
          } else {
            ref.read(batchCropProvider.notifier).setAspectRatio(ratio);
          }
        }
      },
    );
  }

  Widget _buildFocalChip(String label, FocalPointAlign align, bool isSelected, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white70),
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
      backgroundColor: isSelected ? Colors.blueAccent.withOpacity(0.4) : const Color(0xFF2A2A34),
      side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.white12),
      onPressed: () {
        ref.read(batchCropProvider.notifier).applyFocalAlign(align);
      },
    );
  }

  Widget _buildAngleStepChip(BatchCropNotifier notifier, num delta, String label, {bool isReset = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        if (isReset) {
          notifier.resetRotation();
        } else {
          notifier.stepFineRotation(delta.toDouble());
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isReset ? Colors.white10 : const Color(0xFF262632),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isReset ? Colors.amberAccent.withOpacity(0.4) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isReset ? Colors.amberAccent : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomAngleDialog(BuildContext context, BatchCropNotifier notifier, double currentAngle) async {
    final controller = TextEditingController(text: currentAngle.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22222C),
        title: const Text('Set Exact Rotation Angle', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Degrees (-180.0 to +180.0)',
            suffixText: '°',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) Navigator.of(ctx).pop(parsed);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null) Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      notifier.setFineAngle(result);
    }
  }
}
