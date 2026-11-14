import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/crop_settings.dart';

enum HandleType { none, move, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left }

class InteractiveCropView extends StatefulWidget {
  final ImageProvider imageProvider;
  final double imageWidth;
  final double imageHeight;
  final CropSettings settings;
  final ValueChanged<NormalizedRect> onRectChanged;
  final ValueChanged<NormalizedRect> onRectChangeEnd;

  const InteractiveCropView({
    super.key,
    required this.imageProvider,
    required this.imageWidth,
    required this.imageHeight,
    required this.settings,
    required this.onRectChanged,
    required this.onRectChangeEnd,
  });

  @override
  State<InteractiveCropView> createState() => _InteractiveCropViewState();
}

class _InteractiveCropViewState extends State<InteractiveCropView> {
  HandleType _activeHandle = HandleType.none;
  Offset? _dragStartPos;
  NormalizedRect? _initialRect;

  static const double handleTouchRadius = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }

        // Calculate fitted image layout inside the available container
        final availW = constraints.maxWidth;
        final availH = constraints.maxHeight;

        double fittedW = availW;
        double fittedH = availH;

        if (widget.imageWidth > 0 && widget.imageHeight > 0) {
          final aspect = widget.imageWidth / widget.imageHeight;
          if (availW / availH > aspect) {
            fittedH = availH;
            fittedW = fittedH * aspect;
          } else {
            fittedW = availW;
            fittedH = fittedW / aspect;
          }
        }

        final offsetX = (availW - fittedW) / 2.0;
        final offsetY = (availH - fittedH) / 2.0;
        final imageRect = Rect.fromLTWH(offsetX, offsetY, fittedW, fittedH);

        final cropPixelRect = Rect.fromLTWH(
          imageRect.left + widget.settings.rect.left * fittedW,
          imageRect.top + widget.settings.rect.top * fittedH,
          widget.settings.rect.width * fittedW,
          widget.settings.rect.height * fittedH,
        );

        return Stack(
          children: [
            // Centered Image with rotation & flip
            Positioned.fromRect(
              rect: imageRect,
              child: ClipRect(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(widget.settings.totalAngle * pi / 180.0)
                    ..scale(widget.settings.flipHorizontal ? -1.0 : 1.0, widget.settings.flipVertical ? -1.0 : 1.0),
                  child: Image(image: widget.imageProvider, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                ),
              ),
            ),

            // Shading overlay, Crop box border, Grid, Handles
            Positioned.fill(
              child: MouseRegion(
                cursor: _getCursorForHandle(_activeHandle),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _onPointerDown(event, cropPixelRect, imageRect),
                  onPointerMove: (event) => _onPointerMove(event, imageRect),
                  onPointerUp: (event) => _onPointerUp(),
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      cropRect: cropPixelRect,
                      imageRect: imageRect,
                      activeHandle: _activeHandle,
                    ),
                  ),
                ),
              ),
            ),

            // Live Dimensions Pill at top of crop box
            if (widget.imageWidth > 0 && widget.imageHeight > 0)
              Positioned(
                left: cropPixelRect.left + 12,
                top: max(8, cropPixelRect.top - 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    '${(widget.settings.rect.width * widget.imageWidth).round()} × ${(widget.settings.rect.height * widget.imageHeight).round()} px',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  MouseCursor _getCursorForHandle(HandleType handle) {
    switch (handle) {
      case HandleType.move:
        return SystemMouseCursors.move;
      case HandleType.topLeft:
      case HandleType.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case HandleType.topRight:
      case HandleType.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
      case HandleType.top:
      case HandleType.bottom:
        return SystemMouseCursors.resizeUpDown;
      case HandleType.left:
      case HandleType.right:
        return SystemMouseCursors.resizeLeftRight;
      case HandleType.none:
        return SystemMouseCursors.basic;
    }
  }

  HandleType _detectHandle(Offset touchPos, Rect cropRect) {
    final tl = cropRect.topLeft;
    final tr = cropRect.topRight;
    final bl = cropRect.bottomLeft;
    final br = cropRect.bottomRight;
    final tc = cropRect.topCenter;
    final bc = cropRect.bottomCenter;
    final lc = cropRect.centerLeft;
    final rc = cropRect.centerRight;

    if ((touchPos - tl).distance <= handleTouchRadius) return HandleType.topLeft;
    if ((touchPos - tr).distance <= handleTouchRadius) return HandleType.topRight;
    if ((touchPos - bl).distance <= handleTouchRadius) return HandleType.bottomLeft;
    if ((touchPos - br).distance <= handleTouchRadius) return HandleType.bottomRight;
    if ((touchPos - tc).distance <= handleTouchRadius) return HandleType.top;
    if ((touchPos - bc).distance <= handleTouchRadius) return HandleType.bottom;
    if ((touchPos - lc).distance <= handleTouchRadius) return HandleType.left;
    if ((touchPos - rc).distance <= handleTouchRadius) return HandleType.right;

    if (cropRect.contains(touchPos)) {
      return HandleType.move;
    }
    return HandleType.none;
  }

  void _onPointerDown(PointerDownEvent event, Rect cropRect, Rect imageRect) {
    final handle = _detectHandle(event.localPosition, cropRect);
    if (handle != HandleType.none) {
      setState(() {
        _activeHandle = handle;
        _dragStartPos = event.localPosition;
        _initialRect = widget.settings.rect;
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event, Rect imageRect) {
    if (_activeHandle == HandleType.none || _dragStartPos == null || _initialRect == null) {
      return;
    }

    final deltaX = (event.localPosition.dx - _dragStartPos!.dx) / imageRect.width;
    final deltaY = (event.localPosition.dy - _dragStartPos!.dy) / imageRect.height;

    final initial = _initialRect!;
    final lockedRatio = widget.settings.targetRatioValue;
    final imgAspect = (widget.imageWidth > 0 && widget.imageHeight > 0) ? widget.imageWidth / widget.imageHeight : 1.0;

    double left = initial.left;
    double top = initial.top;
    double width = initial.width;
    double height = initial.height;

    switch (_activeHandle) {
      case HandleType.move:
        left = (initial.left + deltaX).clamp(0.0, 1.0 - initial.width);
        top = (initial.top + deltaY).clamp(0.0, 1.0 - initial.height);
        break;

      case HandleType.topLeft:
        left = (initial.left + deltaX).clamp(0.0, initial.right - 0.05);
        top = (initial.top + deltaY).clamp(0.0, initial.bottom - 0.05);
        width = initial.right - left;
        height = initial.bottom - top;
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, initial.bottom);
          top = initial.bottom - height;
        }
        break;

      case HandleType.topRight:
        top = (initial.top + deltaY).clamp(0.0, initial.bottom - 0.05);
        width = (initial.width + deltaX).clamp(0.05, 1.0 - initial.left);
        height = initial.bottom - top;
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, initial.bottom);
          top = initial.bottom - height;
        }
        break;

      case HandleType.bottomLeft:
        left = (initial.left + deltaX).clamp(0.0, initial.right - 0.05);
        width = initial.right - left;
        height = (initial.height + deltaY).clamp(0.05, 1.0 - initial.top);
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, 1.0 - initial.top);
        }
        break;

      case HandleType.bottomRight:
        width = (initial.width + deltaX).clamp(0.05, 1.0 - initial.left);
        height = (initial.height + deltaY).clamp(0.05, 1.0 - initial.top);
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, 1.0 - initial.top);
        }
        break;

      case HandleType.top:
        top = (initial.top + deltaY).clamp(0.0, initial.bottom - 0.05);
        height = initial.bottom - top;
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          width = (height * targetNormRatio).clamp(0.05, 1.0 - initial.left);
        }
        break;

      case HandleType.bottom:
        height = (initial.height + deltaY).clamp(0.05, 1.0 - initial.top);
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          width = (height * targetNormRatio).clamp(0.05, 1.0 - initial.left);
        }
        break;

      case HandleType.left:
        left = (initial.left + deltaX).clamp(0.0, initial.right - 0.05);
        width = initial.right - left;
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, 1.0 - initial.top);
        }
        break;

      case HandleType.right:
        width = (initial.width + deltaX).clamp(0.05, 1.0 - initial.left);
        if (lockedRatio != null && lockedRatio > 0) {
          final targetNormRatio = lockedRatio / imgAspect;
          height = (width / targetNormRatio).clamp(0.05, 1.0 - initial.top);
        }
        break;

      case HandleType.none:
        break;
    }

    final newRect = NormalizedRect(
      left: left.clamp(0.0, 1.0 - width),
      top: top.clamp(0.0, 1.0 - height),
      width: width.clamp(0.05, 1.0),
      height: height.clamp(0.05, 1.0),
    );

    widget.onRectChanged(newRect);
  }

  void _onPointerUp() {
    if (_activeHandle != HandleType.none) {
      widget.onRectChangeEnd(widget.settings.rect);
      setState(() {
        _activeHandle = HandleType.none;
        _dragStartPos = null;
        _initialRect = null;
      });
    }
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Rect imageRect;
  final HandleType activeHandle;

  _CropOverlayPainter({required this.cropRect, required this.imageRect, required this.activeHandle});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark dim mask outside cropRect but inside imageRect
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.58);

    final path = Path()
      ..addRect(imageRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, dimPaint);

    // 2. Dashed / Crisp Crop Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRect(cropRect, borderPaint);

    // 3. Rule of Thirds Grid Lines inside crop rectangle
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final thirdW = cropRect.width / 3.0;
    final thirdH = cropRect.height / 3.0;

    // Vertical lines
    canvas.drawLine(
      Offset(cropRect.left + thirdW, cropRect.top),
      Offset(cropRect.left + thirdW, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdW * 2, cropRect.top),
      Offset(cropRect.left + thirdW * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH),
      Offset(cropRect.right, cropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdH * 2),
      Offset(cropRect.right, cropRect.top + thirdH * 2),
      gridPaint,
    );

    // 4. Draw 8 Control Handles (white filled circles with subtle border & shadow, matching modern UI image 2!)
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const radius = 6.0;

    final points = [
      cropRect.topLeft,
      cropRect.topCenter,
      cropRect.topRight,
      cropRect.centerRight,
      cropRect.bottomRight,
      cropRect.bottomCenter,
      cropRect.bottomLeft,
      cropRect.centerLeft,
    ];

    for (final pt in points) {
      canvas.drawCircle(pt, radius, handlePaint);
      canvas.drawCircle(pt, radius, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.activeHandle != activeHandle;
  }
}
