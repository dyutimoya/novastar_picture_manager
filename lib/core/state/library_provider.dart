import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/image_item.dart';
import '../services/file_service.dart';

enum ImageSortBy {
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  dateDesc('Date (Newest)'),
  dateAsc('Date (Oldest)'),
  sizeDesc('Size (Largest)'),
  sizeAsc('Size (Smallest)'),
  dimensions('Dimensions (Pixels)');

  final String label;
  const ImageSortBy(this.label);
}

enum ThumbnailSize {
  small(100.0),
  medium(160.0),
  large(240.0);

  final double size;
  const ThumbnailSize(this.size);
}

class LibraryState {
  final List<ImageItem> images;
  final Set<String> selectedIds;
  final String? currentDirectory;
  final String searchQuery;
  final String formatFilter; // '' means all
  final ImageSortBy sortBy;
  final ThumbnailSize thumbnailSize;
  final bool isLoading;
  final bool isListView;

  const LibraryState({
    this.images = const [],
    this.selectedIds = const {},
    this.currentDirectory,
    this.searchQuery = '',
    this.formatFilter = '',
    this.sortBy = ImageSortBy.dateDesc,
    this.thumbnailSize = ThumbnailSize.medium,
    this.isLoading = false,
    this.isListView = false,
  });

  List<ImageItem> get filteredImages {
    var result = images;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((img) => img.name.toLowerCase().contains(q)).toList();
    }
    if (formatFilter.isNotEmpty && formatFilter != 'ALL') {
      final f = formatFilter.toLowerCase();
      result = result.where((img) => img.extension.toLowerCase() == f).toList();
    }

    final sorted = List<ImageItem>.from(result);
    switch (sortBy) {
      case ImageSortBy.nameAsc:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ImageSortBy.nameDesc:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ImageSortBy.dateDesc:
        sorted.sort((a, b) => b.dateModified.compareTo(a.dateModified));
        break;
      case ImageSortBy.dateAsc:
        sorted.sort((a, b) => a.dateModified.compareTo(b.dateModified));
        break;
      case ImageSortBy.sizeDesc:
        sorted.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
        break;
      case ImageSortBy.sizeAsc:
        sorted.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
        break;
      case ImageSortBy.dimensions:
        sorted.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
        break;
    }
    return sorted;
  }

  List<ImageItem> get selectedImages => images.where((img) => selectedIds.contains(img.id)).toList();

  LibraryState copyWith({
    List<ImageItem>? images,
    Set<String>? selectedIds,
    String? currentDirectory,
    String? searchQuery,
    String? formatFilter,
    ImageSortBy? sortBy,
    ThumbnailSize? thumbnailSize,
    bool? isLoading,
    bool? isListView,
  }) {
    return LibraryState(
      images: images ?? this.images,
      selectedIds: selectedIds ?? this.selectedIds,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      searchQuery: searchQuery ?? this.searchQuery,
      formatFilter: formatFilter ?? this.formatFilter,
      sortBy: sortBy ?? this.sortBy,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      isLoading: isLoading ?? this.isLoading,
      isListView: isListView ?? this.isListView,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() => const LibraryState();

  void setImages(List<ImageItem> newImages) {
    state = state.copyWith(images: newImages, selectedIds: {});
  }

  void addImages(List<ImageItem> newImages) {
    final existingPaths = state.images.map((e) => e.path).toSet();
    final toAdd = newImages.where((e) => !existingPaths.contains(e.path)).toList();
    state = state.copyWith(images: [...state.images, ...toAdd]);
  }

  void toggleSelect(String id) {
    final current = Set<String>.from(state.selectedIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedIds: current);
  }

  void selectOnly(String id) {
    state = state.copyWith(selectedIds: {id});
  }

  void selectAll() {
    state = state.copyWith(selectedIds: state.filteredImages.map((e) => e.id).toSet());
  }

  void deselectAll() {
    state = state.copyWith(selectedIds: {});
  }

  void toggleFavorite(String id) {
    final updated = state.images.map((item) {
      if (item.id == id) {
        return item.copyWith(isFavorite: !item.isFavorite);
      }
      return item;
    }).toList();
    state = state.copyWith(images: updated);
  }

  void updateImage(ImageItem updatedItem) {
    final updated = state.images.map((item) {
      if (item.id == updatedItem.id) {
        return updatedItem;
      }
      return item;
    }).toList();
    state = state.copyWith(images: updated);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFormatFilter(String filter) {
    state = state.copyWith(formatFilter: filter);
  }

  void setSortBy(ImageSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void setThumbnailSize(ThumbnailSize size) {
    state = state.copyWith(thumbnailSize: size);
  }

  void toggleViewMode() {
    state = state.copyWith(isListView: !state.isListView);
  }

  Future<void> loadFolder(String dirPath) async {
    state = state.copyWith(isLoading: true, currentDirectory: dirPath);
    try {
      final items = await FileService.scanDirectory(dirPath);
      state = state.copyWith(images: items, selectedIds: {}, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshCurrentFolder() async {
    if (state.currentDirectory != null) {
      await loadFolder(state.currentDirectory!);
    }
  }

  Future<void> deleteSelected() async {
    final toDelete = state.selectedImages;
    for (final item in toDelete) {
      await FileService.deleteFile(item.path);
    }
    final remaining = state.images.where((e) => !state.selectedIds.contains(e.id)).toList();
    state = state.copyWith(images: remaining, selectedIds: {});
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);
