/// 倉庫番の盤面（静的な地形情報）。
///
/// 壁とゴールの位置を保持する。箱やプレイヤーの位置は [GameState] で管理する。
class Board {
  Board({
    required this.width,
    required this.height,
    required Set<(int, int)> walls,
    required Set<(int, int)> goals,
  })  : _walls = walls,
        _goals = goals;

  final int width;
  final int height;
  final Set<(int, int)> _walls;
  final Set<(int, int)> _goals;

  /// 指定座標が壁かどうか。
  bool isWall(int x, int y) => _walls.contains((x, y));

  /// 指定座標がゴールかどうか。
  bool isGoal(int x, int y) => _goals.contains((x, y));

  /// すべてのゴール座標。
  Set<(int, int)> get goals => Set.unmodifiable(_goals);

  /// 倉庫番テキスト形式の行リストから盤面を構築する。
  ///
  /// 記法:
  ///   `#` = 壁, `.` = ゴール, `+` = ゴール（プレイヤー位置として使われる）,
  ///   `*` = ゴール（箱位置として使われる）, その他 = 床。
  factory Board.parse(List<String> lines) {
    final walls = <(int, int)>{};
    final goals = <(int, int)>{};
    final height = lines.length;
    var width = 0;

    for (var y = 0; y < lines.length; y++) {
      final line = lines[y];
      if (line.length > width) width = line.length;
      for (var x = 0; x < line.length; x++) {
        switch (line[x]) {
          case '#':
            walls.add((x, y));
          case '.':
          case '+':
          case '*':
            goals.add((x, y));
        }
      }
    }

    return Board(width: width, height: height, walls: walls, goals: goals);
  }
}
