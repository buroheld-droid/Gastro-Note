// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gastro_note/app.dart';

void main() {
  testWidgets('App startet und zeigt PIN-Login', (WidgetTester tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1280, 900);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ProviderScope(child: GastroNoteApp()));
    await tester.pumpAndSettle();

    // App sollte PIN-Login Screen zeigen (da nicht eingeloggt)
    expect(find.text('PIN-Code eingeben'), findsOneWidget);
  });
}
