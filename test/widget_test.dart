import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hermes_app/main.dart';

void main() {
  testWidgets('Hermes app boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HermesApp()));
    // Avance le temps pour purger le timer du splash + animations.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
