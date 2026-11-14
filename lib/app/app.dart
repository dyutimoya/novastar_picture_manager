import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/image_item.dart';
import '../core/state/library_provider.dart';
import 'routes.dart';
import 'theme.dart';

class PictureManagerApp extends ConsumerStatefulWidget {
  final ImageItem? initialImage;
  final List<ImageItem>? initialFolderImages;

  const PictureManagerApp({super.key, this.initialImage, this.initialFolderImages});

  @override
  ConsumerState<PictureManagerApp> createState() => _PictureManagerAppState();
}

class _PictureManagerAppState extends ConsumerState<PictureManagerApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.initialImage);

    if (widget.initialFolderImages != null && widget.initialFolderImages!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(libraryProvider.notifier).setImages(widget.initialFolderImages!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Novastar Picture Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
