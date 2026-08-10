import 'package:flutter_test/flutter_test.dart';

import 'package:amora_florals_mobile/main.dart';

void main() {
  testWidgets('Home loads trending section', (WidgetTester tester) async {
    await tester.pumpWidget(const AmoraFloralsApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Trending Flowers'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
