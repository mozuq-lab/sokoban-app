import 'board.dart';
import 'direction.dart';

/// 倉庫番の盤面における動的状態（プレイヤー位置・箱位置）。
///
/// イミュータブル。[move] で新しい状態を返す。
class GameState {
  GameState({
    required this.board,
    required this.playerX,
    required this.playerY,
    required Set<(int, int)> boxes,
  }) : _boxes = boxes;

  final Board board;
  final int playerX;
  final int playerY;
  final Set<(int, int)> _boxes;

  /// 現在の箱位置一覧。
  Set<(int, int)> get boxes => Set.unmodifiable(_boxes);

  /// すべての箱がゴール上にあれば true。
  bool get isSolved {
    if (_boxes.length != board.goals.length) return false;
    return _boxes.every((b) => board.isGoal(b.$1, b.$2));
  }

  /// 指定方向に移動を試みて、新しい状態を返す。
  ///
  /// 移動できない場合は同じ状態を返す。
  GameState move(Direction dir) {
    final nx = playerX + dir.dx;
    final ny = playerY + dir.dy;

    // 壁には入れない
    if (board.isWall(nx, ny)) return this;

    // 箱がある場合、押せるか判定
    if (_boxes.contains((nx, ny))) {
      final bx = nx + dir.dx;
      final by = ny + dir.dy;
      // 押し先が壁または別の箱なら動けない
      if (board.isWall(bx, by) || _boxes.contains((bx, by))) return this;
      // 箱を押す
      final newBoxes = Set<(int, int)>.from(_boxes)
        ..remove((nx, ny))
        ..add((bx, by));
      return GameState(
        board: board,
        playerX: nx,
        playerY: ny,
        boxes: newBoxes,
      );
    }

    // 空きマスに移動
    return GameState(
      board: board,
      playerX: nx,
      playerY: ny,
      boxes: _boxes,
    );
  }

  /// 倉庫番テキスト形式の行リストから状態を構築する。
  ///
  /// 記法:
  ///   `@` = プレイヤー, `+` = プレイヤー on ゴール,
  ///   `$` = 箱, `*` = 箱 on ゴール。
  factory GameState.parse(List<String> lines) {
    final board = Board.parse(lines);
    int? px, py;
    final boxes = <(int, int)>{};

    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      for (var x = 0; x < line.length; x++) {
        switch (line[x]) {
          case '@':
          case '+':
            px = x;
            py = y;
          case '\$':
          case '*':
            boxes.add((x, y));
        }
      }
    }

    if (px == null || py == null) {
      throw ArgumentError('盤面にプレイヤー (@/+) が見つかりません');
    }

    return GameState(
      board: board,
      playerX: px,
      playerY: py,
      boxes: boxes,
    );
  }
}
