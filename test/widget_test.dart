import 'package:flutter_test/flutter_test.dart';
import 'package:physical_therapy/app/app.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PhysioApp());

    expect(find.byType(PhysioApp), findsOneWidget);
  });
}