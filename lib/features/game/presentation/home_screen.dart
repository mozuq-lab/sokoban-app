import 'package:flutter/material.dart';

/// 倉庫番アプリのホーム画面。
///
/// 現時点ではプレースホルダー。今後ここからゲーム画面に遷移する。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sokoban'),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.grid_on,
              size: 64,
              color: Colors.brown,
            ),
            SizedBox(height: 16),
            Text(
              '倉庫番',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'ゲーム画面は次のステップで実装します',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
