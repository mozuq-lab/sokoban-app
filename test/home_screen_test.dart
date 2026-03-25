import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokoban_app/features/game/presentation/home_screen.dart';

void main() {
  testWidgets('HomeScreen にタイトルとアイコンが表示される', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );

    expect(find.text('Sokoban'), findsOneWidget);
    expect(find.text('倉庫番'), findsOneWidget);
    expect(find.byIcon(Icons.grid_on), findsOneWidget);
  });
}
