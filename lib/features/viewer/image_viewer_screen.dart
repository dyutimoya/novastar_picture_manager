import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/image_item.dart';
import '../../core/services/file_service.dart';
import '../../core/state/batch_crop_provider.dart';
import '../../core/state/library_provider.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final ImageItem initialItem;

  const ImageViewerScreen({super.key, required this.initialItem});

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();
  final FocusNode _focusNode = FocusNode();
  bool _showOverlays = true;
  bool _showFilmstrip = true;
  bool _isSlideshowPlaying = false;
  Timer? _slideshowTimer;
  double _currentZoom = 1.0;
  double _rotation = 0.0;
  bool _flipH = false;
  bool _flipV = false;

  @override
  void initState() {
    super.initState();
    final images = ref.read(libraryProvider).filteredImages;
    final foundIndex = images.indexWhere((e) => e.id == widget.initialItem.id || e.path == widget.initialItem.path);
    _currentIndex = foundIndex != -1 ? foundIndex : 0;
    _transformationController.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentZoom).abs() > 0.05) {
      setState(() => _currentZoom = scale);
    }
  }

  List<ImageItem> _getImages() {
    final images = ref.read(libraryProvider).filteredImages;
    if (images.isNotEmpty) return images;
    return [widget.initialItem];
  }

  ImageItem _getCurrentImage() {
    final images = _getImages();
    if (_currentIndex >= 0 && _currentIndex < images.length) {
      return images[_currentIndex];
    }
    return widget.initialItem;
  }

  void _nextImage() {
    final images = _getImages();
    if (_currentIndex < images.length - 1) {
      setState(() {
        _currentIndex++;
        _resetTransform();
      });
    } else if (_isSlideshowPlaying) {
      // Loop around in slideshow
      setState(() {
        _currentIndex = 0;
        _resetTransform();
      });
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _resetTransform();
      });
    }
  }

  void _resetTransform() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentZoom = 1.0;
      _rotation = 0.0;
      _flipH = false;
      _flipV = false;
    });
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.3).clamp(0.2, 8.0);
    _setZoom(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.3).clamp(0.2, 8.0);
    _setZoom(newScale);
  }

  void _setZoom(double scale) {
    _transformationController.value = Matrix4.identity()..scale(scale);
    setState(() => _currentZoom = scale);
  }

  void _toggleSlideshow() {
    setState(() {
      _isSlideshowPlaying = !_isSlideshowPlaying;
      if (_isSlideshowPlaying) {
        _slideshowTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _nextImage();
        });
      } else {
        _slideshowTimer?.cancel();
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _nextImage();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _previousImage();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _toggleSlideshow();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.pop();
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _openCropEditor();
    } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
      _openAdjustEditor();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      setState(() => _rotation = (_rotation + 90.0) % 360.0);
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      _confirmDeleteCurrent();
    }
  }

  void _openCropEditor() {
    final cur = _getCurrentImage();
    ref.read(batchCropProvider.notifier).init([cur]);
    context.push('/crop');
  }

  void _openAdjustEditor() {
    final cur = _getCurrentImage();
    context.push('/edit', extra: cur);
  }

  void _confirmDeleteCurrent() {
    final cur = _getCurrentImage();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22222B),
        title: const Text('Delete Image?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${cur.name} from disk?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FileService.deleteFile(cur.path);
              ref.read(libraryProvider.notifier).refreshCurrentFolder();
              if (mounted) {
                final images = _getImages();
                if (images.length <= 1) {
                  context.pop();
                } else {
                  _nextImage();
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMetadataDialog() {
    final cur = _getCurrentImage();
    final mp = (cur.width * cur.height / 1000000).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E26),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent),
            const SizedBox(width: 8),
            const Text('Image Properties', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropRow('File Name', cur.name),
            _buildPropRow('File Format', cur.extension.toUpperCase()),
            _buildPropRow('File Size', cur.humanReadableSize),
            _buildPropRow('Dimensions', '${cur.width} × ${cur.height} px ($mp MP)'),
            _buildPropRow('Aspect Ratio', '${cur.aspectRatio.toStringAsFixed(2)} : 1'),
            _buildPropRow(
              'Date Modified',
              '${cur.dateModified.year}-${cur.dateModified.month.toString().padLeft(2, '0')}-${cur.dateModified.day.toString().padLeft(2, '0')} ${cur.dateModified.hour}:${cur.dateModified.minute}',
            ),
            _buildPropRow('Location', cur.path),
          ],
        ),
        actions: [
          if (!kIsWeb && File(cur.path).existsSync())
            TextButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Show in File Manager'),
              onPressed: () {
                FileService.openInFileManager(cur.path);
              },
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
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
    final images = _getImages();
    final cur = _getCurrentImage();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _showOverlays = !_showOverlays),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main Zoomable & Pannable Image Area
              Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.1,
                  maxScale: 10.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateZ(_rotation * pi / 180.0)
                      ..scale(_flipH ? -1.0 : 1.0, _flipV ? -1.0 : 1.0),
                    child: Image(image: _getImageProvider(cur), fit: BoxFit.contain, filterQuality: FilterQuality.high),
                  ),
                ),
              ),

              // Left / Right Floating Edge Click Navigators
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: InkWell(
                      onTap: _previousImage,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              if (_currentIndex < images.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: InkWell(
                      onTap: _nextImage,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),

              // Top Overlay Bar
              if (_showOverlays)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'Back to Library (Esc)',
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cur.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${cur.width} × ${cur.height} px • ${cur.humanReadableSize} • ${_currentIndex + 1} of ${images.length}',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),

                        // Zoom Display Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '${(_currentZoom * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.zoom_out, color: Colors.white70),
                          tooltip: 'Zoom Out',
                          onPressed: _zoomOut,
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.white70),
                          tooltip: 'Zoom In',
                          onPressed: _zoomIn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.aspect_ratio, color: Colors.white70),
                          tooltip: 'Reset to Fit (100%)',
                          onPressed: _resetTransform,
                        ),
                        IconButton(
                          icon: Icon(
                            _isSlideshowPlaying ? Icons.pause_circle : Icons.play_circle_outline,
                            color: _isSlideshowPlaying ? Colors.amberAccent : Colors.white70,
                          ),
                          tooltip: _isSlideshowPlaying ? 'Pause Slideshow (Space)' : 'Play Slideshow (Space)',
                          onPressed: _toggleSlideshow,
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white70),
                          tooltip: 'Properties',
                          onPressed: _showMetadataDialog,
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Overlay Toolbar & Filmstrip
              if (_showOverlays)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quick Action Button Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.rotate_left, color: Colors.white),
                                tooltip: 'Rotate Left 90°',
                                onPressed: () => setState(() => _rotation = (_rotation - 90.0) % 360.0),
                              ),
                              IconButton(
                                icon: const Icon(Icons.rotate_right, color: Colors.white),
                                tooltip: 'Rotate Right 90° (R)',
                                onPressed: () => setState(() => _rotation = (_rotation + 90.0) % 360.0),
                              ),
                              const SizedBox(width: 4),

                              // Stepper with value and up/down arrows (1+++ / -1---)
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Decrease 1° (-1°)',
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                                        onTap: () => setState(
                                          () => _rotation = double.parse((_rotation - 1.0).toStringAsFixed(1)),
                                        ),
                                        child: const SizedBox(
                                          width: 28,
                                          height: 32,
                                          child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                    Container(width: 1, height: 18, color: Colors.white24),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '${_rotation.toStringAsFixed(1)}°',
                                        style: TextStyle(
                                          color: _rotation != 0.0 ? Colors.blueAccent : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    Container(width: 1, height: 18, color: Colors.white24),
                                    Tooltip(
                                      message: 'Increase 1° (+1°)',
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                                        onTap: () => setState(
                                          () => _rotation = double.parse((_rotation + 1.0).toStringAsFixed(1)),
                                        ),
                                        child: const SizedBox(
                                          width: 28,
                                          height: 32,
                                          child: Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_rotation != 0.0) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.restart_alt, size: 18, color: Colors.amberAccent),
                                  tooltip: 'Reset Rotation to 0.0°',
                                  onPressed: () => setState(() => _rotation = 0.0),
                                ),
                              ],
                              const SizedBox(width: 4),

                              IconButton(
                                icon: Icon(Icons.flip, color: _flipH ? Colors.blueAccent : Colors.white),
                                tooltip: 'Flip Horizontal',
                                onPressed: () => setState(() => _flipH = !_flipH),
                              ),
                              IconButton(
                                icon: Icon(Icons.flip, color: _flipV ? Colors.blueAccent : Colors.white),
                                tooltip: 'Flip Vertical',
                                onPressed: () => setState(() => _flipV = !_flipV),
                              ),
                              const SizedBox(width: 8),
                              const SizedBox(height: 20, child: VerticalDivider(color: Colors.white24, width: 1)),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E2E3C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.crop, size: 16),
                                label: const Text('Crop (C)', style: TextStyle(fontSize: 12)),
                                onPressed: _openCropEditor,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E2E3C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.tune, size: 16),
                                label: const Text('Adjust (E)', style: TextStyle(fontSize: 12)),
                                onPressed: _openAdjustEditor,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Delete Image',
                                onPressed: _confirmDeleteCurrent,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(
                                  _showFilmstrip ? Icons.photo_library : Icons.photo_library_outlined,
                                  color: Colors.white70,
                                ),
                                tooltip: 'Toggle Filmstrip',
                                onPressed: () => setState(() => _showFilmstrip = !_showFilmstrip),
                              ),
                            ],
                          ),
                        ),

                        // Collapsible Filmstrip
                        if (_showFilmstrip && images.length > 1)
                          Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final item = images[index];
                                final isSelected = index == _currentIndex;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentIndex = index;
                                      _resetTransform();
                                    });
                                  },
                                  child: Container(
                                    width: 60,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? Colors.blueAccent : Colors.white10,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: item.thumbnailBytes != null
                                        ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                                        : Container(color: Colors.white10),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
