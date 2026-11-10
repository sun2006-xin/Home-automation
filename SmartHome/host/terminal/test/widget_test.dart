import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_kiosk/main.dart';

void main() {
  testWidgets('Terminal App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TerminalApp());

    // Verify that clock or main screen loads
    expect(find.byType(TerminalApp), findsOneWidget);
  });
}
