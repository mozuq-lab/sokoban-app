import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sokoban_app/features/game/domain/direction.dart';
import 'package:sokoban_app/features/game/domain/board.dart';
import 'package:sokoban_app/features/game/domain/game_state.dart';

// テスト用の小さな盤面を作るヘルパー
//
// 記法 (倉庫番の標準的な表現に近い):
//   # = 壁
//   . = ゴール
//   @ = プレイヤー
//   + = プレイヤー on ゴール
//   $ = 箱
//   * = 箱 on ゴール
//   (スペース) = 床
//
// 例: 3x3 で中央にプレイヤー
//   ###
//   # @#
//   ###

void main() {
  group('Direction', () {
    test('各方向の delta が正しい', () {
      expect(Direction.up.dx, 0);
      expect(Direction.up.dy, -1);
      expect(Direction.down.dx, 0);
      expect(Direction.down.dy, 1);
      expect(Direction.left.dx, -1);
      expect(Direction.left.dy, 0);
      expect(Direction.right.dx, 1);
      expect(Direction.right.dy, 0);
    });
  });

  group('Board', () {
    test('文字列からパースできる', () {
      final board = Board.parse([
        '###',
        '# #',
        '###',
      ]);
      expect(board.width, 3);
      expect(board.height, 3);
      expect(board.isWall(0, 0), isTrue);
      expect(board.isWall(1, 1), isFalse);
    });

    test('ゴール位置を認識できる', () {
      final board = Board.parse([
        '####',
        '#. #',
        '#  #',
        '####',
      ]);
      expect(board.isGoal(1, 1), isTrue);
      expect(board.isGoal(2, 1), isFalse);
    });

    test('空の行リストでパースするとエラーになる', () {
      expect(
        () => Board.parse([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('+ と * の位置がゴールとして認識される', () {
      final board = Board.parse([
        '####',
        '#+*#',
        '####',
      ]);
      expect(board.isGoal(1, 1), isTrue); // + はゴール
      expect(board.isGoal(2, 1), isTrue); // * もゴール
    });

    test('コンストラクタに渡した Set を外部から変更しても影響しない', () {
      final walls = <(int, int)>{(0, 0)};
      final goals = <(int, int)>{(1, 1)};
      final board = Board(width: 3, height: 3, walls: walls, goals: goals);

      // 外部から壁とゴールを追加
      walls.add((2, 2));
      goals.add((0, 1));

      // Board 内部には影響しない
      expect(board.isWall(2, 2), isFalse);
      expect(board.isGoal(0, 1), isFalse);
    });
  });

  group('GameState', () {
    // テスト盤面:
    //  #####
    //  #   #
    //  # $ #
    //  # . #
    //  # @ #
    //  #####
    late GameState state;

    setUp(() {
      state = GameState.parse([
        '#####',
        '#   #',
        '# \$ #',
        '# . #',
        '# @ #',
        '#####',
      ]);
    });

    test('初期状態のプレイヤー位置が正しい', () {
      expect(state.playerX, 2);
      expect(state.playerY, 4);
    });

    test('初期状態の箱位置が正しい', () {
      expect(state.boxes, contains((2, 2)));
    });

    test('プレイヤーが空きマスに移動できる', () {
      final next = state.move(Direction.up);
      expect(next.playerX, 2);
      expect(next.playerY, 3);
    });

    test('プレイヤーが壁に移動できない', () {
      // 左は壁ではないが、下は壁
      final next = state.move(Direction.down);
      // 壁なので動かない
      expect(next.playerX, state.playerX);
      expect(next.playerY, state.playerY);
    });

    test('プレイヤーが箱を空きマスに押せる', () {
      // まず上に2回移動してプレイヤーを箱の下に持っていく
      var s = state.move(Direction.up); // (2,3)
      // ここで上に移動すると箱(2,2)を押す
      s = s.move(Direction.up); // プレイヤー(2,2), 箱(2,1)
      expect(s.playerX, 2);
      expect(s.playerY, 2);
      expect(s.boxes, contains((2, 1)));
      expect(s.boxes, isNot(contains((2, 2))));
    });

    test('プレイヤーが箱を壁の方向に押せない', () {
      // 箱(2,2)の上は(2,1)で空き。さらに上の(2,0)は壁。
      // プレイヤーを(2,3)に移動してから上に押す → 箱は(2,1)へ
      var s = state.move(Direction.up); // (2,3)
      s = s.move(Direction.up); // 箱押し: プレイヤー(2,2), 箱(2,1)
      // もう一度上に移動 → 箱(2,1)の先(2,0)は壁なので押せない
      final blocked = s.move(Direction.up);
      expect(blocked.playerX, 2);
      expect(blocked.playerY, 2); // 動かない
      expect(blocked.boxes, contains((2, 1))); // 箱も動かない
    });

    test('プレイヤーが箱を別の箱の方向に押せない', () {
      // 2つの箱が縦に並ぶ盤面
      final s = GameState.parse([
        '#####',
        '#   #',
        '# \$ #',
        '# \$ #',
        '# @ #',
        '#####',
      ]);
      // 上に移動 → 箱(2,3)を押そうとするが、先に箱(2,2)がある
      final next = s.move(Direction.up);
      expect(next.playerX, 2);
      expect(next.playerY, 4); // 動かない
    });

    test('すべての箱がゴール上にあるときクリアと判定される', () {
      // 箱がすでにゴール上にある盤面
      final s = GameState.parse([
        '####',
        '#* #',
        '# @#',
        '####',
      ]);
      expect(s.isSolved, isTrue);
    });

    test('箱がゴール外にあるときクリアではない', () {
      expect(state.isSolved, isFalse);
    });

    test('remainingBoxes がゴール上にない箱の数を返す', () {
      // 箱 1 つ、ゴール 1 つ、箱はゴール外
      expect(state.remainingBoxes, 1);
    });

    test('箱をゴールに押すと remainingBoxes が減る', () {
      final s = GameState.parse([
        '#####',
        '#   #',
        '#@\$.#',
        '#   #',
        '#####',
      ]);
      expect(s.remainingBoxes, 1);
      final solved = s.move(Direction.right);
      expect(solved.remainingBoxes, 0);
    });

    test('全箱ゴール上で remainingBoxes が 0', () {
      final s = GameState.parse([
        '####',
        '#* #',
        '# @#',
        '####',
      ]);
      expect(s.remainingBoxes, 0);
      expect(s.isSolved, isTrue);
    });

    test('複数の箱とゴールでクリア判定が正しい', () {
      // 2つの箱、2つのゴール — 1つだけゴール上
      final s = GameState.parse([
        '#####',
        '#*  #',
        '#\$. #',
        '# @ #',
        '#####',
      ]);
      expect(s.isSolved, isFalse);
    });

    test('プレイヤーがゴール上にいても移動できる', () {
      final s = GameState.parse([
        '####',
        '# .#',
        '#\$+#',
        '####',
      ]);
      // + はプレイヤー on ゴール
      expect(s.playerX, 2);
      expect(s.playerY, 2);
      expect(s.board.isGoal(2, 2), isTrue);
      // 上に移動
      final next = s.move(Direction.up);
      expect(next.playerX, 2);
      expect(next.playerY, 1);
    });

    test('左右方向の移動が正しく動作する', () {
      final s = GameState.parse([
        '#####',
        '# @ #',
        '#####',
      ]);
      // 左に移動
      final left = s.move(Direction.left);
      expect(left.playerX, 1);
      expect(left.playerY, 1);
      // 右に移動
      final right = s.move(Direction.right);
      expect(right.playerX, 3);
      expect(right.playerY, 1);
    });

    test('箱を押してゴールに乗せるとクリアになる', () {
      // ゲームプレイ一連: 箱を押してゴールへ運びクリア
      final s = GameState.parse([
        '#####',
        '#   #',
        '#@\$.#',
        '#   #',
        '#####',
      ]);
      expect(s.isSolved, isFalse);
      // 右に押す → 箱がゴール(3,2)に乗る
      final solved = s.move(Direction.right);
      expect(solved.playerX, 2);
      expect(solved.playerY, 2);
      expect(solved.boxes, contains((3, 2)));
      expect(solved.isSolved, isTrue);
    });

    test('プレイヤーがいない盤面のパースでエラーになる', () {
      expect(
        () => GameState.parse([
          '####',
          '# \$#',
          '# .#',
          '####',
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('欠けた行がある盤面で盤面外に移動できない', () {
      // 2行目が短い盤面（右端が欠けている）
      final s = GameState.parse([
        '####',
        '#@',
        '####',
      ]);
      // 右に移動 → (2,1) は行の外なので壁扱い
      final next = s.move(Direction.right);
      expect(next.playerX, 1);
      expect(next.playerY, 1); // 動かない
    });

    test('盤面の上端・下端の外に移動できない', () {
      final s = GameState.parse([
        '# #',
        '#@#',
        '# #',
      ]);
      // 上に移動 → (1,0) は壁ではないが床
      final up = s.move(Direction.up);
      expect(up.playerY, 0);
      // さらに上 → 盤面外
      final outUp = up.move(Direction.up);
      expect(outUp.playerY, 0); // 動かない
      // 下端
      final down = s.move(Direction.down);
      final outDown = down.move(Direction.down);
      expect(outDown.playerY, 2); // 動かない
    });

    test('欠けた行の外に箱を押せない', () {
      // 2行目が短い盤面で箱が端にある
      final s = GameState.parse([
        '#####',
        '#@\$',
        '#####',
      ]);
      // 右に箱を押す → 押し先 (3,1) は行の外なので壁扱い
      final next = s.move(Direction.right);
      expect(next.playerX, 1);
      expect(next.playerY, 1); // 動かない
    });

    test('左右方向で箱を押せる', () {
      final s = GameState.parse([
        '#####',
        '# @\$ #',
        '#####',
      ]);
      // 右に箱を押す
      final pushed = s.move(Direction.right);
      expect(pushed.playerX, 3);
      expect(pushed.playerY, 1);
      expect(pushed.boxes, contains((4, 1)));
      expect(pushed.boxes, isNot(contains((3, 1))));
    });

    test('プレイヤーが複数ある盤面のパースでエラーになる', () {
      expect(
        () => GameState.parse([
          '#####',
          '#@ @#',
          '#####',
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('@ と + が両方ある盤面でもプレイヤー重複エラーになる', () {
      expect(
        () => GameState.parse([
          '#####',
          '#@.+#',
          '#####',
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('空の盤面のパースでエラーになる', () {
      expect(
        () => GameState.parse([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('テキストファイル形式の文字列から盤面をパースできる', () {
      // asset から読み込んだテキストを LineSplitter で分割して末尾空行を除去する想定
      const fileContent = '######\n#    #\n# @  #\n# \$\$ #\n# .. #\n######\n';
      final lines = const LineSplitter().convert(fileContent);
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      final s = GameState.parse(lines);
      expect(s.playerX, 2);
      expect(s.playerY, 2);
      expect(s.boxes, containsAll([(2, 3), (3, 3)]));
      expect(s.board.isGoal(2, 4), isTrue);
      expect(s.board.isGoal(3, 4), isTrue);
      expect(s.isSolved, isFalse);
    });

    test('CRLF 改行のテキストからも正しくパースできる', () {
      const fileContent =
          '######\r\n#    #\r\n# @  #\r\n# \$\$ #\r\n# .. #\r\n######\r\n';
      final lines = const LineSplitter().convert(fileContent);
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      final s = GameState.parse(lines);
      expect(s.playerX, 2);
      expect(s.playerY, 2);
      expect(s.board.width, 6);
      expect(s.boxes, containsAll([(2, 3), (3, 3)]));
      expect(s.board.isGoal(2, 4), isTrue);
      expect(s.board.isGoal(3, 4), isTrue);
      expect(s.isSolved, isFalse);
    });

    test('* は箱とゴールの両方として認識される', () {
      final s = GameState.parse([
        '####',
        '#* #',
        '# @#',
        '####',
      ]);
      expect(s.boxes, contains((1, 1)));
      expect(s.board.isGoal(1, 1), isTrue);
    });

    test('コンストラクタに渡した箱 Set を外部から変更しても影響しない', () {
      final board = Board.parse([
        '###',
        '# #',
        '###',
      ]);
      final boxes = <(int, int)>{(1, 1)};
      final gs = GameState(
        board: board,
        playerX: 1,
        playerY: 1,
        boxes: boxes,
      );

      // 外部から箱を追加
      boxes.add((0, 0));

      // GameState 内部には影響しない
      expect(gs.boxes.length, 1);
      expect(gs.boxes, isNot(contains((0, 0))));
    });

    test('move で箱を押さない場合も元の状態の boxes が変更されない', () {
      final s = GameState.parse([
        '#####',
        '#   #',
        '# \$ #',
        '# @ #',
        '#####',
      ]);
      final originalBoxes = s.boxes;

      // 箱を押さない移動（左へ）
      final moved = s.move(Direction.left);

      // 元の状態の boxes は変わらない
      expect(s.boxes, equals(originalBoxes));
      // 新しい状態でも同じ箱位置
      expect(moved.boxes, equals(originalBoxes));
    });

    test('boxes ゲッターの戻り値を変更しても内部状態に影響しない', () {
      final s = GameState.parse([
        '####',
        '#\$@#',
        '####',
      ]);

      // boxes ゲッターで取得した Set を変更しようとする
      expect(
        () => s.boxes.add((0, 0)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
