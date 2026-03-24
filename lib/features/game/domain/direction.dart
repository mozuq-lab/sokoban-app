/// プレイヤーの移動方向。
enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dx, this.dy);

  /// X 方向の変位。
  final int dx;

  /// Y 方向の変位。
  final int dy;
}
