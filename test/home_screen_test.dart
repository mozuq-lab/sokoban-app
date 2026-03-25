import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokoban_app/features/game/presentation/home_screen.dart';

void main() {
  Widget buildApp() => const MaterialApp(home: HomeScreen());

  testWidgets('AppBar にタイトルが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('Sokoban'), findsOneWidget);
  });

  testWidgets('盤面とプレイヤーが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('方向ボタンが 4 つ表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('リスタートボタンが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('方向ボタンを押すとプレイヤーが移動する', (tester) async {
    await tester.pumpWidget(buildApp());

    // 箱アイコンが 2 つ
    expect(find.byIcon(Icons.inventory_2), findsNWidgets(2));

    // 下ボタンを押して盤面更新
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // プレイヤーがまだ存在する
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('クリア前はクリアメッセージが表示されない', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('クリア！'), findsNothing);
  });

  testWidgets('リスタートで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 何手か動かす
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // リスタート
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    // プレイヤーと箱がまだ存在
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2), findsNWidgets(2));
  });

  testWidgets('全箱をゴールに載せるとクリアメッセージが表示される',
      (tester) async {
    await tester.pumpWidget(buildApp());

    // 盤面:
    // ######
    // #    #
    // # @  #       player(2,2)
    // # $$ #       boxes(2,3),(3,3)
    // # .. #       goals(2,4),(3,4)
    // ######
    //
    // 解法: 下(box(2,3)→(2,4)), 上, 右, 下(box(3,3)→(3,4))

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    // box(2,3)→(2,4) [goal!], player→(2,3)

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    // player→(2,2)

    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    // player→(3,2)

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    // box(3,3)→(3,4) [goal!], player→(3,3). Solved!

    expect(find.text('クリア！'), findsOneWidget);
  });
}
