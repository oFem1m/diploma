import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Оптимизатор BBO'), findsOneWidget);
  });
}
