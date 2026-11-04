import 'package:flutter_test/flutter_test.dart';
import 'package:vendix/main.dart';

void main() {
  testWidgets('La aplicación Vendix inicia', (tester) async {
    await tester.pumpWidget(const VendixApp());

    expect(find.byType(VendixApp), findsOneWidget);
  });
}
