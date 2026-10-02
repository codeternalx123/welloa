import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:longevity/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end app flow test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // In a real scenario we'd click through navigation and verify dashboards load.
    // For now we just verify the app launches successfully.
    expect(find.byType(app.MyApp), findsOneWidget);
  });
}
