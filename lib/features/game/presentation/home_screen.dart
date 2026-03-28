import 'package:flutter/material.dart';

import '../domain/direction.dart';
import '../domain/game_state.dart';

/// 固定 1 ステージの倉庫番プレイ画面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// 初期ステージ定義（標準 Sokoban テキスト形式）。
  static const List<String> initialLevel = [
    '######',
    '#    #',
    '# @  #',
    '# \$\$ #',
    '# .. #',
    '######',
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GameState _gameState;
  final List<GameState> _history = [];
  int _moveCount = 0;

  @override
  void initState() {
    super.initState();
    _gameState = GameState.parse(HomeScreen.initialLevel);
  }

  void _move(Direction dir) {
    final next = _gameState.move(dir);
    if (!identical(next, _gameState)) {
      setState(() {
        _history.add(_gameState);
        _gameState = next;
        _moveCount++;
      });
    }
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _gameState = _history.removeLast();
      _moveCount--;
    });
  }

  void _restart() {
    setState(() {
      _history.clear();
      _moveCount = 0;
      _gameState = GameState.parse(HomeScreen.initialLevel);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sokoban'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '元に戻す',
            onPressed: _history.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'リスタート',
            onPressed: _restart,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_gameState.isSolved)
                    Container(
                      width: double.infinity,
                      color: Colors.green.shade100,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'クリア！ $_moveCount手',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _ProgressBar(
                      moveCount: _moveCount,
                      remainingBoxes: _gameState.remainingBoxes,
                      totalBoxes: _gameState.board.goals.length,
                      isSolved: _gameState.isSolved,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            _gameState.board.width / _gameState.board.height,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cellSize = constraints.maxWidth /
                                _gameState.board.width;
                            return _BoardView(
                              gameState: _gameState,
                              cellSize: cellSize,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  _DirectionPad(
                    onMove: _move,
                    enabled: !_gameState.isSolved,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _history.isNotEmpty ? _undo : null,
                            icon: const Icon(Icons.undo),
                            label: const Text('元に戻す'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _restart,
                            icon: const Icon(Icons.refresh),
                            label: const Text('リスタート'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 手数・残り箱数を並べて表示する進捗バー。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.moveCount,
    required this.remainingBoxes,
    required this.totalBoxes,
    required this.isSolved,
  });

  final int moveCount;
  final int remainingBoxes;
  final int totalBoxes;
  final bool isSolved;

  @override
  Widget build(BuildContext context) {
    final placedBoxes = totalBoxes - remainingBoxes;
    final boxColor = isSolved
        ? Colors.green
        : remainingBoxes == 0
            ? Colors.green
            : Colors.orange.shade800;

    return Row(
      children: [
        Expanded(
          child: _ProgressCard(
            icon: Icons.directions_walk,
            iconColor: Colors.blue,
            label: '手数',
            value: '$moveCount',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProgressCard(
            icon: Icons.inventory_2,
            iconColor: boxColor,
            label: '残り箱',
            value: '$placedBoxes / $totalBoxes',
          ),
        ),
      ],
    );
  }
}

/// 個別の進捗カード（アイコン + ラベル + 値）。
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 盤面をグリッド描画するウィジェット。
class _BoardView extends StatelessWidget {
  const _BoardView({required this.gameState, required this.cellSize});

  final GameState gameState;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    final board = gameState.board;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(board.height, (y) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(board.width, (x) {
            return SizedBox(
              width: cellSize,
              height: cellSize,
              child: _CellWidget(
                isWall: board.isWall(x, y),
                isGoal: board.isGoal(x, y),
                isPlayer: x == gameState.playerX && y == gameState.playerY,
                isBox: gameState.boxes.contains((x, y)),
              ),
            );
          }),
        );
      }),
    );
  }
}

/// 1 セルの描画。
class _CellWidget extends StatelessWidget {
  const _CellWidget({
    required this.isWall,
    required this.isGoal,
    required this.isPlayer,
    required this.isBox,
  });

  final bool isWall;
  final bool isGoal;
  final bool isPlayer;
  final bool isBox;

  @override
  Widget build(BuildContext context) {
    if (isWall) {
      return Container(color: Colors.brown.shade700);
    }

    final bgColor = isGoal ? Colors.green.shade50 : Colors.amber.shade50;

    if (isPlayer) {
      return Container(
        color: bgColor,
        child: const FittedBox(
          child: Icon(Icons.person, color: Colors.blue),
        ),
      );
    }

    if (isBox) {
      final boxColor =
          isGoal ? Colors.green.shade700 : Colors.orange.shade800;
      return Container(
        color: bgColor,
        child: FittedBox(
          child: Icon(Icons.inventory_2, color: boxColor),
        ),
      );
    }

    if (isGoal) {
      return Container(
        color: bgColor,
        child: FittedBox(
          child: Icon(Icons.close, color: Colors.green.shade300),
        ),
      );
    }

    return Container(color: bgColor);
  }
}

/// 方向パッド（上下左右ボタン）。
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onMove, this.enabled = true});

  final void Function(Direction) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const btnSize = 56.0;

    Widget dirButton(Direction dir, IconData icon, String label) {
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: IconButton.filled(
          onPressed: enabled ? () => onMove(dir) : null,
          icon: Icon(icon),
          tooltip: label,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dirButton(Direction.up, Icons.arrow_upward, '上'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dirButton(Direction.left, Icons.arrow_back, '左'),
              const SizedBox(width: btnSize, height: btnSize),
              dirButton(Direction.right, Icons.arrow_forward, '右'),
            ],
          ),
          dirButton(Direction.down, Icons.arrow_downward, '下'),
        ],
      ),
    );
  }
}
