import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sokoban_app/features/game/presentation/home_screen.dart';

/// Web 前提の簡易プレイフロー widget test。
///
/// HomeScreen を起点に、画面表示 → 移動操作 → 状態更新 → クリア → リスタート
/// という最小プレイ導線がひとまとまりで壊れていないことを確認する。
/// 見た目の細部に依存せず、プレイ導線の骨格を保護する。
void main() {
  // 最小の解けるレベル: プレイヤー(2,2), 箱(2,3)(3,3), ゴール(2,4)(3,4)
  // 解法: 下, 上, 右, 下 (4手)
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

  group('最小プレイフロー', () {
    testWidgets('画面起動 → 移動 → クリア → リスタートの一連導線が動作する',
        (tester) async {
      // --- Phase 1: 画面が正しく描画される ---
      await tester.pumpWidget(buildApp());

      // 盤面と操作UIが表示されている
      expect(find.text('Sokoban'), findsOneWidget);

      // 操作ボタン(方向パッド)が揃っている
      expect(find.byTooltip('上'), findsOneWidget);
      expect(find.byTooltip('下'), findsOneWidget);
      expect(find.byTooltip('左'), findsOneWidget);
      expect(find.byTooltip('右'), findsOneWidget);

      // 手数が 0、残り箱が「あと2個」で始まる
      expect(find.text('0'), findsOneWidget);
      expect(find.text('あと2個'), findsOneWidget);

      // クリア表示はまだ出ていない
      expect(find.textContaining('クリア'), findsNothing);

      // --- Phase 2: 移動操作で盤面が更新される ---
      // 下に移動 → 箱を 1 つゴールに載せる
      await tester.tap(find.byTooltip('下'));
      await tester.pump();

      // 手数が 1 に増え、残り箱が 1 に減る
      expect(find.text('1'), findsOneWidget);
      expect(find.text('あと1個'), findsOneWidget);
      expect(find.textContaining('クリア'), findsNothing);

      // --- Phase 3: 解法の残りを実行してクリアに到達する ---
      await tester.tap(find.byTooltip('上'));
      await tester.pump();
      await tester.tap(find.byTooltip('右'));
      await tester.pump();
      await tester.tap(find.byTooltip('下'));
      await tester.pump();

      // クリアメッセージが表示される
      expect(find.text('クリア！ 4手'), findsOneWidget);

      // --- Phase 4: リスタートで初期状態に戻る ---
      await tester.tap(find.byTooltip('リスタート').first);
      await tester.pump();

      // クリア表示が消え、手数と残り箱が初期値に戻る
      expect(find.textContaining('クリア'), findsNothing);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('あと2個'), findsOneWidget);
      expect(find.text('配置'), findsOneWidget);
    });

    testWidgets('壁で移動がブロックされても画面が壊れない', (tester) async {
      // 1x1 で動けない極小レベル
      const tinyLevel = [
        '####',
        '#@.#',
        '####',
      ];
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(initialLevel: tinyLevel)),
      );

      // 描画される
      expect(find.text('Sokoban'), findsOneWidget);

      // 上に移動（壁でブロック）
      await tester.tap(find.byTooltip('上'));
      await tester.pump();

      // 画面構造が壊れていない
      expect(find.text('Sokoban'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // 手数は増えない
    });

    testWidgets('Undo で直前の状態に正しく巻き戻せる', (tester) async {
      await tester.pumpWidget(buildApp());

      // 1手動かす
      await tester.tap(find.byTooltip('下'));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('あと1個'), findsOneWidget);

      // Undo
      await tester.tap(find.byTooltip('元に戻す').first);
      await tester.pump();

      // 手数と残り箱が元に戻る
      expect(find.text('0'), findsOneWidget);
      expect(find.text('あと2個'), findsOneWidget);
    });
  });
}
