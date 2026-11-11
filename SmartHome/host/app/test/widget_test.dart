import 'package:flutter_test/flutter_test.dart';
import 'package:smarthome_app/main.dart';

void main() {
  testWidgets('SmartHomeMiApp renders navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartHomeMiApp(autoConnect: false));
    expect(find.text('我的家'), findsOneWidget);
    expect(find.text('米家'), findsOneWidget);
    expect(find.text('智能'), findsOneWidget);
    expect(find.text('空间'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
