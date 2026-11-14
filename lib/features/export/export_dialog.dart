import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/batch_operations.dart';
import '../../core/models/crop_settings.dart';
import '../../core/models/image_adjustments.dart';
import '../../core/models/image_item.dart';
import '../../core/services/file_service.dart';
import '../../core/state/export_provider.dart';

class ExportDialog extends ConsumerStatefulWidget {
  final List<ImageItem> images;
  final Map<String, CropSettings> cropSettingsMap;
  final bool isBatchCropWorkflow;
  final ResizeSettings? initialResizeSettings;
  final RenameSettings? initialRenameSettings;
  final WatermarkSettings? initialBatchWatermark;
  final ImageFilterType? initialBatchFilter;
  final BorderSettings? initialBatchBorder;

  const ExportDialog({
    super.key,
    required this.images,
    required this.cropSettingsMap,
    this.isBatchCropWorkflow = true,
    this.initialResizeSettings,
    this.initialRenameSettings,
    this.initialBatchWatermark,
    this.initialBatchFilter,
    this.initialBatchBorder,
  });

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late ExportSettings _settings;
  final _folderController = TextEditingController();
  final _subfolderController = TextEditingController(text: 'PictureManager_Export');
  final _prefixController = TextEditingController();
  final _suffixController = TextEditingController(text: '_cropped');
  bool _enableRename = false;

  @override
  void initState() {
    super.initState();
    String defaultDir = '';
    if (!kIsWeb && widget.images.isNotEmpty && widget.images.first.path.isNotEmpty) {
      defaultDir = File(widget.images.first.path).parent.path;
    }
    _settings = ExportSettings(
      outputDirectory: defaultDir,
      applyCrop: widget.isBatchCropWorkflow,
      resizeSettings: widget.initialResizeSettings ?? const ResizeSettings(),
      renameSettings: widget.initialRenameSettings ?? const RenameSettings(),
      batchWatermark: widget.initialBatchWatermark,
      batchFilter: widget.initialBatchFilter,
      batchBorder: widget.initialBatchBorder,
    );
    _enableRename = widget.initialRenameSettings != null && widget.initialRenameSettings!.mode != NamingMode.original;
    _folderController.text = defaultDir;
  }

  @override
  void dispose() {
    _folderController.dispose();
    _subfolderController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      setState(() {
        _folderController.text = path;
        _settings = _settings.copyWith(outputDirectory: path);
      });
    }
  }

  void _startExport() {
    var finalRename = _settings.renameSettings;
    if (_enableRename) {
      finalRename = finalRename.copyWith(prefix: _prefixController.text, suffix: _suffixController.text);
    } else {
      finalRename = const RenameSettings(mode: NamingMode.original);
    }

    final finalSettings = _settings.copyWith(
      outputDirectory: _folderController.text,
      subfolderName: _subfolderController.text,
      renameSettings: finalRename,
    );

    ref
        .read(exportProvider.notifier)
        .runBatchExport(items: widget.images, cropSettingsMap: widget.cropSettingsMap, settings: finalSettings);
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportProvider);
    final theme = Theme.of(context);

    if (exportState.isExporting || exportState.completionMessage != null) {
      return _buildProgressView(context, exportState);
    }

    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.file_upload_outlined, color: Colors.blueAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Export ${widget.images.length} Images',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              // Format & Quality
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Output Format',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<ImageOutputFormat>(
                          value: _settings.format,
                          dropdownColor: const Color(0xFF2B2B36),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2A2A34),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: ImageOutputFormat.values.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text(f.label, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _settings = _settings.copyWith(format: val));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Quality',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_settings.quality}%',
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _settings.quality.toDouble(),
                          min: 10,
                          max: 100,
                          divisions: 18,
                          label: '${_settings.quality}%',
                          onChanged: (val) => setState(() => _settings = _settings.copyWith(quality: val.round())),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Destination directory (Desktop only)
              if (!kIsWeb) ...[
                const Text(
                  'Destination Directory',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _folderController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A34),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          hintText: 'Select output folder...',
                          hintStyle: const TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333342),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse'),
                      onPressed: _pickFolder,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Subfolder & Overwrite options
                Row(
                  children: [
                    Checkbox(
                      value: _settings.createSubfolder,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(createSubfolder: val ?? false)),
                    ),
                    const Text('Create subfolder:', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        controller: _subfolderController,
                        enabled: _settings.createSubfolder,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF2A2A34),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _settings.overwriteExisting,
                      onChanged: (val) =>
                          setState(() => _settings = _settings.copyWith(overwriteExisting: val ?? false)),
                    ),
                    const Text('Overwrite existing files', style: TextStyle(color: Colors.white70)),
                    const Spacer(),
                    Checkbox(
                      value: _settings.exportAsZip,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(exportAsZip: val ?? false)),
                    ),
                    const Text('Package as ZIP archive', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),

              // Batch renaming options
              Row(
                children: [
                  Checkbox(value: _enableRename, onChanged: (val) => setState(() => _enableRename = val ?? false)),
                  const Text(
                    'Enable Batch Renaming',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_enableRename) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prefixController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Prefix',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF2A2A34),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _suffixController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Suffix',
                          labelStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: const Color(0xFF2A2A34),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Buttons
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Start Export', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _startExport,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView(BuildContext context, ExportState exportState) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  exportState.completionMessage != null ? Icons.check_circle : Icons.hourglass_top,
                  color: exportState.completionMessage != null ? Colors.greenAccent : Colors.blueAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  exportState.completionMessage != null ? 'Export Complete' : 'Exporting Images...',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: exportState.progress,
                minHeight: 10,
                backgroundColor: Colors.white12,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(exportState.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${exportState.processedCount} of ${exportState.totalCount} completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            if (exportState.currentProcessingName.isNotEmpty && exportState.isExporting) ...[
              const SizedBox(height: 8),
              Text(
                'Processing: ${exportState.currentProcessingName}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (exportState.completionMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Text(
                  exportState.completionMessage!,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (exportState.isExporting)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Export'),
                    onPressed: () => ref.read(exportProvider.notifier).cancel(),
                  ),
                if (exportState.completionMessage != null) ...[
                  if (!kIsWeb && exportState.exportedPaths.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Open Folder'),
                      onPressed: () {
                        FileService.openInFileManager(exportState.exportedPaths.first);
                      },
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    onPressed: () {
                      ref.read(exportProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
