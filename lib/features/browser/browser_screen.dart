import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/image_item.dart';
import '../../core/services/file_service.dart';
import '../../core/state/batch_crop_provider.dart';
import '../../core/state/library_provider.dart';
import 'widgets/default_viewer_dialog.dart';
import '../batch_tools/batch_tools_dialog.dart';
import '../export/export_dialog.dart';

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDragging = false;
  bool _showOnlyFavorites = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openBatchCrop() {
    final libraryState = ref.read(libraryProvider);
    final selected = libraryState.selectedImages.isNotEmpty ? libraryState.selectedImages : libraryState.filteredImages;

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or load images first.')));
      return;
    }

    ref.read(batchCropProvider.notifier).init(selected);
    context.push('/crop');
  }

  void _openViewer(ImageItem item) {
    context.push('/viewer', extra: item);
  }

  void _openDefaultViewerSettings() {
    showDialog(context: context, builder: (ctx) => const DefaultViewerDialog());
  }

  void _openEditor(ImageItem item) {
    context.push('/edit', extra: item);
  }

  void _openBatchTools(BatchToolTab tab) {
    final libraryState = ref.read(libraryProvider);
    final selected = libraryState.selectedImages.isNotEmpty ? libraryState.selectedImages : libraryState.filteredImages;

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or load images first.')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => BatchToolsDialog(images: selected, initialTab: tab),
    );
  }

  void _openExport() {
    final libraryState = ref.read(libraryProvider);
    final selected = libraryState.selectedImages.isNotEmpty ? libraryState.selectedImages : libraryState.filteredImages;

    if (selected.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(images: selected, cropSettingsMap: {}, isBatchCropWorkflow: false),
    );
  }

  Future<void> _pickImages() async {
    final items = await FileService.pickImages();
    if (items.isNotEmpty) {
      ref.read(libraryProvider.notifier).addImages(items);
    }
  }

  Future<void> _pickFolder() async {
    final items = await FileService.pickFolder();
    if (items.isNotEmpty) {
      ref.read(libraryProvider.notifier).setImages(items);
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final library = ref.read(libraryProvider.notifier);

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      library.selectAll();
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyO) {
      _pickFolder();
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      _openBatchCrop();
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      _confirmDeleteSelected();
    }
  }

  void _confirmDeleteSelected() {
    final selectedCount = ref.read(libraryProvider).selectedIds.length;
    if (selectedCount == 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF22222B),
        title: const Text('Delete Images?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete $selectedCount image(s) from disk? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(libraryProvider.notifier).deleteSelected();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    var displayList = libraryState.filteredImages;
    if (_showOnlyFavorites) {
      displayList = displayList.where((img) => img.isFavorite).toList();
    }

    final totalBytes = displayList.fold<int>(0, (acc, item) => acc + item.fileSizeBytes);
    final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          final droppedItems = <ImageItem>[];
          for (final file in details.files) {
            final item = await FileService.loadItemFromFile(file.path);
            if (item != null) droppedItems.add(item);
          }
          if (droppedItems.isNotEmpty) {
            ref.read(libraryProvider.notifier).addImages(droppedItems);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF141419),
          body: Row(
            children: [
              // Sidebar Navigation
              _buildSidebar(context, libraryState),

              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Professional Top Toolbar
                    _buildTopToolbar(context, libraryState),

                    // Drag Drop Indicator Banner
                    if (_isDragging)
                      Container(
                        color: Colors.blueAccent.withOpacity(0.9),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_download, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Drop images here to import',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                    // Filter & Search Header
                    _buildFilterBar(libraryState),

                    // Thumbnail Grid / Empty state
                    Expanded(
                      child: libraryState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : (displayList.isEmpty ? _buildEmptyState() : _buildThumbnailGrid(displayList, libraryState)),
                    ),

                    // Bottom Status Bar
                    _buildStatusBar(displayList, libraryState, sizeMb),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, LibraryState state) {
    return Material(
      color: const Color(0xFF1B1B22),
      child: SizedBox(
        width: 230,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Title / Branding
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PICTURE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'MANAGER PRO',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),

            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildSidebarItem(
                    icon: Icons.photo_library_outlined,
                    label: 'All Images',
                    count: state.images.length,
                    isSelected: !_showOnlyFavorites,
                    onTap: () => setState(() => _showOnlyFavorites = false),
                  ),
                  _buildSidebarItem(
                    icon: Icons.star_border,
                    label: 'Favorites',
                    count: state.images.where((e) => e.isFavorite).length,
                    isSelected: _showOnlyFavorites,
                    onTap: () => setState(() => _showOnlyFavorites = true),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(
                      'FOLDERS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  if (state.currentDirectory != null) ...[
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder, color: Colors.amberAccent, size: 18),
                      title: Text(
                        state.currentDirectory!.split(Platform.pathSeparator).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      subtitle: Text(
                        state.currentDirectory!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                        onPressed: () => ref.read(libraryProvider.notifier).refreshCurrentFolder(),
                      ),
                    ),
                  ],
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.create_new_folder_outlined, color: Colors.white54, size: 18),
                    title: const Text('Open Folder...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    onTap: _pickFolder,
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 18),
                    title: const Text('Add Images...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    onTap: _pickImages,
                  ),
                ],
              ),
            ),

            // Batch Action Shortcuts Banner
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF262632),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Images',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.selectedIds.length} of ${state.images.length}',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.crop, size: 16),
                      label: const Text('Batch Crop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _openBatchCrop,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.blueAccent.withOpacity(0.18) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.blueAccent : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context, LibraryState state) {
    final notifier = ref.read(libraryProvider.notifier);
    final hasSelection = state.selectedIds.isNotEmpty;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF1E1E26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1100;
          final isVeryNarrow = constraints.maxWidth < 700;
          return Row(
            children: [
              // Open Folder / Add Images
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C38),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 8),
                ),
                icon: const Icon(Icons.folder_open, size: 16),
                label: isCompact ? const SizedBox.shrink() : const Text('Open Folder', style: TextStyle(fontSize: 12)),
                onPressed: _pickFolder,
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  foregroundColor: Colors.white70,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10, vertical: 8),
                ),
                icon: const Icon(Icons.add_photo_alternate, size: 16),
                label: isCompact ? const SizedBox.shrink() : const Text('Import', style: TextStyle(fontSize: 12)),
                onPressed: _pickImages,
              ),

              const SizedBox(width: 6),
              const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
              const SizedBox(width: 6),

              // Batch Crop (High Priority Action)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.crop, size: 16),
                label: Text(
                  hasSelection ? 'Batch Crop (${state.selectedIds.length})' : 'Batch Crop All',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _openBatchCrop,
              ),

              const SizedBox(width: 4),
              // Batch Tools Menu
              PopupMenuButton<BatchToolTab>(
                tooltip: 'Batch Operations',
                icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
                color: const Color(0xFF2A2A36),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: BatchToolTab.resize,
                    child: Row(
                      children: [Icon(Icons.aspect_ratio, size: 18), SizedBox(width: 10), Text('Batch Resize')],
                    ),
                  ),
                  const PopupMenuItem(
                    value: BatchToolTab.convert,
                    child: Row(
                      children: [
                        Icon(Icons.transform, size: 18),
                        SizedBox(width: 10),
                        Text('Batch Convert & Compress'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: BatchToolTab.rename,
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_rename_outline, size: 18),
                        SizedBox(width: 10),
                        Text('Batch Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: BatchToolTab.watermark,
                    child: Row(
                      children: [
                        Icon(Icons.branding_watermark, size: 18),
                        SizedBox(width: 10),
                        Text('Batch Watermark'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: BatchToolTab.filters,
                    child: Row(
                      children: [Icon(Icons.filter, size: 18), SizedBox(width: 10), Text('Batch Filters & Frames')],
                    ),
                  ),
                ],
                onSelected: _openBatchTools,
              ),

              // Export Selected
              IconButton(
                icon: const Icon(Icons.file_upload_outlined, color: Colors.white70, size: 20),
                tooltip: 'Export',
                onPressed: _openExport,
              ),

              const Spacer(),

              if (!isVeryNarrow) ...[
                // Selection controls
                TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: notifier.selectAll,
                  child: const Text('Select All', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ),
                TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: notifier.deselectAll,
                  child: const Text('Deselect', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ),
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
                const SizedBox(width: 4),
              ],

              // View mode toggle
              IconButton(
                icon: Icon(state.isListView ? Icons.grid_view : Icons.view_list, color: Colors.white70, size: 20),
                tooltip: state.isListView ? 'Switch to Grid View' : 'Switch to List View',
                onPressed: notifier.toggleViewMode,
              ),

              const SizedBox(width: 4),

              // Default Viewer & System Associations Settings
              IconButton(
                icon: const Icon(Icons.settings_applications, color: Colors.blueAccent, size: 20),
                tooltip: 'Set as Default Image Viewer & System Associations',
                onPressed: _openDefaultViewerSettings,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(LibraryState state) {
    final notifier = ref.read(libraryProvider.notifier);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF181820),
      child: Row(
        children: [
          // Search box
          SizedBox(
            width: 220,
            height: 32,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search images...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          notifier.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF242430),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
              onChanged: notifier.setSearchQuery,
            ),
          ),

          const SizedBox(width: 16),

          // Format Filter Chips
          Wrap(
            spacing: 6,
            children: ['ALL', 'JPG', 'PNG', 'WEBP', 'BMP'].map((fmt) {
              final isSelected =
                  (state.formatFilter.isEmpty && fmt == 'ALL') || (state.formatFilter.toUpperCase() == fmt);
              return ChoiceChip(
                label: Text(fmt, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.white60)),
                selected: isSelected,
                selectedColor: Colors.blueAccent.withOpacity(0.5),
                backgroundColor: const Color(0xFF242430),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: -2),
                onSelected: (val) {
                  notifier.setFormatFilter(fmt == 'ALL' ? '' : fmt);
                },
              );
            }).toList(),
          ),

          const Spacer(),

          // Sort Dropdown
          DropdownButton<ImageSortBy>(
            value: state.sortBy,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(0xFF262634),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            icon: const Icon(Icons.sort, color: Colors.white54, size: 16),
            items: ImageSortBy.values.map((sort) {
              return DropdownMenuItem(value: sort, child: Text(sort.label));
            }).toList(),
            onChanged: (val) {
              if (val != null) notifier.setSortBy(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailGrid(List<ImageItem> images, LibraryState state) {
    final notifier = ref.read(libraryProvider.notifier);

    if (state.isListView) {
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: images.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
        itemBuilder: (context, index) {
          final item = images[index];
          final isSelected = state.selectedIds.contains(item.id);

          return ListTile(
            dense: true,
            selected: isSelected,
            selectedTileColor: Colors.blueAccent.withOpacity(0.15),
            onTap: () => notifier.toggleSelect(item.id),
            leading: SizedBox(
              width: 44,
              height: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: item.thumbnailBytes != null
                    ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                    : Container(color: Colors.white10),
              ),
            ),
            title: Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.dimensionsText} • ${item.humanReadableSize} • ${item.extension.toUpperCase()}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blueAccent),
                  tooltip: 'Open in Viewer',
                  onPressed: () => _openViewer(item),
                ),
                IconButton(
                  icon: Icon(
                    item.isFavorite ? Icons.star : Icons.star_border,
                    color: item.isFavorite ? Colors.amberAccent : Colors.white30,
                    size: 18,
                  ),
                  onPressed: () => notifier.toggleFavorite(item.id),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                  onPressed: () => _openEditor(item),
                ),
              ],
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: state.thumbnailSize.size + 40,
        mainAxisExtent: state.thumbnailSize.size + 65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final item = images[index];
        final isSelected = state.selectedIds.contains(item.id);

        return GestureDetector(
          onTap: () => notifier.toggleSelect(item.id),
          onDoubleTap: () => _openViewer(item),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10, width: isSelected ? 2.5 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Image Preview
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: const Color(0xFF121216),
                        child: item.thumbnailBytes != null
                            ? Image.memory(item.thumbnailBytes!, fit: BoxFit.contain)
                            : (item.bytes != null
                                  ? Image.memory(item.bytes!, fit: BoxFit.contain)
                                  : const Center(child: Icon(Icons.image, color: Colors.white24))),
                      ),

                      // Selection Checkbox Badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blueAccent : Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(isSelected ? Icons.check : Icons.circle_outlined, size: 14, color: Colors.white),
                        ),
                      ),

                      // Favorite Star
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => notifier.toggleFavorite(item.id),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: Icon(
                              item.isFavorite ? Icons.star : Icons.star_border,
                              size: 14,
                              color: item.isFavorite ? Colors.amberAccent : Colors.white60,
                            ),
                          ),
                        ),
                      ),

                      // Crop / Adjust Modified Badge
                      if (item.cropSettings.isModified || item.adjustments.isModified)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Edited',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Details footer
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  color: const Color(0xFF22222D),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.dimensionsText, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          Text(item.humanReadableSize, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'No Images Loaded',
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag and drop images here, or choose an option below',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Folder'),
                onPressed: _pickFolder,
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Import Images'),
                onPressed: _pickImages,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(List<ImageItem> images, LibraryState state, String sizeMb) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1B1B22),
      child: Row(
        children: [
          Text('${images.length} images found', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 16),
          Text(
            '${state.selectedIds.length} selected',
            style: TextStyle(
              color: state.selectedIds.isNotEmpty ? Colors.blueAccent : Colors.white38,
              fontSize: 11,
              fontWeight: state.selectedIds.isNotEmpty ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 16),
          Text('Total Size: $sizeMb MB', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const Spacer(),
          const Text(
            'Novastar Picture Manager • Clean Architecture',
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
