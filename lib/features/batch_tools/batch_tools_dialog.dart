import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/batch_operations.dart';
import '../../core/models/image_adjustments.dart';
import '../../core/models/image_item.dart';
import '../export/export_dialog.dart';

enum BatchToolTab { resize, convert, rename, watermark, filters }

class BatchToolsDialog extends ConsumerStatefulWidget {
  final List<ImageItem> images;
  final BatchToolTab initialTab;

  const BatchToolsDialog({super.key, required this.images, this.initialTab = BatchToolTab.resize});

  @override
  ConsumerState<BatchToolsDialog> createState() => _BatchToolsDialogState();
}

class _BatchToolsDialogState extends ConsumerState<BatchToolsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Resize state
  ResizeMode _resizeMode = ResizeMode.percentage;
  int _targetW = 1920;
  int _targetH = 1080;
  int _percentage = 80;
  bool _maintainAspect = true;

  // Convert state
  ImageOutputFormat _convertFormat = ImageOutputFormat.webp;
  int _quality = 90;

  // Rename state
  NamingMode _renameMode = NamingMode.sequential;
  int _startNum = 1;
  final int _digits = 3;

  // Watermark state
  WatermarkSettings _watermark = const WatermarkSettings(enabled: false, text: 'Novastar Picture Manager');
  final _watermarkController = TextEditingController(text: 'Novastar Picture Manager');

  // Filter & Frame state
  ImageFilterType _batchFilter = ImageFilterType.none;
  BorderSettings _border = const BorderSettings(enabled: false, thickness: 16, colorHex: '#FFFFFF');

  final _targetWController = TextEditingController(text: '1920');
  final _targetHController = TextEditingController(text: '1080');
  final _prefixController = TextEditingController(text: 'edited_');
  final _suffixController = TextEditingController();
  final _baseNameController = TextEditingController(text: 'photo');
  final _startNumController = TextEditingController(text: '1');
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTab.index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetWController.dispose();
    _targetHController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _baseNameController.dispose();
    _startNumController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  void _applyAndProceed() {
    final resizeSettings = ResizeSettings(
      mode: _resizeMode,
      targetWidth: _targetW,
      targetHeight: _targetH,
      percentage: _percentage,
      maintainAspectRatio: _maintainAspect,
    );

    final renameSettings = RenameSettings(
      mode: _renameMode,
      prefix: _prefixController.text,
      suffix: _suffixController.text,
      baseName: _baseNameController.text,
      startNumber: _startNum,
      digitPadding: _digits,
      findText: _findController.text,
      replaceText: _replaceController.text,
    );

    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(
        images: widget.images,
        cropSettingsMap: const {},
        isBatchCropWorkflow: false,
        initialResizeSettings: resizeSettings,
        initialRenameSettings: renameSettings,
        initialBatchWatermark: _watermark.enabled ? _watermark : null,
        initialBatchFilter: _batchFilter != ImageFilterType.none ? _batchFilter : null,
        initialBatchBorder: _border.enabled ? _border : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E26),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 820,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.tune, color: Colors.blueAccent, size: 26),
                const SizedBox(width: 12),
                Text(
                  'Batch Operations (${widget.images.length} images)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tabController,
              indicatorColor: Colors.blueAccent,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white60,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.aspect_ratio), text: 'Resize'),
                Tab(icon: Icon(Icons.transform), text: 'Convert'),
                Tab(icon: Icon(Icons.drive_file_rename_outline), text: 'Rename'),
                Tab(icon: Icon(Icons.branding_watermark), text: 'Watermark'),
                Tab(icon: Icon(Icons.filter), text: 'Filters & Frames'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildResizeTab(),
                  _buildConvertTab(),
                  _buildRenameTab(),
                  _buildWatermarkTab(),
                  _buildFiltersTab(),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Proceed to Export'),
                  onPressed: _applyAndProceed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resize Method',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ResizeMode>(
            value: _resizeMode,
            dropdownColor: const Color(0xFF2A2A34),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ResizeMode.values.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(m.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _resizeMode = val);
            },
          ),
          const SizedBox(height: 16),

          if (_resizeMode == ResizeMode.percentage) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Scale Percentage', style: TextStyle(color: Colors.white70)),
                Text(
                  '$_percentage%',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _percentage.toDouble(),
              min: 10,
              max: 200,
              divisions: 38,
              onChanged: (v) => setState(() => _percentage = v.round()),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetWController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Width (px)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => _targetW = int.tryParse(v) ?? _targetW,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetHController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Height (px)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => _targetH = int.tryParse(v) ?? _targetH,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            'Common Screen & Social Presets',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Full HD (1920x1080)', 1920, 1080),
              _buildPresetChip('4K UHD (3840x2160)', 3840, 2160),
              _buildPresetChip('Instagram Square (1080x1080)', 1080, 1080),
              _buildPresetChip('Instagram Story (1080x1920)', 1080, 1920),
              _buildPresetChip('Web Thumbnail (600x400)', 600, 400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int w, int h) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      backgroundColor: const Color(0xFF262630),
      onPressed: () {
        setState(() {
          _resizeMode = ResizeMode.fitInside;
          _targetW = w;
          _targetH = h;
          _targetWController.text = w.toString();
          _targetHController.text = h.toString();
        });
      },
    );
  }

  Widget _buildConvertTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target Image Format',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ImageOutputFormat>(
            value: _convertFormat,
            dropdownColor: const Color(0xFF2A2A34),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ImageOutputFormat.values.where((e) => e != ImageOutputFormat.original).map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(f.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _convertFormat = val);
            },
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compression Quality',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
              ),
              Text(
                '$_quality%',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _quality.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            onChanged: (v) => setState(() => _quality = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildRenameTab() {
    final previewList = widget.images.take(5).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Renaming Pattern',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<NamingMode>(
            value: _renameMode,
            dropdownColor: const Color(0xFF2A2A34),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: NamingMode.values.map((m) {
              return DropdownMenuItem(
                value: m,
                child: Text(m.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _renameMode = val);
            },
          ),
          const SizedBox(height: 14),

          if (_renameMode == NamingMode.sequential) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Base Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _startNumController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Start Number',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _startNum = int.tryParse(v) ?? 1),
                  ),
                ),
              ],
            ),
          ] else if (_renameMode == NamingMode.prefix || _renameMode == NamingMode.suffix) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prefixController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Prefix',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _suffixController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Suffix',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF262630),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Text(
            'Filename Live Preview',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF262630), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: previewList.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final nameNoExt = item.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                final settings = RenameSettings(
                  mode: _renameMode,
                  prefix: _prefixController.text,
                  suffix: _suffixController.text,
                  baseName: _baseNameController.text,
                  startNumber: _startNum,
                  digitPadding: _digits,
                  findText: _findController.text,
                  replaceText: _replaceController.text,
                );
                final newName = settings.generateName(
                  originalNameWithoutExtension: nameNoExt,
                  index: i,
                  date: item.dateModified,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${item.name}  →  $newName.${item.extension}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatermarkTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Apply Watermark to All Images in Batch',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _watermark.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (val) => setState(() => _watermark = _watermark.copyWith(enabled: val)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _watermarkController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Watermark Text',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => setState(() => _watermark = _watermark.copyWith(text: v)),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<WatermarkPosition>(
            value: _watermark.position,
            dropdownColor: const Color(0xFF2A2A34),
            decoration: InputDecoration(
              labelText: 'Position',
              labelStyle: const TextStyle(color: Colors.white60),
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: WatermarkPosition.values.map((p) {
              return DropdownMenuItem(
                value: p,
                child: Text(p.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _watermark = _watermark.copyWith(position: val));
            },
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Watermark Opacity', style: TextStyle(color: Colors.white70)),
              Text(
                '${(_watermark.opacity * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _watermark.opacity,
            min: 0.1,
            max: 1.0,
            divisions: 9,
            onChanged: (v) => setState(() => _watermark = _watermark.copyWith(opacity: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch Filter Effect',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ImageFilterType>(
            value: _batchFilter,
            dropdownColor: const Color(0xFF2A2A34),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF262630),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: ImageFilterType.values.map((f) {
              return DropdownMenuItem(
                value: f,
                child: Text(f.label, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _batchFilter = val);
            },
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Outer Border Frame to Batch',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Switch(
                value: _border.enabled,
                activeColor: Colors.blueAccent,
                onChanged: (val) => setState(() => _border = _border.copyWith(enabled: val)),
              ),
            ],
          ),
          if (_border.enabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Frame Thickness', style: TextStyle(color: Colors.white70)),
                Text(
                  '${_border.thickness} px',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _border.thickness.toDouble(),
              min: 4,
              max: 60,
              divisions: 28,
              onChanged: (v) => setState(() => _border = _border.copyWith(thickness: v.round())),
            ),
          ],
        ],
      ),
    );
  }
}
