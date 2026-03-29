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

  testWidgets('リスタートボタンが AppBar と画面下部に表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byIcon(Icons.refresh), findsNWidgets(2));
  });

  testWidgets('方向ボタンを押すとプレイヤーが移動する', (tester) async {
    await tester.pumpWidget(buildApp());

    // 箱アイコンが 3 つ（盤面 2 + 進捗カード 1）
    expect(find.byIcon(Icons.inventory_2), findsNWidgets(3));

    // 下ボタンを押して盤面更新
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // プレイヤーがまだ存在する
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('クリア前はクリアメッセージが表示されない', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.textContaining('クリア！'), findsNothing);
  });

  testWidgets('リスタートで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 何手か動かす
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // リスタート
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();

    // プレイヤーと箱がまだ存在
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2), findsNWidgets(3));
  });

  testWidgets('Undo ボタンが AppBar と画面下部に表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byIcon(Icons.undo), findsNWidgets(2));
  });

  testWidgets('初期状態では Undo ボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final undoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('移動後に Undo すると元の状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // Undo ボタンが有効になっている
    final undoAfterMove = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoAfterMove.onPressed, isNotNull);

    // Undo
    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();

    // プレイヤーと箱がまだ存在
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2), findsNWidgets(3));

    // Undo 後は再び無効
    final undoAfterUndo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoAfterUndo.onPressed, isNull);
  });

  testWidgets('リスタートで Undo 履歴がクリアされる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 移動
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // リスタート
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();

    // Undo ボタンが無効
    final undoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('クリア後に Undo するとクリア表示が消える', (tester) async {
    await tester.pumpWidget(buildApp());

    // 解法: 下, 上, 右, 下
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    expect(find.text('クリア！ 4手'), findsOneWidget);

    // Undo
    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();

    expect(find.textContaining('クリア！'), findsNothing);
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

    expect(find.text('クリア！ 4手'), findsOneWidget);
  });

  // --- 手数カウンタのテスト ---

  testWidgets('初期状態で手数が 0 と表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('手数'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('移動成功で手数が増える', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('壁にぶつかる移動では手数が増えない', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功: (2,2) → (1,2)）
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // さらに左に移動（壁 (0,2) で blocked）
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Undo で手数が 1 戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('リスタートで手数が 0 に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('クリア後も手数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());

    // 解法: 下, 上, 右, 下 (4 手)
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    expect(find.text('クリア！ 4手'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  // --- クリア後の方向ボタン無効化テスト ---

  /// ステージを解法手順でクリアするヘルパー。
  Future<void> solveStage(WidgetTester tester) async {
    // 解法: 下, 上, 右, 下
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
  }

  testWidgets('クリア後に方向ボタンが無効になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('クリア！ 4手'), findsOneWidget);

    // 各方向ボタンの onPressed が null であることを確認
    for (final icon in [
      Icons.arrow_upward,
      Icons.arrow_downward,
      Icons.arrow_back,
      Icons.arrow_forward,
    ]) {
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, icon),
      );
      expect(button.onPressed, isNull, reason: '$icon should be disabled');
    }
  });

  testWidgets('クリア後でも Undo でクリア状態を戻せる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('クリア！ 4手'), findsOneWidget);

    // Undo ボタンが有効であることを確認
    final undoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undoButton.onPressed, isNotNull);

    // Undo を実行
    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();

    // クリア表示が消える
    expect(find.textContaining('クリア！'), findsNothing);

    // 方向ボタンが再び有効になる
    final upButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_upward),
    );
    expect(upButton.onPressed, isNotNull);
  });

  // --- SafeArea・レイアウトのテスト ---

  testWidgets('body が SafeArea で囲まれ最大幅 480 の制約がある', (tester) async {
    await tester.pumpWidget(buildApp());
    // maxWidth: 480 の ConstrainedBox を探す
    final finder = find.byWidgetPredicate(
      (w) => w is ConstrainedBox && w.constraints.maxWidth == 480,
    );
    expect(finder, findsOneWidget);

    // その ConstrainedBox が SafeArea の子孫であることを確認
    final safeAreaFinder = find.ancestor(
      of: finder,
      matching: find.byType(SafeArea),
    );
    expect(safeAreaFinder, findsWidgets);
  });

  testWidgets('クリア後でも Restart が使える', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('クリア！ 4手'), findsOneWidget);

    // Restart ボタンが有効であることを確認
    final restartButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(restartButton.onPressed, isNotNull);

    // Restart を実行
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();

    // クリア表示が消え、手数が 0 に戻る
    expect(find.textContaining('クリア！'), findsNothing);
    expect(find.text('0'), findsOneWidget);

    // 方向ボタンが再び有効になる
    final upButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_upward),
    );
    expect(upButton.onPressed, isNotNull);
  });

  // --- 画面下部の補助ボタンのテスト ---

  testWidgets('画面下部に「元に戻す」「リスタート」テキストが表示される',
      (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('元に戻す'), findsOneWidget);
    expect(find.text('リスタート'), findsOneWidget);
  });

  // --- リスタートボタン初期無効化のテスト ---

  testWidgets('初期状態では AppBar のリスタートボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final restartButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(restartButton.onPressed, isNull);
  });

  testWidgets('初期状態では画面下部のリスタートボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final bottomRestart = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'リスタート'),
    );
    expect(bottomRestart.onPressed, isNull);
  });

  testWidgets('移動後にリスタートボタンが有効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(restartButton.onPressed, isNotNull);

    final bottomRestart = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'リスタート'),
    );
    expect(bottomRestart.onPressed, isNotNull);
  });

  testWidgets('リスタート実行後にリスタートボタンが再び無効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // リスタート実行
    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(restartButton.onPressed, isNull);

    final bottomRestart = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'リスタート'),
    );
    expect(bottomRestart.onPressed, isNull);
  });

  testWidgets('Undo で初期状態に戻るとリスタートボタンが無効になる',
      (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    // Undo で初期状態に戻す
    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(restartButton.onPressed, isNull);
  });

  testWidgets('画面下部の Undo ボタンが初期状態で無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final bottomUndo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '元に戻す'),
    );
    expect(bottomUndo.onPressed, isNull);
  });

  testWidgets('画面下部の Undo ボタンが移動後に有効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    final bottomUndo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '元に戻す'),
    );
    expect(bottomUndo.onPressed, isNotNull);
  });

  testWidgets('画面下部の Undo ボタンで手数が戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '元に戻す'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('画面下部の Restart ボタンで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'リスタート'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('下部ボタンが Expanded で均等幅になっている', (tester) async {
    await tester.pumpWidget(buildApp());
    // OutlinedButton が 2 つ Expanded の子として存在する
    final expandedButtons = find.ancestor(
      of: find.byType(OutlinedButton),
      matching: find.byType(Expanded),
    );
    expect(expandedButtons, findsNWidgets(2));
  });

  testWidgets('下部ボタンの最小高さが 48 以上である', (tester) async {
    await tester.pumpWidget(buildApp());
    final undoButton = tester.getSize(
      find.widgetWithText(OutlinedButton, '元に戻す'),
    );
    final restartButton = tester.getSize(
      find.widgetWithText(OutlinedButton, 'リスタート'),
    );
    expect(undoButton.height, greaterThanOrEqualTo(48));
    expect(restartButton.height, greaterThanOrEqualTo(48));
  });

  // --- 残り箱数表示のテスト ---

  testWidgets('初期状態で残り箱数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('配置'), findsOneWidget);
    expect(find.text('あと2個'), findsOneWidget);
  });

  testWidgets('箱をゴールに押すと残り数が減る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('あと1個'), findsOneWidget);
  });

  testWidgets('Undo で箱がゴールから外れると残り数が戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('あと1個'), findsOneWidget);

    // Undo: 箱がゴールから外れる
    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();
    expect(find.text('あと2個'), findsOneWidget);
  });

  testWidgets('リスタートで残り箱数が初期値に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    expect(find.text('あと1個'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    expect(find.text('あと2個'), findsOneWidget);
  });

  // --- 操作ヒント表示のテスト ---

  testWidgets('通常時に操作ヒントが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(
      find.text('方向ボタンで移動 ／ 元に戻す・リスタートでやり直し'),
      findsOneWidget,
    );
  });

  testWidgets('クリア後にヒントがクリア済み文言に切り替わる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(
      find.text('クリア済み — 元に戻す・リスタートで続けられます'),
      findsOneWidget,
    );
    expect(
      find.text('方向ボタンで移動 ／ 元に戻す・リスタートでやり直し'),
      findsNothing,
    );
  });

  testWidgets('クリア後に Undo するとヒントが通常文言に戻る', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    await tester.tap(find.byIcon(Icons.undo).first);
    await tester.pump();

    expect(
      find.text('方向ボタンで移動 ／ 元に戻す・リスタートでやり直し'),
      findsOneWidget,
    );
    expect(
      find.text('クリア済み — 元に戻す・リスタートで続けられます'),
      findsNothing,
    );
  });

  testWidgets('クリア時に全配置と表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('全配置！'), findsOneWidget);
  });
}
