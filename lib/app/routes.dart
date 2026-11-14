import 'package:go_router/go_router.dart';

import '../core/models/image_item.dart';
import '../features/browser/browser_screen.dart';
import '../features/batch_crop/batch_crop_screen.dart';
import '../features/editing/editor_screen.dart';
import '../features/viewer/image_viewer_screen.dart';

GoRouter createAppRouter([ImageItem? initialImage]) {
  return GoRouter(
    initialLocation: initialImage != null ? '/viewer' : '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const BrowserScreen()),
      GoRoute(
        path: '/viewer',
        builder: (context, state) {
          final item = (state.extra as ImageItem?) ?? initialImage;
          if (item == null) {
            return const BrowserScreen();
          }
          return ImageViewerScreen(initialItem: item);
        },
      ),
      GoRoute(path: '/crop', builder: (context, state) => const BatchCropScreen()),
      GoRoute(
        path: '/edit',
        builder: (context, state) {
          final item = state.extra as ImageItem;
          return EditorScreen(item: item);
        },
      ),
    ],
  );
}

final appRouter = createAppRouter();
