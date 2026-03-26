import 'package:flutter_test/flutter_test.dart';
import 'package:floracloud/main.dart';

void main() {
  testWidgets('FloraCloud app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const FloraCloudApp());
    await tester.pump();
    expect(find.byType(FloraCloudApp), findsOneWidget);
  });
}
