import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokoban_app/features/game/presentation/game_painters.dart';
import 'package:sokoban_app/features/game/presentation/home_screen.dart';

void main() {
  /// テスト用の初期レベルデータ。
  const testLevel = [
    '######',
    '#    #',
    '# @  #',
    '# \$\$ #',
    '# .. #',
    '######',
  ];

  Widget buildApp() => const MaterialApp(
        home: HomeScreen(initialLevel: testLevel),
      );

  testWidgets('AppBar にタイトルが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('Sokoban'), findsOneWidget);
  });

  testWidgets('盤面とプレイヤーが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byType(PlayerWidget), findsOneWidget);
  });

  testWidgets('方向ボタンが 4 つ表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    for (final label in ['上', '下', '左', '右']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
  });

  testWidgets('方向ボタンにキーヒント (WASD) が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    for (final hint in ['W', 'A', 'S', 'D']) {
      expect(find.text(hint), findsOneWidget);
    }
  });

  testWidgets('リスタートボタンが AppBar と画面下部に表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // AppBar にリスタートアイコン、画面下部にテキスト「リスタート」
    expect(find.byKey(const ValueKey('appbar-restart')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-restart')), findsOneWidget);
  });

  testWidgets('方向ボタンを押すとプレイヤーが移動する', (tester) async {
    await tester.pumpWidget(buildApp());

    // 箱アイコンが 3 つ（盤面 2 + 進捗カード 1）
    expect(find.byType(BoxWidget), findsNWidgets(2));

    // 下ボタンを押して盤面更新
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // プレイヤーがまだ存在する
    expect(find.byType(PlayerWidget), findsOneWidget);
  });

  testWidgets('クリア前はクリアメッセージが表示されない', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.textContaining('クリア！'), findsNothing);
  });

  testWidgets('リスタートで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 何手か動かす
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // リスタート
    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();

    // プレイヤーと箱がまだ存在
    expect(find.byType(PlayerWidget), findsOneWidget);
    expect(find.byType(BoxWidget), findsNWidgets(2));
  });

  testWidgets('Undo ボタンが AppBar と画面下部に表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // AppBar に元に戻すアイコン、画面下部にテキスト「元に戻す」
    expect(find.byKey(const ValueKey('appbar-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-undo')), findsOneWidget);
  });

  testWidgets('初期状態では Undo ボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-undo')),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('移動後に Undo すると元の状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // Undo ボタンが有効になっている
    final undoAfterMove = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-undo')),
    );
    expect(undoAfterMove.onPressed, isNotNull);

    // Undo
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    // プレイヤーと箱がまだ存在
    expect(find.byType(PlayerWidget), findsOneWidget);
    expect(find.byType(BoxWidget), findsNWidgets(2));

    // Undo 後は再び無効
    final undoAfterUndo = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-undo')),
    );
    expect(undoAfterUndo.onPressed, isNull);
  });

  testWidgets('リスタートで Undo 履歴がクリアされる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 移動
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // リスタート
    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();

    // Undo ボタンが無効
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-undo')),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('クリア後に Undo するとクリア表示が消える', (tester) async {
    await tester.pumpWidget(buildApp());

    // 解法: 下, 上, 右, 下
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    await tester.tap(find.byTooltip('右'));
    await tester.pump();
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    expect(find.text('クリア！'), findsNWidgets(2));

    // Undo
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    expect(find.textContaining('クリア！'), findsNothing);
  });

  testWidgets('全箱をゴールに載せるとクリアメッセージが表示される', (tester) async {
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

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    // box(2,3)→(2,4) [goal!], player→(2,3)

    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    // player→(2,2)

    await tester.tap(find.byTooltip('右'));
    await tester.pump();
    // player→(3,2)

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    // box(3,3)→(3,4) [goal!], player→(3,3). Solved!

    expect(find.text('クリア！'), findsNWidgets(2));
  });

  // --- 手数カウンタのテスト ---

  testWidgets('初期状態で手数が 0 と表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('手数'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('移動成功で手数が増える', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('壁にぶつかる移動では手数が増えない', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功: (2,2) → (1,2)）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // さらに左に移動（壁 (0,2) で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Undo で手数が 1 戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('リスタートで手数が 0 に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('クリア後も手数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());

    // 解法: 下, 上, 右, 下 (4 手)
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    await tester.tap(find.byTooltip('右'));
    await tester.pump();
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    expect(find.text('クリア！'), findsNWidgets(2));
    expect(find.text('4'), findsOneWidget);
  });

  // --- クリア後の方向ボタン無効化テスト ---

  /// ステージを解法手順でクリアするヘルパー。
  Future<void> solveStage(WidgetTester tester) async {
    // 解法: 下, 上, 右, 下
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    await tester.tap(find.byTooltip('上'));
    await tester.pump();
    await tester.tap(find.byTooltip('右'));
    await tester.pump();
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
  }

  testWidgets('クリア後に方向ボタンが無効になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('クリア！'), findsNWidgets(2));

    // 各方向ボタンの InkWell.onTap が null であることを確認
    for (final label in ['上', '下', '左', '右']) {
      final inkWell = tester.widget<InkWell>(
        find.descendant(
          of: find.byTooltip(label),
          matching: find.byType(InkWell),
        ),
      );
      expect(inkWell.onTap, isNull, reason: '$label should be disabled');
    }
  });

  testWidgets('クリア後でも Undo でクリア状態を戻せる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('クリア！'), findsNWidgets(2));

    // Undo ボタンが有効であることを確認
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-undo')),
    );
    expect(undoButton.onPressed, isNotNull);

    // Undo を実行
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    // クリア表示が消える
    expect(find.textContaining('クリア！'), findsNothing);

    // 方向ボタンが再び有効になる
    final upInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('上'),
        matching: find.byType(InkWell),
      ),
    );
    expect(upInkWell.onTap, isNotNull);
  });

  // --- SafeArea・レイアウトのテスト ---

  testWidgets('body が SafeArea で囲まれ ConstrainedBox の制約がある', (tester) async {
    await tester.pumpWidget(buildApp());
    // ConstrainedBox を探す（狭い画面: 480、広い画面: 960）
    final finder = find.byWidgetPredicate(
      (w) =>
          w is ConstrainedBox &&
          (w.constraints.maxWidth == 480 || w.constraints.maxWidth == 960),
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

    expect(find.text('クリア！'), findsNWidgets(2));

    // Restart ボタンが有効であることを確認
    final restartButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-restart')),
    );
    expect(restartButton.onPressed, isNotNull);

    // Restart を実行
    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();

    // クリア表示が消え、手数が 0 に戻る
    expect(find.textContaining('クリア！'), findsNothing);
    expect(find.text('0'), findsOneWidget);

    // 方向ボタンが再び有効になる
    final upInkWell2 = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('上'),
        matching: find.byType(InkWell),
      ),
    );
    expect(upInkWell2.onTap, isNotNull);
  });

  // --- 画面下部の補助ボタンのテスト ---

  testWidgets('画面下部に「元に戻す」「リスタート」テキストが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('元に戻す'), findsOneWidget);
    expect(find.text('リスタート'), findsOneWidget);
  });

  // --- リスタートボタン初期無効化のテスト ---

  testWidgets('初期状態では AppBar のリスタートボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final restartButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-restart')),
    );
    expect(restartButton.onPressed, isNull);
  });

  testWidgets('初期状態では画面下部のリスタートボタンが無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-restart')),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNull);
  });

  testWidgets('移動後にリスタートボタンが有効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-restart')),
    );
    expect(restartButton.onPressed, isNotNull);

    final bottomRestartInk = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-restart')),
        matching: find.byType(InkWell),
      ),
    );
    expect(bottomRestartInk.onTap, isNotNull);
  });

  testWidgets('リスタート実行後にリスタートボタンが再び無効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // リスタート実行
    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-restart')),
    );
    expect(restartButton.onPressed, isNull);

    final bottomRestartInk2 = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-restart')),
        matching: find.byType(InkWell),
      ),
    );
    expect(bottomRestartInk2.onTap, isNull);
  });

  testWidgets('Undo で初期状態に戻るとリスタートボタンが無効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // Undo で初期状態に戻す
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    final restartButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('appbar-restart')),
    );
    expect(restartButton.onPressed, isNull);
  });

  testWidgets('画面下部の Undo ボタンが初期状態で無効', (tester) async {
    await tester.pumpWidget(buildApp());
    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-undo')),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNull);
  });

  testWidgets('画面下部の Undo ボタンが移動後に有効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    final inkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-undo')),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNotNull);
  });

  testWidgets('画面下部の Undo ボタンで手数が戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('bottom-undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-undo')));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('画面下部の Restart ボタンで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('bottom-restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-restart')));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(PlayerWidget), findsOneWidget);
  });

  testWidgets('下部ボタンが Expanded で均等幅になっている', (tester) async {
    await tester.pumpWidget(buildApp());
    // 補助ボタンが Expanded の子として存在する
    final expandedUndo = find.ancestor(
      of: find.byKey(const ValueKey('bottom-undo')),
      matching: find.byType(Expanded),
    );
    final expandedRestart = find.ancestor(
      of: find.byKey(const ValueKey('bottom-restart')),
      matching: find.byType(Expanded),
    );
    expect(expandedUndo, findsAtLeastNWidgets(1));
    expect(expandedRestart, findsAtLeastNWidgets(1));
  });

  testWidgets('下部ボタンの最小高さが 48 以上である', (tester) async {
    await tester.pumpWidget(buildApp());
    final undoButton = tester.getSize(
      find.byKey(const ValueKey('bottom-undo')),
    );
    final restartButton = tester.getSize(
      find.byKey(const ValueKey('bottom-restart')),
    );
    expect(undoButton.height, greaterThanOrEqualTo(48));
    expect(restartButton.height, greaterThanOrEqualTo(48));
  });

  // --- 操作ボタンの disabled 状態の視覚表示テスト ---

  testWidgets('初期状態の補助ボタンが Opacity で薄く表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // 初期状態では履歴がないので Undo / Restart は disabled
    final undoOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-undo')),
        matching: find.byType(Opacity),
      ),
    );
    expect(undoOpacity.opacity, lessThan(1.0));

    final restartOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-restart')),
        matching: find.byType(Opacity),
      ),
    );
    expect(restartOpacity.opacity, lessThan(1.0));
  });

  testWidgets('移動後の補助ボタンが不透明になる', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    final undoOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('bottom-undo')),
        matching: find.byType(Opacity),
      ),
    );
    expect(undoOpacity.opacity, equals(1.0));
  });

  testWidgets('クリア後に方向ボタンが Opacity で薄く表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    // 方向ボタンの Opacity を確認
    final upOpacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byTooltip('上'),
        matching: find.byType(Opacity),
      ),
    );
    expect(upOpacity.opacity, lessThan(1.0));
  });

  // --- 残り箱数表示のテスト ---

  testWidgets('初期状態で残り箱数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('配置'), findsOneWidget);
    // ステータスカードとバナー進捗チップの両方に表示される
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  testWidgets('箱をゴールに押すと残り数が減る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    // ステータスカードとバナー進捗チップの両方に表示される
    expect(find.text('1 / 2'), findsNWidgets(2));
  });

  testWidgets('Undo で箱がゴールから外れると残り数が戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1 / 2'), findsNWidgets(2));

    // Undo: 箱がゴールから外れる
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  testWidgets('リスタートで残り箱数が初期値に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1 / 2'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pump();
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  // --- 操作ヒント表示のテスト ---

  testWidgets('通常時に操作ヒントが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(
      find.byKey(const Key('hint_move')),
      findsOneWidget,
    );
  });

  testWidgets('クリア後にヒントがクリア済み文言に切り替わる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    // ヒントチップに「クリア済み」が表示される
    expect(
      find.byKey(const Key('hint_cleared')),
      findsOneWidget,
    );
    // 移動ヒントが消える
    expect(
      find.byKey(const Key('hint_move')),
      findsNothing,
    );
  });

  testWidgets('クリア後に Undo するとヒントが通常文言に戻る', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    expect(
      find.byKey(const Key('hint_move')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('hint_cleared')),
      findsNothing,
    );
  });

  testWidgets('ヒントチップの操作名とキーヒントが分離して表示される', (tester) async {
    await tester.pumpWidget(buildApp());

    // 移動ヒントチップ内に Text.rich が使われ、操作名とキーヒントが含まれる
    final moveChip = find.byKey(const Key('hint_move'));
    expect(moveChip, findsOneWidget);
    final richText = find.descendant(
      of: moveChip,
      matching: find.byType(RichText),
    );
    expect(richText, findsOneWidget);

    // Undo・リスタートのヒントチップも存在する
    expect(find.byKey(const Key('hint_undo')), findsOneWidget);
    expect(find.byKey(const Key('hint_restart')), findsOneWidget);
  });

  testWidgets('クリア済みヒントチップにアイコンが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    final clearedChip = find.byKey(const Key('hint_cleared'));
    expect(clearedChip, findsOneWidget);

    // チップ内にチェックアイコンがある
    final iconFinder = find.descendant(
      of: clearedChip,
      matching: find.byIcon(Icons.check_circle_outline),
    );
    expect(iconFinder, findsOneWidget);
  });

  // --- 移動失敗フィードバックのテスト ---

  testWidgets('壁に向かって移動するとサマリー帯にブロック文言が表示される', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功: (2,2) → (1,2)）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左に移動（壁 (0,2) で blocked）
    await tester.tap(find.byTooltip('左'));
    // AnimatedSwitcher の遷移を完了させる（タイマー 1 秒より前）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // サマリー帯にブロック文言が表示される
    expect(find.text('その方向には進めません'), findsOneWidget);
    // ヒント行は通常文言のまま表示される
    expect(
      find.byKey(const Key('hint_move')),
      findsOneWidget,
    );
  });

  testWidgets('ブロック文言が約 1 秒後に自動で消える', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('その方向には進めません'), findsOneWidget);

    // 1 秒経過させてタイマー発火
    await tester.pump(const Duration(seconds: 1));
    // AnimatedSwitcher 遷移を完了させる
    await tester.pumpAndSettle();

    // サマリー帯が進捗表示に戻る
    expect(find.text('その方向には進めません'), findsNothing);
    expect(find.text('あと 2 個で完了'), findsOneWidget);
  });

  testWidgets('ブロック後に成功移動するとサマリー帯が進捗表示に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(find.text('その方向には進めません'), findsOneWidget);

    // 右に移動（成功）
    await tester.tap(find.byTooltip('右'));
    await tester.pumpAndSettle();

    expect(find.text('その方向には進めません'), findsNothing);
    expect(find.text('あと 2 個で完了'), findsOneWidget);
  });

  testWidgets('ブロック後に Undo するとサマリー帯が進捗表示に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動（成功）
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // 左に移動（成功: (2,3) → (1,3)）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(find.text('その方向には進めません'), findsOneWidget);

    // Undo
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pumpAndSettle();

    expect(find.text('その方向には進めません'), findsNothing);
    // Undo 後は箱 1 個がゴール上（下移動時に押した分）→ 残り 1 個
    expect(find.text('あと 1 個で完了'), findsOneWidget);
    expect(
      find.byKey(const Key('hint_move')),
      findsOneWidget,
    );
  });

  testWidgets('ブロック後に Restart するとサマリー帯が進捗表示に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動（成功）
    await tester.tap(find.byTooltip('下'));
    await tester.pump();

    // 左に移動して壁にぶつける
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // player at (1,3), try left again → wall
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(find.text('その方向には進めません'), findsOneWidget);

    // Restart
    await tester.tap(find.byKey(const ValueKey('appbar-restart')).first);
    await tester.pumpAndSettle();

    expect(find.text('その方向には進めません'), findsNothing);
    expect(find.text('あと 2 個で完了'), findsOneWidget);
    expect(
      find.byKey(const Key('hint_move')),
      findsOneWidget,
    );
  });

  testWidgets('クリア時はブロック文言ではなくクリア済み文言が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    // ヒーローバナーとヒントチップの両方に「クリア済み」が表示される
    expect(
      find.text('クリア済み'),
      findsAtLeast(1),
    );
    expect(find.text('その方向には進めません'), findsNothing);
  });

  testWidgets('クリア時に全配置と表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('全配置！'), findsOneWidget);
  });

  // --- 状態サマリー帯のテスト ---

  testWidgets('初期状態でサマリー帯に残り箱数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('あと 2 個で完了'), findsOneWidget);
  });

  testWidgets('箱をゴールに押すとサマリー帯の残り数が減る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('あと 1 個で完了'), findsOneWidget);
  });

  testWidgets('クリア時にサマリー帯が完了表示になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('すべて配置完了！'), findsOneWidget);
  });

  // --- 配置ドットのテスト ---

  testWidgets('初期状態でサマリー帯に箱数ぶんのドットが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // totalBoxes == 2 なのでドットが 2 つ
    expect(find.byKey(const ValueKey('progress-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-dot-1')), findsOneWidget);
  });

  testWidgets('箱をゴールに置くとドットの塗りが変わる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 初期状態: 両方アウトライン（color == null）
    for (var i = 0; i < 2; i++) {
      final dot = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('progress-dot-$i')),
      );
      final deco = dot.decoration! as BoxDecoration;
      expect(deco.color, isNull, reason: 'dot $i should be outline');
      expect(deco.border, isNotNull, reason: 'dot $i should have border');
    }

    // 下に移動: box(2,3)→(2,4) がゴールに乗る → placedCount == 1
    await tester.tap(find.byTooltip('下'));
    await tester.pumpAndSettle();

    final dot0 = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('progress-dot-0')),
    );
    final deco0 = dot0.decoration! as BoxDecoration;
    expect(deco0.color, isNotNull, reason: 'dot 0 should be filled');
    expect(deco0.border, isNull, reason: 'dot 0 should have no border');

    final dot1 = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('progress-dot-1')),
    );
    final deco1 = dot1.decoration! as BoxDecoration;
    expect(deco1.color, isNull, reason: 'dot 1 should be outline');
    expect(deco1.border, isNotNull, reason: 'dot 1 should have border');
  });

  testWidgets('クリア時にすべてのドットが塗りつぶしになる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      final dot = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('progress-dot-$i')),
      );
      final deco = dot.decoration! as BoxDecoration;
      expect(deco.color, isNotNull, reason: 'dot $i should be filled');
    }
  });

  // --- ステータスカードの余白・構造テスト ---

  testWidgets('ステータスカードにセグメントバーとヒントチップが共存する', (tester) async {
    await tester.pumpWidget(buildApp());
    // セグメントバーとヒントチップが両方表示されており、
    // 余白で適切に区切られていることを確認する。
    expect(find.byKey(const ValueKey('segment_0')), findsOneWidget);
    expect(find.byKey(const Key('hint_move')), findsOneWidget);
    expect(find.byKey(const Key('hint_undo')), findsOneWidget);
    expect(find.byKey(const Key('hint_restart')), findsOneWidget);
  });

  // --- 配置セグメントバーのテスト ---

  testWidgets('配置セグメントバーが箱数ぶんのセグメントを持つ', (tester) async {
    await tester.pumpWidget(buildApp());
    // totalBoxes == 2 なのでセグメントが 2 つ
    expect(find.byKey(const ValueKey('segment_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('segment_1')), findsOneWidget);
  });

  testWidgets('初期状態でセグメントバーの全セグメントが未配置色', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    // 両セグメントとも未配置色（薄いグレー系）
    for (var i = 0; i < 2; i++) {
      final container = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('segment_$i')),
      );
      final deco = container.decoration! as BoxDecoration;
      // 未配置色は alpha が低い薄い色
      expect(deco.color, isNotNull, reason: 'segment $i should have a color');
      expect(deco.color!.a, lessThan(0.5),
          reason: 'segment $i should be faded (empty)');
    }
  });

  testWidgets('箱をゴールに置くとセグメントが配置色に変わる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る → placedCount == 1
    await tester.tap(find.byTooltip('下'));
    await tester.pumpAndSettle();

    // セグメント 0 が配置色（alpha が高い）
    final seg0 = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('segment_0')),
    );
    final deco0 = seg0.decoration! as BoxDecoration;
    expect(deco0.color!.a, greaterThan(0.5),
        reason: 'segment 0 should be filled');

    // セグメント 1 はまだ未配置色
    final seg1 = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('segment_1')),
    );
    final deco1 = seg1.decoration! as BoxDecoration;
    expect(deco1.color!.a, lessThan(0.5),
        reason: 'segment 1 should be empty');
  });

  testWidgets('初期状態で配置が分数形式で表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // ステータスカードとバナー進捗チップの両方に表示される
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  // --- キーボード操作のテスト ---

  testWidgets('矢印キーでプレイヤーが移動する', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下矢印キーで移動
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // 手数が 1 に増える
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(PlayerWidget), findsOneWidget);
  });

  testWidgets('WASD キーで移動できる', (tester) async {
    await tester.pumpWidget(buildApp());

    // S キー（下）で移動
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // W キー（上）で移動
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('HJKL キーで移動できる', (tester) async {
    await tester.pumpWidget(buildApp());

    // J キー（下）で移動
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // K キー（上）で移動
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('クリア後はキーボード移動が無効になる', (tester) async {
    await tester.pumpWidget(buildApp());

    // キーボードで解法: 下, 上, 右, 下
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.text('クリア！'), findsNWidgets(2));

    // クリア後に矢印キーを押しても手数が変わらない
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('Ctrl+Z で Undo できる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // Ctrl+Z で Undo
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('初期状態では R キーで Restart されない', (tester) async {
    await tester.pumpWidget(buildApp());

    // 初期状態で R キーを押す
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    // 手数が 0 のまま変わらない
    expect(find.text('0'), findsOneWidget);
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  testWidgets('R キーで Restart できる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 数手動かす
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    // R キーで Restart
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
  });

  // --- ボタン操作後のキーボードフォーカス維持テスト ---

  testWidgets('方向ボタン押下後もキーボード操作が有効', (tester) async {
    await tester.pumpWidget(buildApp());

    // 方向ボタンでプレイヤーを移動
    await tester.tap(find.byTooltip('下'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // ボタン操作後にキーボードで移動できることを確認
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Undo ボタン押下後もキーボード操作が有効', (tester) async {
    await tester.pumpWidget(buildApp());

    // キーボードで移動
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // 画面下部の Undo ボタンをタップ
    await tester.ensureVisible(find.byKey(const ValueKey('bottom-undo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-undo')));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    // ボタン操作後にキーボードで移動できることを確認
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Restart ボタン押下後もキーボード操作が有効', (tester) async {
    await tester.pumpWidget(buildApp());

    // キーボードで移動
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // 画面下部のリスタートボタンをタップ
    await tester.ensureVisible(find.byKey(const ValueKey('bottom-restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-restart')));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    // ボタン操作後にキーボードで移動できることを確認
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('AppBar の Undo ボタン押下後もキーボード操作が有効', (tester) async {
    await tester.pumpWidget(buildApp());

    // キーボードで移動
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // AppBar の Undo ボタンをタップ（AppBar 内の undo アイコン）
    final undoButtons = find.byKey(const ValueKey('appbar-undo'));
    // AppBar のボタンは最初に見つかる
    await tester.tap(undoButtons.first);
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    // ボタン操作後にキーボードで移動できることを確認
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('キーボードで解法を入力するとクリアできる', (tester) async {
    await tester.pumpWidget(buildApp());

    // 解法: 下, 上, 右, 下
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.text('クリア！'), findsNWidgets(2));
  });

  // --- クリアオーバーレイのテスト ---

  testWidgets('クリア時に盤面オーバーレイが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    // オーバーレイ内の「もう一度」ボタンが表示される
    expect(find.text('もう一度'), findsOneWidget);
    expect(find.byKey(const ValueKey('overlay-restart')), findsOneWidget);
  });

  testWidgets('クリア前にはオーバーレイが表示されない', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('もう一度'), findsNothing);
    expect(find.byKey(const ValueKey('overlay-restart')), findsNothing);
  });

  testWidgets('オーバーレイの「もう一度」ボタンで初期状態に戻る', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    // クリアオーバーレイの入場アニメーション完了を待つ
    await tester.pumpAndSettle();

    expect(find.text('もう一度'), findsOneWidget);

    // オーバーレイのリスタートボタンをタップ
    await tester.tap(find.byKey(const ValueKey('overlay-restart')));
    await tester.pumpAndSettle();

    // クリア表示が消え、初期状態に戻る
    expect(find.text('もう一度'), findsNothing);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('0 / 2'), findsNWidgets(2));
  });

  testWidgets('Undo でクリア解除するとオーバーレイが消える', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);

    expect(find.text('もう一度'), findsOneWidget);

    // Undo
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    expect(find.text('もう一度'), findsNothing);
  });

  testWidgets('クリアオーバーレイにアクセントラインとピル型手数表示がある',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    // アクセントライン: LinearGradient を持つ DecoratedBox が存在する
    final accentFinder = find.byWidgetPredicate((widget) {
      if (widget is DecoratedBox) {
        final decoration = widget.decoration;
        if (decoration is BoxDecoration &&
            decoration.gradient is LinearGradient) {
          return true;
        }
      }
      return false;
    });
    expect(accentFinder, findsWidgets);

    // 手数表示がピル型背景（borderRadius 付き DecoratedBox）内に表示される
    final pillFinder = find.ancestor(
      of: find.textContaining('手でクリア'),
      matching: find.byWidgetPredicate((widget) {
        if (widget is DecoratedBox) {
          final decoration = widget.decoration;
          if (decoration is BoxDecoration && decoration.borderRadius != null) {
            return true;
          }
        }
        return false;
      }),
    );
    expect(pillFinder, findsWidgets);
  });

  testWidgets('クリアオーバーレイにステージ完了サブタイトルが表示される',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overlay-stage-complete')), findsOneWidget);
    expect(find.text('ステージ 1 完了'), findsOneWidget);
  });

  testWidgets('クリアオーバーレイに配置数チップが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overlay-box-count')), findsOneWidget);
    expect(find.text('2/2 配置'), findsOneWidget);
  });

  testWidgets('Undo でクリア解除するとオーバーレイのサブタイトルとチップが消える',
      (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(find.text('ステージ 1 完了'), findsOneWidget);
    expect(find.byKey(const Key('overlay-box-count')), findsOneWidget);

    // Undo
    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pump();

    expect(find.text('ステージ 1 完了'), findsNothing);
    expect(find.byKey(const Key('overlay-box-count')), findsNothing);
  });

  // --- レスポンシブレイアウトのテスト ---

  group('レスポンシブレイアウト', () {
    Widget buildAppWithSize(Size size) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: const HomeScreen(initialLevel: testLevel),
            ),
          ),
        );

    testWidgets('狭い画面（600px）では縦積みレイアウトになる', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildAppWithSize(const Size(600, 800)));

      // maxWidth 480 の ConstrainedBox がある = 狭いレイアウト
      final narrowConstraint = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 480,
      );
      expect(narrowConstraint, findsOneWidget);

      // 基本ウィジェットが描画されている
      expect(find.byType(PlayerWidget), findsOneWidget);
      expect(find.text('Sokoban'), findsOneWidget);
    });

    testWidgets('広い画面（900px）では 2 カラムレイアウトになる', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildAppWithSize(const Size(900, 700)));

      // maxWidth 960 の ConstrainedBox がある = 広いレイアウト
      final wideConstraint = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 960,
      );
      expect(wideConstraint, findsOneWidget);

      // 基本ウィジェットが描画されている
      expect(find.byType(PlayerWidget), findsOneWidget);
      expect(find.text('Sokoban'), findsOneWidget);
      expect(find.text('元に戻す'), findsOneWidget);
      expect(find.text('リスタート'), findsOneWidget);
    });

    testWidgets('広い画面でも方向ボタンが機能する', (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildAppWithSize(const Size(900, 700)));

      // 方向ボタンが存在する（Tooltip で探す）
      expect(find.byTooltip('上'), findsOneWidget);
      expect(find.byTooltip('下'), findsOneWidget);

      // 移動できる
      await tester.tap(find.byTooltip('下'));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
    });
  });

  testWidgets('ヒーローバナーと盤面ヘッダーにステージ見出しが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    // ヒーローバナーと盤面ヘッダーに「ステージ 1」が表示される
    expect(find.text('ステージ 1'), findsAtLeast(2));
  });

  // --- 盤面ヘッダーのテスト ---

  testWidgets('盤面カードにステージラベルと箱カウントが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byKey(const Key('board_header_stage')), findsOneWidget);
    expect(find.byKey(const Key('board_header_box_count')), findsOneWidget);
    expect(find.byKey(const Key('board_header_status')), findsOneWidget);
    expect(find.byKey(const Key('board_header_move_count')), findsOneWidget);
  });

  testWidgets('盤面ヘッダーにプレイ中ステータスと手数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('プレイ中'), findsOneWidget);
    expect(find.text('0 手'), findsOneWidget);
  });

  // --- 操作セクション内サブラベルのテスト ---

  testWidgets('操作セクションに「移動」と「やり直し」のサブラベルが表示される', (tester) async {
    await tester.pumpWidget(buildApp());

    final moveLabel = find.byKey(const Key('control_sub_label_move'));
    expect(moveLabel, findsOneWidget);
    expect(
      find.descendant(of: moveLabel, matching: find.text('移動')),
      findsOneWidget,
    );

    final assistLabel = find.byKey(const Key('control_sub_label_assist'));
    expect(assistLabel, findsOneWidget);
    expect(
      find.descendant(of: assistLabel, matching: find.text('やり直し')),
      findsOneWidget,
    );
  });

  // --- 操作パッド中央ステータスチップのテスト ---

  /// ステータスチップを Key で探すヘルパー。
  Finder findDpadChip(String text) =>
      find.byKey(Key('dpad_center_status_$text'));

  testWidgets('操作パッド中央にステータスチップが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(findDpadChip('残 2'), findsOneWidget);
  });

  testWidgets('初期状態でステータスチップに残り箱数が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(findDpadChip('残 2'), findsOneWidget);
  });

  testWidgets('箱をゴールに押すとステータスチップの残り数が減る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 下に移動: box(2,3)→(2,4) がゴールに乗る
    await tester.tap(find.byTooltip('下'));
    await tester.pumpAndSettle();

    expect(findDpadChip('残 1'), findsOneWidget);
  });

  testWidgets('クリア後にステータスチップが完了表示になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(findDpadChip('完了'), findsOneWidget);
  });

  testWidgets('Undo でクリア解除するとステータスチップが残り数に戻る', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('appbar-undo')).first);
    await tester.pumpAndSettle();

    expect(findDpadChip('残 1'), findsOneWidget);
  });

  testWidgets('壁に向かって移動すると方向パッド中央にブロック表示が出る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功: (2,2) → (1,2)）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁 (0,2) で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(findDpadChip('進めません'), findsOneWidget);
  });

  testWidgets('ブロック表示が約 1 秒後に方向パッド中央から消える', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(findDpadChip('進めません'), findsOneWidget);

    // 1 秒経過させてタイマー発火
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(findDpadChip('進めません'), findsNothing);
    expect(findDpadChip('残 2'), findsOneWidget);
  });

  testWidgets('ブロック後に成功移動すると方向パッド中央が残り数に戻る', (tester) async {
    await tester.pumpWidget(buildApp());

    // 左に移動（成功）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    // さらに左（壁で blocked）
    await tester.tap(find.byTooltip('左'));
    await tester.pump();
    expect(findDpadChip('進めません'), findsOneWidget);

    // 右に移動（成功）
    await tester.tap(find.byTooltip('右'));
    await tester.pumpAndSettle();

    expect(findDpadChip('進めません'), findsNothing);
    expect(findDpadChip('残 2'), findsOneWidget);
  });

  // --- プレイコンテキストバナーのテスト ---

  testWidgets('プレイコンテキストバナーにステージ情報と目的が表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(
      find.byKey(const Key('play_context_label')),
      findsOneWidget,
    );
    // ヒーローバナーはステージ名と説明を2行で表示する
    expect(find.text('ステージ 1'), findsAtLeast(1));
    expect(find.text('箱をすべてゴールへ運ぼう'), findsOneWidget);
  });

  testWidgets('クリア後にバナーがクリア済み表示に変わる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    // ヒーローバナーの説明テキストでクリア状態を確認
    expect(find.byKey(const Key('play_context_description')), findsOneWidget);
    final descWidget = tester.widget<Text>(
      find.byKey(const Key('play_context_description')),
    );
    expect(descWidget.data, 'クリア済み');
  });

  testWidgets('ヒーローバナーにステージラベルと説明のキーが存在する', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byKey(const Key('play_context_label')), findsOneWidget);
    expect(find.byKey(const Key('play_context_description')), findsOneWidget);
  });

  // --- バナー進捗チップのテスト ---

  testWidgets('バナーに初期状態の進捗チップが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byKey(const Key('banner_progress_0 / 2')), findsOneWidget);
  });

  testWidgets('箱をゴールに押すとバナー進捗チップが更新される', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner_progress_1 / 2')), findsOneWidget);
  });

  testWidgets('クリア後にバナー進捗チップが全配置表示になる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner_progress_全配置')), findsOneWidget);
  });

  // --- バナー進捗バーのテスト ---

  testWidgets('バナーに初期状態の進捗バーが表示される', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.byKey(const Key('banner_bar_0_2')), findsOneWidget);
  });

  testWidgets('箱をゴールに押すとバナー進捗バーが更新される', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byTooltip('下'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner_bar_1_2')), findsOneWidget);
  });

  testWidgets('クリア後にバナー進捗バーが満タンになる', (tester) async {
    await tester.pumpWidget(buildApp());
    await solveStage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner_bar_2_2')), findsOneWidget);
  });

  // --- バナーレスポンシブのテスト ---

  testWidgets('狭い幅でバナーの進捗チップが進捗バーの下に配置される', (tester) async {
    // 幅 320px → バナー実効幅 296px < _compactThreshold (300)
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 700)),
          child: const HomeScreen(initialLevel: testLevel),
        ),
      ),
    );

    // バナーのラベルと進捗チップが共存している
    expect(find.byKey(const Key('play_context_label')), findsOneWidget);
    expect(find.byKey(const Key('banner_progress_0 / 2')), findsOneWidget);

    // compact 時はチップが Align で右寄せされている
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.alignment == Alignment.centerRight,
      ),
      findsOneWidget,
    );
  });

  testWidgets('広い幅でバナーの進捗チップが横に並ぶ', (tester) async {
    await tester.pumpWidget(buildApp());

    // デフォルトテストサイズ (800x600) では compact ではない
    expect(find.byKey(const Key('play_context_label')), findsOneWidget);
    expect(find.byKey(const Key('banner_progress_0 / 2')), findsOneWidget);

    // compact 用の Align は存在しない
    expect(
      find.byWidgetPredicate(
        (w) => w is Align && w.alignment == Alignment.centerRight,
      ),
      findsNothing,
    );
  });
}
