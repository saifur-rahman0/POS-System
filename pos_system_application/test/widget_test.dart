import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_client/app/app.dart';

void main() {
  testWidgets('App shell boots and displays title and destinations', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PosApp(),
      ),
    );

    // Verify app bar title
    expect(find.text('Retail POS — Local Terminal'), findsOneWidget);

    // Verify navigation destinations
    expect(find.text('POS Register'), findsWidgets);
    expect(find.text('Catalog & Stock'), findsOneWidget);
    expect(find.text('Sales History'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

