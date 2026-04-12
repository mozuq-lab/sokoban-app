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
        backgroundColor: Color.lerp(
            Theme.of(context).colorScheme.surface, Colors.brown.shade50, 0.3),
        appBar: AppBar(
          titleSpacing: 16,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.brown.shade100,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sokoban',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Text(
                'ステージ 1',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          toolbarHeight: 64,
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
          child: LayoutBuilder(
            builder: (context, outerConstraints) {
              final useWideLayout = outerConstraints.maxWidth >= 700;

              final boardSection = _BoardSection(
                gameState: gameState,
                moveCount: _moveCount,
                onRestart: _restart,
              );

              final statusCard = _StatusCard(
                moveCount: _moveCount,
                remainingBoxes: gameState.remainingBoxes,
                isSolved: gameState.isSolved,
                moveBlocked: _moveBlocked,
              );

              final controlSection = _ControlSection(
                gameState: gameState,
                history: _history,
                onMove: _move,
                onUndo: _undo,
                onRestart: _restart,
              );

              if (useWideLayout) {
                return _WideLayout(
                  boardSection: boardSection,
                  statusCard: statusCard,
                  controlSection: controlSection,
                );
              }

              return _NarrowLayout(
                boardSection: boardSection,
                statusCard: statusCard,
                controlSection: controlSection,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 盤面セクション（コンテナ装飾 + AspectRatio + オーバーレイ）。
class _BoardSection extends StatelessWidget {
  const _BoardSection({
    required this.gameState,
    required this.moveCount,
    required this.onRestart,
  });

  final GameState gameState;
  final int moveCount;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.brown.shade50,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: AspectRatio(
            aspectRatio: gameState.board.width / gameState.board.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cellSize =
                    constraints.maxWidth / gameState.board.width;
                return Stack(
                  children: [
                    _BoardView(
                      gameState: gameState,
                      cellSize: cellSize,
                    ),
                    if (gameState.isSolved)
                      _ClearOverlay(
                        moveCount: moveCount,
                        onRestart: onRestart,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 操作パッド + Undo / Restart ボタンをまとめたセクション。
class _ControlSection extends StatelessWidget {
  const _ControlSection({
    required this.gameState,
    required this.history,
    required this.onMove,
    required this.onUndo,
    required this.onRestart,
  });

  final GameState gameState;
  final List<GameState> history;
  final void Function(Direction) onMove;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DirectionPad(
            onMove: onMove,
            enabled: !gameState.isSolved,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: history.isNotEmpty ? onUndo : null,
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
                  onPressed: history.isNotEmpty ? onRestart : null,
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
        ],
      ),
    );
  }
}

/// 狭い画面向けの縦積みレイアウト（従来と同じ構成）。
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.boardSection,
    required this.statusCard,
    required this.controlSection,
  });

  final Widget boardSection;
  final Widget statusCard;
  final Widget controlSection;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: statusCard,
              ),
              Expanded(child: boardSection),
              const SizedBox(height: 16),
              controlSection,
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// 広い画面向けの 2 カラムレイアウト。
/// 左に盤面、右にステータスカードと操作セクションを配置する。
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.boardSection,
    required this.statusCard,
    required this.controlSection,
  });

  final Widget boardSection;
  final Widget statusCard;
  final Widget controlSection;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 左カラム: 盤面 ---
              Expanded(
                flex: 3,
                child: boardSection,
              ),
              const SizedBox(width: 24),
              // --- 右カラム: ステータス + 操作 ---
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    statusCard,
                    const SizedBox(height: 16),
                    controlSection,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手数・残り箱数・クリア状態・ヒントを統合表示するステータスカード。
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.moveCount,
    required this.remainingBoxes,
    required this.isSolved,
    required this.moveBlocked,
  });

  final int moveCount;
  final int remainingBoxes;
  final bool isSolved;
  final bool moveBlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPlaced = remainingBoxes == 0;

    return Container(
      decoration: BoxDecoration(
        color: isSolved
            ? Colors.green.shade50
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSolved
              ? Colors.green.shade200
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- クリアバナー（クリア時のみ表示） ---
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
            child: isSolved
                ? Container(
                    key: const ValueKey('clear-banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.emoji_events,
                              color: Colors.green.shade600, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'クリア！',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              '$moveCount手でクリア',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('no-banner'),
                  ),
          ),
          // --- 進捗情報（手数・残り箱数） ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.directions_walk,
                    iconColor: Colors.blue,
                    label: '手数',
                    value: '$moveCount',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.inventory_2,
                    iconColor:
                        allPlaced ? Colors.green : Colors.orange.shade800,
                    label: '配置',
                    value: allPlaced ? '全配置！' : 'あと$remainingBoxes個',
                  ),
                ),
              ],
            ),
          ),
          // --- ヒントテキスト ---
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.only(left: 14, right: 14, bottom: 8, top: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                isSolved
                    ? 'クリア済み — Ctrl+Z で戻す・R でやり直し'
                    : moveBlocked
                        ? 'その方向には進めません'
                        : '移動: ボタン／矢印・WASD ｜ 戻す: Ctrl+Z ｜ やり直し: R',
                key: ValueKey(
                  isSolved
                      ? 'hint-cleared'
                      : moveBlocked
                          ? 'hint-blocked'
                          : 'hint-normal',
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: moveBlocked && !isSolved
                      ? Colors.red.shade400
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 進捗カード内の個別項目（アイコン + ラベル + 値）。
class _StatItem extends StatelessWidget {
  const _StatItem({
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
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// クリア時に盤面上へ表示する完了オーバーレイ。
class _ClearOverlay extends StatelessWidget {
  const _ClearOverlay({
    required this.moveCount,
    required this.onRestart,
  });

  final int moveCount;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 36,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'クリア！',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$moveCount手でクリア',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('overlay-restart'),
                      onPressed: onRestart,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('もう一度'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(120, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
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
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.brown.shade600, Colors.brown.shade800],
          ),
          border: Border.all(color: Colors.brown.shade900, width: 0.5),
        ),
      );
    }

    final floorColor = Colors.amber.shade50;
    final goalBgColor = Colors.green.shade50;

    // --- ゴール上のプレイヤー ---
    if (isPlayer && isGoal) {
      return Container(
        color: goalBgColor,
        child: Stack(
          children: [
            const Positioned.fill(
              child: GoalMarkerWidget(),
            ),
            const Positioned.fill(
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
      return Container(
        color: floorColor,
        padding: const EdgeInsets.all(2),
        child: const PlayerWidget(),
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
      return Container(
        color: floorColor,
        padding: const EdgeInsets.all(1),
        child: const BoxWidget(),
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
    return Container(
      decoration: BoxDecoration(
        color: floorColor,
        border: Border.all(color: Colors.amber.shade100, width: 0.5),
      ),
    );
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

    Widget dirButton(Direction dir, IconData icon, String label) {
      return SizedBox(
        width: btnSize,
        height: btnSize,
        child: IconButton(
          onPressed: enabled ? () => onMove(dir) : null,
          icon: Icon(icon, size: 28),
          tooltip: label,
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            disabledBackgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: enabled
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            elevation: enabled ? 2 : 0,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dirButton(Direction.up, Icons.keyboard_arrow_up, '上'),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dirButton(Direction.left, Icons.keyboard_arrow_left, '左'),
              const SizedBox(width: btnSize + 8, height: btnSize),
              dirButton(Direction.right, Icons.keyboard_arrow_right, '右'),
            ],
          ),
          const SizedBox(height: 4),
          dirButton(Direction.down, Icons.keyboard_arrow_down, '下'),
        ],
      ),
    );
  }
}
