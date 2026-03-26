# sokoban-app

OpenClaw を使って実験的に開発を進めている、個人用のモバイル倉庫番（Sokoban）アプリです。

## 概要

このリポジトリは、iOS / Android 向けの倉庫番アプリを育てていくためのものです。

現在は、AI 支援で継続開発しやすいように、要件・設計・バックログの初期文書を先に整えています。

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

このプロジェクトは、スマホ実機がなくても Flutter Web で基本動作を確認しやすい構成を目指しています。

Flutter プロジェクト本体の初期化後は、たとえば次のような流れで確認できます。

```bash
flutter config --enable-web
flutter create .
flutter run -d chrome
```

> 実際のコマンドは、Flutter プロジェクトの構成が入った段階で調整してください。
> 現時点ではまだ Flutter 本体は未作成です。

## 今後の予定

- Flutter プロジェクト本体の初期化
- 倉庫番のコアロジック実装
- レベル表現の決定
- 複数ステージ / Undo / Restart 対応

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
