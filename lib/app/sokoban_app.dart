import 'package:flutter/material.dart';

import '../features/game/presentation/home_screen.dart';

/// アプリのルートウィジェット。
class SokobanApp extends StatelessWidget {
  const SokobanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sokoban',
      theme: ThemeData(
        colorSchemeSeed: Colors.brown,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
