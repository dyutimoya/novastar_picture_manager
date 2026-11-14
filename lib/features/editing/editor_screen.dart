import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/batch_operations.dart';
import '../../core/models/crop_settings.dart';
import '../../core/models/image_adjustments.dart';
import '../../core/models/image_item.dart';
import '../../core/services/file_service.dart';
import '../../core/services/image_processor.dart';
import '../../core/state/library_provider.dart';
import '../export/export_dialog.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final ImageItem item;

  const EditorScreen({super.key, required this.item});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> with SingleTickerProviderStateMixin {
  late ImageAdjustments _adjustments;
  late CropSettings _cropSettings;
  Uint8List? _highResBaseBytes;
  Uint8List? _previewBytes;
  bool _isLoadingBase = true;
  bool _isProcessingPreview = false;
  bool _needsReprocess = false;
  bool _showOriginal = false;
  Timer? _debounceTimer;

  // Zoom and Pan controller
  final TransformationController _transformationController = TransformationController();
  double _currentZoom = 1.0;

  late TabController _tabController;
  final _watermarkTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adjustments = widget.item.adjustments;
    _cropSettings = widget.item.cropSettings;
    _tabController = TabController(length: 4, vsync: this);
    _watermarkTextController.text = _adjustments.watermark.text;
    _loadHighResBase();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _transformationController.dispose();
    _tabController.dispose();
    _watermarkTextController.dispose();
    super.dispose();
  }

  Future<void> _loadHighResBase() async {
    setState(() => _isLoadingBase = true);
    final rawBytes = await FileService.getImageBytes(widget.item) ?? widget.item.thumbnailBytes;
    if (rawBytes != null) {
      // Create high-resolution lossless base (up to 2048px for instant, pixel-perfect updates)
      final base = await ImageProcessor.createHighResPreviewBase(rawBytes, maxDimension: 2048);
      _highResBaseBytes = base ?? rawBytes;
    }
    if (mounted) {
      setState(() => _isLoadingBase = false);
      _generateLivePreview();
    }
  }

  Future<void> _generateLivePreview() async {
    if (_highResBaseBytes == null) {
      await _loadHighResBase();
      return;
    }
    if (_isProcessingPreview) {
      _needsReprocess = true;
      return;
    }
    _isProcessingPreview = true;
    _needsReprocess = false;

    final processed = await ImageProcessor.processImage(
      ProcessTaskParams(
        rawBytes: _highResBaseBytes!,
        cropSettings: _cropSettings,
        adjustments: _adjustments,
        format: ImageOutputFormat.png, // 100% Lossless, maximum fidelity
        quality: 98,
      ),
    );

    if (mounted && processed != null) {
      setState(() {
        _previewBytes = processed;
      });
    }
    _isProcessingPreview = false;
    if (_needsReprocess && mounted) {
      _generateLivePreview();
    }
  }

  void _updateAdjustments(ImageAdjustments newAdj) {
    setState(() {
      _adjustments = newAdj;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 25), () {
      _generateLivePreview();
    });
  }

  void _resetAdjustments() {
    _watermarkTextController.text = 'Novastar Picture Manager';
    _updateAdjustments(ImageAdjustments.initial);
  }

  void _applyAutoCorrect() {
    _updateAdjustments(_adjustments.copyWith(contrast: 1.15, saturation: 1.12, brightness: 0.05, gamma: 1.05));
  }

  void _zoomIn() {
    final newZoom = (_currentZoom * 1.3).clamp(0.2, 8.0);
    _setZoom(newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom / 1.3).clamp(0.2, 8.0);
    _setZoom(newZoom);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _currentZoom = 1.0);
  }

  void _setZoom(double zoom) {
    _transformationController.value = Matrix4.identity()..scale(zoom);
    setState(() => _currentZoom = zoom);
  }

  void _saveChanges() {
    final updated = widget.item.copyWith(adjustments: _adjustments, cropSettings: _cropSettings);
    ref.read(libraryProvider.notifier).updateImage(updated);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Changes saved to image!'), duration: Duration(seconds: 1)));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E26),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(widget.item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.amberAccent),
            tooltip: 'Auto-Correct',
            onPressed: _applyAutoCorrect,
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reset All', onPressed: _resetAdjustments),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save'),
            onPressed: _saveChanges,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
            ),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Export'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => ExportDialog(
                  images: [widget.item.copyWith(adjustments: _adjustments, cropSettings: _cropSettings)],
                  cropSettingsMap: {widget.item.id: _cropSettings},
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Center Image Preview with Zoom & High Quality
          Expanded(child: _buildPreviewArea()),

          // Right Sidebar with Tabs
          Container(
            width: 340,
            color: const Color(0xFF1E1E26),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blueAccent,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.white60,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.tune, size: 18), text: 'Adjust'),
                    Tab(icon: Icon(Icons.filter, size: 18), text: 'Filters'),
                    Tab(icon: Icon(Icons.branding_watermark, size: 18), text: 'Watermark'),
                    Tab(icon: Icon(Icons.crop_square, size: 18), text: 'Borders'),
                  ],
                ),
                const Divider(height: 1, color: Colors.white12),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildAdjustmentsTab(), _buildFiltersTab(), _buildWatermarkTab(), _buildBordersTab()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_isLoadingBase && _previewBytes == null && _highResBaseBytes == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 14),
            Text('Loading high-resolution image...', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    final displayBytes = _showOriginal
        ? _highResBaseBytes
        : (_previewBytes ?? _highResBaseBytes ?? widget.item.thumbnailBytes);

    return Container(
      color: const Color(0xFF101014),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive Zoom & Pan Canvas
          if (displayBytes != null)
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.2,
              maxScale: 8.0,
              boundaryMargin: const EdgeInsets.all(120),
              clipBehavior: Clip.none,
              onInteractionUpdate: (details) {
                final scale = _transformationController.value.getMaxScaleOnAxis();
                setState(() => _currentZoom = scale);
              },
              child: Center(
                child: GestureDetector(
                  onDoubleTap: () {
                    if (_currentZoom > 1.1) {
                      _resetZoom();
                    } else {
                      _setZoom(2.0);
                    }
                  },
                  child: Image.memory(displayBytes, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 14),
                  Text('Loading high-resolution image...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),

          // Top Info Pill
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.dimensionsText,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Colors.white24),
                  const SizedBox(width: 8),
                  Text(
                    widget.item.extension.toUpperCase(),
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Compare Badge Indicator
          if (_showOriginal)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'ORIGINAL (BEFORE)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Floating Zoom & Compare Toolbar
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E28).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Before / After Compare Button
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _showOriginal = !_showOriginal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showOriginal ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _showOriginal ? Colors.amberAccent : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showOriginal ? Icons.visibility : Icons.visibility_outlined,
                              size: 16,
                              color: _showOriginal ? Colors.amberAccent : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showOriginal ? 'Original' : 'Compare',
                              style: TextStyle(
                                fontSize: 12,
                                color: _showOriginal ? Colors.amberAccent : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),
                    const SizedBox(height: 18, child: VerticalDivider(color: Colors.white24, width: 1)),
                    const SizedBox(width: 6),

                    // Zoom Out
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                      tooltip: 'Zoom Out (-)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _zoomOut,
                    ),

                    // Zoom Slider
                    SizedBox(
                      width: 100,
                      child: Slider(
                        value: _currentZoom.clamp(0.2, 5.0),
                        min: 0.2,
                        max: 5.0,
                        onChanged: (val) => _setZoom(val),
                      ),
                    ),

                    // Zoom In
                    IconButton(
                      icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                      tooltip: 'Zoom In (+)',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: _zoomIn,
                    ),

                    const SizedBox(width: 4),

                    // Percentage readout
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(_currentZoom * 100).toInt()}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                    const SizedBox(height: 18, child: VerticalDivider(color: Colors.white24, width: 1)),
                    const SizedBox(width: 6),

                    // Reset / Fit
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _resetZoom,
                      child: const Text('Fit', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ),

                    const SizedBox(width: 4),

                    // 1:1 Pixel
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _setZoom(1.0),
                      child: const Text('1:1', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ),

                    if (_isProcessingPreview) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSlider(
            label: 'Brightness',
            value: _adjustments.brightness,
            min: -1.0,
            max: 1.0,
            defaultValue: 0.0,
            displayFormat: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(brightness: v)),
          ),
          _buildSlider(
            label: 'Contrast',
            value: _adjustments.contrast,
            min: 0.0,
            max: 2.0,
            defaultValue: 1.0,
            displayFormat: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(contrast: v)),
          ),
          _buildSlider(
            label: 'Saturation',
            value: _adjustments.saturation,
            min: 0.0,
            max: 2.0,
            defaultValue: 1.0,
            displayFormat: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(saturation: v)),
          ),
          _buildSlider(
            label: 'Warmth (Temp)',
            value: _adjustments.temperature,
            min: -1.0,
            max: 1.0,
            defaultValue: 0.0,
            displayFormat: (v) =>
                v > 0 ? '+${(v * 100).toStringAsFixed(0)} Warm' : '${(v * 100).toStringAsFixed(0)} Cool',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(temperature: v)),
          ),
          _buildSlider(
            label: 'Tint',
            value: _adjustments.tint,
            min: -1.0,
            max: 1.0,
            defaultValue: 0.0,
            displayFormat: (v) =>
                v > 0 ? '+${(v * 100).toStringAsFixed(0)} Magenta' : '${(v * 100).toStringAsFixed(0)} Green',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(tint: v)),
          ),
          _buildSlider(
            label: 'Hue',
            value: _adjustments.hue,
            min: -180.0,
            max: 180.0,
            defaultValue: 0.0,
            displayFormat: (v) => '${v.toStringAsFixed(0)}°',
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(hue: v)),
          ),
          _buildSlider(
            label: 'Gamma',
            value: _adjustments.gamma,
            min: 0.2,
            max: 3.0,
            defaultValue: 1.0,
            displayFormat: (v) => v.toStringAsFixed(2),
            onChanged: (v) => _updateAdjustments(_adjustments.copyWith(gamma: v)),
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          const Text(
            'Transform & Orientation',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),

          // Fine Rotation Controls with Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fine Rotation', style: TextStyle(color: Colors.white70, fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.restart_alt, size: 16),
                color: (_cropSettings.rotationDegrees != 0 || _cropSettings.fineAngle != 0.0)
                    ? Colors.amberAccent
                    : Colors.white24,
                tooltip: 'Reset Rotation (0.0°)',
                onPressed: (_cropSettings.rotationDegrees != 0 || _cropSettings.fineAngle != 0.0)
                    ? () {
                        setState(() => _cropSettings = _cropSettings.withResetRotation());
                        _generateLivePreview();
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Stepper Row: Value + Up/Down Arrows
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262632),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_cropSettings.totalAngle >= 0 ? '+' : ''}${_cropSettings.totalAngle.toStringAsFixed(1)}°',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _cropSettings.totalAngle == 0 ? '0°' : (_cropSettings.totalAngle > 0 ? 'CW' : 'CCW'),
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Up & Down arrow buttons side of the value
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF262632),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Decrease 1° (-1°)',
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                        onTap: () {
                          setState(() => _cropSettings = _cropSettings.withSteppedRotation(-1.0));
                          _generateLivePreview();
                        },
                        child: const SizedBox(
                          width: 34,
                          height: 38,
                          child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 22, color: Colors.white12),
                    Tooltip(
                      message: 'Increase 1° (+1°)',
                      child: InkWell(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                        onTap: () {
                          setState(() => _cropSettings = _cropSettings.withSteppedRotation(1.0));
                          _generateLivePreview();
                        },
                        child: const SizedBox(
                          width: 34,
                          height: 38,
                          child: Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Slider(
            value: _cropSettings.fineAngle.clamp(-180.0, 180.0),
            min: -180.0,
            max: 180.0,
            divisions: 360,
            label: '${_cropSettings.fineAngle >= 0 ? '+' : ''}${_cropSettings.fineAngle.toStringAsFixed(1)}°',
            onChanged: (val) {
              setState(() => _cropSettings = _cropSettings.withFineAngle(val));
              _generateLivePreview();
            },
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                  icon: const Icon(Icons.rotate_left, size: 16),
                  label: const Text('Rotate L', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final newDeg = (_cropSettings.rotationDegrees - 90) % 360;
                    setState(() => _cropSettings = _cropSettings.copyWith(rotationDegrees: newDeg));
                    _generateLivePreview();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                  icon: const Icon(Icons.rotate_right, size: 16),
                  label: const Text('Rotate R', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final newDeg = (_cropSettings.rotationDegrees + 90) % 360;
                    setState(() => _cropSettings = _cropSettings.copyWith(rotationDegrees: newDeg));
                    _generateLivePreview();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _cropSettings.flipHorizontal ? Colors.blueAccent : Colors.white24),
                  ),
                  icon: const Icon(Icons.flip, size: 16),
                  label: const Text('Flip H', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(
                      () => _cropSettings = _cropSettings.copyWith(flipHorizontal: !_cropSettings.flipHorizontal),
                    );
                    _generateLivePreview();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _cropSettings.flipVertical ? Colors.blueAccent : Colors.white24),
                  ),
                  icon: const Icon(Icons.flip, size: 16),
                  label: const Text('Flip V', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() => _cropSettings = _cropSettings.copyWith(flipVertical: !_cropSettings.flipVertical));
                    _generateLivePreview();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Color & Artistic Effects',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...ImageFilterType.values.map((f) {
          final isSelected = _adjustments.filter == f;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF262632),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.blueAccent : Colors.white38,
                size: 20,
              ),
              title: Text(
                f.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () => _updateAdjustments(_adjustments.copyWith(filter: f)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildWatermarkTab() {
    final wm = _adjustments.watermark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enable Watermark',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: wm.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  _updateAdjustments(_adjustments.copyWith(watermark: wm.copyWith(enabled: val)));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          const Text('Watermark Text', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _watermarkTextController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262632),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (val) {
              _updateAdjustments(_adjustments.copyWith(watermark: wm.copyWith(text: val)));
            },
          ),
          const SizedBox(height: 16),

          const Text('Position', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          DropdownButtonFormField<WatermarkPosition>(
            value: wm.position,
            dropdownColor: const Color(0xFF2A2A36),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262632),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: WatermarkPosition.values.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                _updateAdjustments(_adjustments.copyWith(watermark: wm.copyWith(position: val)));
              }
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font Size', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${wm.fontSize} pt',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: wm.fontSize.toDouble(),
            min: 14,
            max: 48,
            divisions: 2,
            label: '${wm.fontSize} pt',
            onChanged: (val) {
              _updateAdjustments(_adjustments.copyWith(watermark: wm.copyWith(fontSize: val.round())));
            },
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Opacity', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${(wm.opacity * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: wm.opacity,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: (val) {
              _updateAdjustments(_adjustments.copyWith(watermark: wm.copyWith(opacity: val)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBordersTab() {
    final border = _adjustments.border;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enable Border Frame',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: border.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  _updateAdjustments(_adjustments.copyWith(border: border.copyWith(enabled: val)));
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Border Thickness', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                '${border.thickness} px',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: border.thickness.toDouble(),
            min: 2,
            max: 60,
            divisions: 29,
            label: '${border.thickness} px',
            onChanged: (val) {
              _updateAdjustments(_adjustments.copyWith(border: border.copyWith(thickness: val.round())));
            },
          ),
          const SizedBox(height: 16),

          const Text('Frame Color', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildColorChip('#FFFFFF', 'White'),
              _buildColorChip('#000000', 'Black'),
              _buildColorChip('#D4AF37', 'Gold'),
              _buildColorChip('#E5E7EB', 'Gallery Silver'),
              _buildColorChip('#1E293B', 'Slate Dark'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(String hex, String label) {
    final isSelected = _adjustments.border.colorHex.toUpperCase() == hex.toUpperCase();
    return ActionChip(
      avatar: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: hex == '#FFFFFF' ? Colors.white : (hex == '#000000' ? Colors.black : const Color(0xFFD4AF37)),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
      ),
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
      backgroundColor: isSelected ? Colors.blueAccent.withOpacity(0.4) : const Color(0xFF262632),
      side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.white12),
      onPressed: () {
        _updateAdjustments(_adjustments.copyWith(border: _adjustments.border.copyWith(colorHex: hex)));
      },
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required double defaultValue,
    required String Function(double) displayFormat,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Row(
              children: [
                Text(
                  displayFormat(value),
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                if ((value - defaultValue).abs() > 0.001)
                  InkWell(
                    onTap: () => onChanged(defaultValue),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.replay, size: 14, color: Colors.white38),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        const SizedBox(height: 4),
      ],
    );
  }
}
