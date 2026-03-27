# プロダクトバックログ

> 個人用 Flutter Sokoban アプリのための、暫定的な初期バックログ。
>
> まずは軽量に保ち、必要になったら育てる。

## プロダクト目標

iOS / Android 向けに、気持ちよく遊べる Sokoban アプリを作る。まずはパズル挙動の正しさと、読みやすい UI、あとで拡張しやすい土台を優先する。

v1 の基準:
- 複数ステージを遊べる
- 画面内ボタン（上下左右）で操作できる
- Undo / Restart がある
- レベルはテキスト形式で assets に持つ
- 見た目はミニマル寄りだが、少し気持ちよさを持たせる

## ステータス

- `ready`
- `needs-clarification`
- `blocked`
- `done`

---

## Now

### 1. Flutter アプリの土台を作る
- **Status:** `done`
- **Purpose:** 実行可能なアプリの基本構造、lint、最小のアプリシェルを整える。
- **Acceptance ideas:**
  - iOS / Android で起動できる
  - プロジェクト構造が把握しやすい
  - プレースホルダーのホーム画面がある
- **実装メモ:** PR #3 で最小アプリシェルを追加済み。

### 2. Sokoban のコアドメインモデルを実装する
- **Status:** `done`
- **Purpose:** 壁、床、箱、ゴール、プレイヤー、盤面状態を明快に表現できるようにする。
- **Acceptance ideas:**
  - 盤面状態を安定して構築または解析できる
  - プレイヤー移動ルールがテスト可能な形で表現されている
  - 箱押しルールが正しく扱われる

### 3. クリア判定ロジックを追加する
- **Status:** `done`
- **Purpose:** すべての箱がゴール上にある状態を検出する。
- **Acceptance ideas:**
  - クリア判定が決定的である
  - unit test で保護されている

### 4. 1 ステージ遊べる画面を作る
- **Status:** `done`
- **Purpose:** Flutter の最小アプリシェルの上で、固定の 1 ステージを実際に遊べる最小のエンドツーエンド体験を成立させる。
- **Acceptance ideas:**
  - Flutter の最小アプリシェル上で 1 ステージが表示される
  - 画面内ボタン（上下左右）でプレイヤーを操作できる
  - 毎手ごとに盤面が正しく更新される
  - クリア状態がユーザーに見える
  - Flutter Web でも基本動作を確認しやすい
- **実装メモ:** PR #5 で固定ステージの遊べる画面を追加済み。

### 5. パズルロジックのテストを追加する
- **Status:** `done`
- **Purpose:** 移動、押し出し、衝突、クリア判定を守る。
- **Acceptance ideas:**
  - 重要なロジック経路に unit test がある
  - 回帰バグをテストで再現できる
- **実装メモ:** PR #1, #2, #4 でコアロジックと異常系のテストを追加済み。

---

## Later

### 6. レベル読み込み形式を決める
- **Status:** `needs-clarification`
- **Purpose:** レベルをどう保存し、どう読み込むかを決める。
- **Notes:** asset のテキストマップ、JSON、あるいはもっと簡潔な表現など候補あり。

### 7. 複数レベルと進行管理
- **Status:** `needs-clarification`
- **Purpose:** レベル選択やレベルパック進行を扱えるようにする。

### 8. Undo / Restart を追加する
- **Status:** `done`
- **Purpose:** `GameState` の履歴を画面側で薄く扱い、1 手ずつ戻す Undo とステージ初期化の Restart を追加して、倉庫番としての遊びやすさを上げる。
- **Acceptance ideas:**
  - 固定 1 ステージのまま、移動成功時だけ履歴が積まれる
  - Undo ボタンから 1 手ずつ戻せる
  - Restart で初期状態と履歴がリセットされる
  - 既存のゲーム進行やクリア判定を壊さない
- **実装メモ:** PR #6 で Undo / Restart を追加済み。

### 9. 手数カウンタ / 簡易統計
- **Status:** `done`
- **Purpose:** 移動成功回数を表示し、クリア時に簡単な結果を見せてプレイ感と達成感を上げる。
- **Acceptance ideas:**
  - 移動成功回数が常時表示される
  - クリア時に「クリア！ 12手」のような簡易結果表示が出る
  - Restart で手数がリセットされる
  - 表示追加が既存の最小 UI と大きく衝突しない
- **実装メモ:** PR #7 で手数カウンタ、PR #8 でクリア時の手数表示を追加済み。

### 10. プレイ状態の保存 / 復元
- **Status:** `needs-clarification`
- **Purpose:** アプリ再起動後も進行状態を保持する。

### 11. モバイル UX の磨き込み
- **Status:** `ready`
- **Purpose:** レイアウト、アニメーション、フィードバック、操作感を改善する。
- **Acceptance ideas:**
  - プレイ中の進捗表示（残り箱数など）を追加し、ひと目で把握しやすくする
  - SafeArea や最大幅の調整でレイアウトを整える
  - 操作補助ボタン（Undo / Restart）を画面下部に配置する
  - クリア後の方向ボタン無効化など、状態に応じたフィードバックを改善する
- **実装メモ:** PR #11 でクリア後ボタン無効化、PR #12 で SafeArea 調整、PR #13 で補助ボタン追加、PR #14 で残り箱数表示を追加。

### 12. GitHub Actions で analyze / test を自動化する
- **Status:** `done`
- **Purpose:** PR と `main` への push で `flutter analyze` / `flutter test` を自動実行し、回帰を早めに検知できる状態を作る。
- **Acceptance ideas:**
  - GitHub Actions の最小 workflow が追加されている
  - PR 作成時に `flutter analyze` と `flutter test` が自動実行される
  - `main` への push でも `flutter analyze` と `flutter test` が実行される
  - 失敗時に GitHub 上で分かる
  - Flutter セットアップを含めても過剰でない最小限の構成になっている
- **実装メモ:** PR #9 で CI workflow を追加済み。

---

## Icebox

### 13. レベルエディタ
- **Status:** `needs-clarification`
- **Purpose:** アプリ内で Sokoban ステージを作成・編集できるようにする。

### 14. クラウド同期
- **Status:** `blocked`
- **Purpose:** 端末間で進捗を同期する。
- **Reason:** 最初の有用バージョンには不要。

### 15. デイリーチャレンジ / キュレーションパック
- **Status:** `blocked`
- **Purpose:** コアゲームが固まったあとに再遊性を足す。

---

## 将来の AI 作業メモ

- まずは `Now` の項目を優先する。
- 自走してよいのは、明確に `ready` な項目だけ。
- `needs-clarification` の項目は、実装前に小さな提案か確認質問を足す。
- backlog の更新は小さく、事実ベースで行う。

## 言語ルール

- このファイル内の説明文、項目説明、補足は基本的に日本語で書く。
- ステータス値 (`ready` など) やファイル名、技術用語は必要に応じて英語のままでよい。
