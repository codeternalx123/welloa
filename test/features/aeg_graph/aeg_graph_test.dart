import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:longevity/features/aeg_graph/aeg_graph_screen.dart';

void main() {
  testWidgets('AEG Graph Screen renders correctly and shows loading state when button pressed', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AEGGraphScreen(),
        ),
      ),
    );

    // Initial render
    expect(find.text('AEG Biological Network'), findsOneWidget);
    expect(find.text('Synthesize Network (Demo)'), findsOneWidget);

    // Tap button
    await tester.tap(find.text('Synthesize Network (Demo)'));
    await tester.pump();

    // Verify loading state
    expect(find.text('Synthesizing multi-node causal graph...'), findsOneWidget);
  });
}
