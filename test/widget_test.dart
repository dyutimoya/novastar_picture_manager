import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastar_picture_manager/app/app.dart';

void main() {
  testWidgets('PictureManagerApp loads smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: PictureManagerApp()));
    await tester.pump();

    expect(find.text('PICTURE'), findsOneWidget);
    expect(find.text('MANAGER PRO'), findsOneWidget);
    expect(find.text('Batch Crop All'), findsOneWidget);
  });
}
