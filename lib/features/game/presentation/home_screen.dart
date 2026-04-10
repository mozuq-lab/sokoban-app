import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/direction.dart';
import '../domain/game_state.dart';
import 'game_painters.dart';

/// 固定 1 ステージの倉庫番プレイ画面。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialLevel});

  /// テスト等で直接レベルデータを渡す場合に使う。
  /// null の場合は asset から読み込む。
  final List<String>? initialLevel;

  /// asset のレベルファイルパス。
  static const String levelAssetPath = 'assets/levels/level_001.txt';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameState? _gameState;
  late List<String> _levelLines;
  final List<GameState> _history = [];
  int _moveCount = 0;
  bool _moveBlocked = false;
  Timer? _blockedHintTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialLevel != null) {
      _levelLines = widget.initialLevel!;
      _gameState = GameState.parse(_levelLines);
    } else {
      _loadLevelFromAsset();
    }
  }

  Future<void> _loadLevelFromAsset() async {
    final text = await rootBundle.loadString(HomeScreen.levelAssetPath);
    final lines = const LineSplitter().convert(text);
    // 末尾の空行を除去
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (mounted) {
      setState(() {
        _levelLines = lines;
        _gameState = GameState.parse(_levelLines);
      });
    }
  }

  @override
  void dispose() {
    _blockedHintTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// キーボードイベントを処理する。
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_gameState == null) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Undo: Ctrl+Z / Cmd+Z
    if (isCtrlOrMeta && key == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }

    // Restart: R キー（修飾キーなし・履歴があるときのみ）
    if (!isCtrlOrMeta && key == LogicalKeyboardKey.keyR) {
      if (_history.isNotEmpty) {
        _restart();
      }
      return KeyEventResult.handled;
    }

    // 方向キー（クリア後は無効）
    final direction = _directionFromKey(key);
    if (direction != null) {
      if (!_gameState!.isSolved) {
        _move(direction);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// キーから方向を返す。対応しないキーは null。
  static Direction? _directionFromKey(LogicalKeyboardKey key) {
    // 矢印キー
    if (key == LogicalKeyboardKey.arrowUp) return Direction.up;
    if (key == LogicalKeyboardKey.arrowDown) return Direction.down;
    if (key == LogicalKeyboardKey.arrowLeft) return Direction.left;
    if (key == LogicalKeyboardKey.arrowRight) return Direction.right;
    // WASD
    if (key == LogicalKeyboardKey.keyW) return Direction.up;
    if (key == LogicalKeyboardKey.keyS) return Direction.down;
    if (key == LogicalKeyboardKey.keyA) return Direction.left;
    if (key == LogicalKeyboardKey.keyD) return Direction.right;
    // HJKL (Vim 風)
    if (key == LogicalKeyboardKey.keyH) return Direction.left;
    if (key == LogicalKeyboardKey.keyJ) return Direction.down;
    if (key == LogicalKeyboardKey.keyK) return Direction.up;
    if (key == LogicalKeyboardKey.keyL) return Direction.right;
    return null;
  }

  void _move(Direction dir) {
    final current = _gameState!;
    final next = current.move(dir);
    if (!identical(next, current)) {
      _blockedHintTimer?.cancel();
      setState(() {
        _history.add(current);
        _gameState = next;
        _moveCount++;
        _moveBlocked = false;
      });
    } else {
      _blockedHintTimer?.cancel();
      setState(() {
        _moveBlocked = true;
      });
      _blockedHintTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _moveBlocked = false;
          });
        }
      });
    }
    _focusNode.requestFocus();
  }

  void _undo() {
    if (_history.isEmpty) return;
    _blockedHintTimer?.cancel();
    setState(() {
      _gameState = _history.removeLast();
      _moveCount--;
      _moveBlocked = false;
    });
    _focusNode.requestFocus();
  }

  void _restart() {
    _blockedHintTimer?.cancel();
    setState(() {
      _history.clear();
      _moveCount = 0;
      _moveBlocked = false;
      _gameState = GameState.parse(_levelLines);
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = _gameState;
    if (gameState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sokoban')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
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
              onPressed: _history.isNotEmpty ? _restart : null,
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        );
                      },
                      child: gameState.isSolved
                          ? Container(
                              key: const ValueKey('clear-banner'),
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
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('no-banner'),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _ProgressBar(
                        moveCount: _moveCount,
                        remainingBoxes: gameState.remainingBoxes,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              gameState.board.width / gameState.board.height,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF4E342E),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x30000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final cellSize =
                                      constraints.maxWidth /
                                      gameState.board.width;
                                  return _BoardView(
                                    gameState: gameState,
                                    cellSize: cellSize,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _DirectionPad(
                      onMove: _move,
                      enabled: !gameState.isSolved,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _history.isNotEmpty ? _undo : null,
                              icon: const Icon(Icons.undo, size: 20),
                              label: const Text('元に戻す'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _history.isNotEmpty ? _restart : null,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text('リスタート'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          gameState.isSolved
                              ? 'クリア済み — Ctrl+Z で戻す・R でやり直し'
                              : _moveBlocked
                                  ? 'その方向には進めません'
                                  : '移動: ボタン／矢印・WASD ｜ 戻す: Ctrl+Z ｜ やり直し: R',
                          key: ValueKey(
                            gameState.isSolved
                                ? 'hint-cleared'
                                : _moveBlocked
                                    ? 'hint-blocked'
                                    : 'hint-normal',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: _moveBlocked && !gameState.isSolved
                                ? Colors.red.shade400
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
  });

  final int moveCount;
  final int remainingBoxes;

  @override
  Widget build(BuildContext context) {
    final allPlaced = remainingBoxes == 0;
    final boxColor = allPlaced ? Colors.green : Colors.orange.shade800;
    final boxValue = allPlaced ? '全配置！' : 'あと$remainingBoxes個';

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
            label: '配置',
            value: boxValue,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
    // --- 壁 ---
    if (isWall) {
      return const CustomPaint(painter: WallPainter());
    }

    const goalBgColor = Color(0xFFE8F5E9);

    // --- ゴール上のプレイヤー ---
    if (isPlayer && isGoal) {
      return Container(
        color: goalBgColor,
        child: const Stack(
          children: [
            Positioned.fill(child: GoalMarkerWidget()),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(2),
                child: PlayerWidget(),
              ),
            ),
          ],
        ),
      );
    }

    // --- プレイヤー ---
    if (isPlayer) {
      return const Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: FloorPainter())),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(2),
              child: PlayerWidget(),
            ),
          ),
        ],
      );
    }

    // --- ゴール上の箱 ---
    if (isBox && isGoal) {
      return Container(
        color: goalBgColor,
        padding: const EdgeInsets.all(1),
        child: const BoxWidget(onGoal: true),
      );
    }

    // --- 箱 ---
    if (isBox) {
      return const Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: FloorPainter())),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(1),
              child: BoxWidget(),
            ),
          ),
        ],
      );
    }

    // --- ゴール（空） ---
    if (isGoal) {
      return Container(
        color: goalBgColor,
        child: const GoalMarkerWidget(),
      );
    }

    // --- 床 ---
    return const CustomPaint(painter: FloorPainter());
  }
}

/// 方向パッド（上下左右ボタン）。
class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onMove, this.enabled = true});

  final void Function(Direction) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const btnSize = 60.0;

    final activeColor = const Color(0xFF5D4037);
    final disabledColor = Colors.grey.shade400;

    Widget dirButton(Direction dir, String label) {
      final arrowColor = enabled ? activeColor : disabledColor;
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: Tooltip(
          message: label,
          child: Material(
            color: enabled
                ? const Color(0xFFF5E6CC)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
            elevation: enabled ? 3 : 0,
            shadowColor: const Color(0x40000000),
            child: InkWell(
              onTap: enabled ? () => onMove(dir) : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: enabled
                        ? const Color(0xFF8D6E63)
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: CustomPaint(
                  painter: ArrowPainter(
                    direction: dir,
                    color: arrowColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dirButton(Direction.up, '上'),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dirButton(Direction.left, '左'),
              const SizedBox(width: btnSize + 8, height: btnSize),
              dirButton(Direction.right, '右'),
            ],
          ),
          const SizedBox(height: 4),
          dirButton(Direction.down, '下'),
        ],
      ),
    );
  }
}
