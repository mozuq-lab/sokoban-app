# sokoban-app

OpenClaw を使って実験的に開発を進めている、個人用のモバイル倉庫番（Sokoban）アプリです。

## 概要

このリポジトリは、iOS / Android 向けの倉庫番アプリを育てていくためのものです。

現在は固定の 1 ステージを実際に遊べる状態まで実装が進んでいます。画面内ボタンでの操作、Undo / Restart、手数カウンタ、クリア時の手数表示が動作します。

## v1 の目標

初期バージョンでは、少なくとも次を目指します。

- 複数ステージを遊べる
- 画面内ボタン（上下左右）で操作できる
- Undo / Restart がある
- クリア判定がある
- レベルはテキスト形式で assets に持つ

## 技術方針

- Flutter による iOS / Android 両対応
- スマホ実機がなくても、まずは Flutter Web で基本動作を確認しやすい構成を目指す
- コアのパズルロジックをテストしやすく保つ
- ドキュメントは基本的に日本語で管理する
- 依存追加は必要最小限にする

## CI

GitHub Actions により、PR と `main` への push で `flutter analyze` / `flutter test` が自動実行されます。

設定ファイル: `.github/workflows/ci.yml`

## 動作確認について

このプロジェクトは、スマホ実機がなくても Flutter Web で基本動作を確認しやすい構成になっています。

```bash
flutter run -d chrome
```

## 今後の予定

- レベル読み込み形式の決定
- 複数ステージと進行管理
- プレイ状態の保存 / 復元
- モバイル UX の磨き込み

## ドキュメント

最初に読むとよいもの:

- `docs/product-brief.md`
- `docs/product-backlog.md`
- `docs/architecture.md`
- `CLAUDE.md`

## v1 で入れないもの

少なくとも初期段階では、次は対象外です。

- クラウド同期
- レベルエディタ
- 派手なアニメーション
- オンライン要素
