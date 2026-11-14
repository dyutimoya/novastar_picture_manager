import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/batch_crop_provider.dart';

class BatchCropReviewDialog extends ConsumerWidget {
  final VoidCallback onProceedToExport;

  const BatchCropReviewDialog({super.key, required this.onProceedToExport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(batchCropProvider);
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: const Color(0xFF1E1E24),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Batch Crop Review (${batchState.images.length} images)',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Verify the crop framing and output dimensions for each image before exporting.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),

            // Grid of review cards
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 260,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: batchState.images.length,
                itemBuilder: (context, index) {
                  final item = batchState.images[index];
                  final crop = batchState.settingsMap[item.id] ?? item.cropSettings;
                  final outW = (item.width * crop.rect.width).round();
                  final outH = (item.height * crop.rect.height).round();
                  final isInvalid = outW < 20 || outH < 20;

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A32),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isInvalid ? Colors.redAccent : Colors.white10,
                        width: isInvalid ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image preview with crop box overlay
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: Colors.black45,
                                child: item.thumbnailBytes != null
                                    ? Image.memory(item.thumbnailBytes!, fit: BoxFit.contain)
                                    : (!kIsWeb && File(item.path).existsSync()
                                          ? Image.file(File(item.path), fit: BoxFit.contain)
                                          : const Center(child: Icon(Icons.image, color: Colors.white30))),
                              ),
                              // Relative crop frame indicator
                              Positioned(
                                left: crop.rect.left * 100,
                                top: crop.rect.top * 100,
                                width: (crop.rect.width * 100).clamp(10, 100),
                                height: (crop.rect.height * 100).clamp(10, 100),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.greenAccent, width: 1.5),
                                    color: Colors.greenAccent.withOpacity(0.15),
                                  ),
                                ),
                              ),
                              if (isInvalid)
                                Container(
                                  color: Colors.red.withOpacity(0.7),
                                  child: const Center(
                                    child: Text(
                                      'Crop Too Small',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Info section
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${outW}x${outH} px',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      crop.aspectRatio.label,
                                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                height: 26,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    side: const BorderSide(color: Colors.white24),
                                  ),
                                  onPressed: () {
                                    ref.read(batchCropProvider.notifier).selectImage(index);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Edit Framing', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Editor', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Proceed to Export'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onProceedToExport();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
