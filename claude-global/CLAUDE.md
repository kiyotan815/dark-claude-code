# CLAUDE.md

## Conversation Guidelines

- 常に日本語で会話する

## Kit (dark-claude-code plugin)

以下で参照する skill / agent / command は `dcc@dark-claude-code` plugin が提供する（`/dcc:codex-flow` のように `dcc:` プレフィックスで呼ぶ）。
未インストールなら: `claude plugin marketplace add kiyotan815/dark-claude-code && claude plugin install dcc@dark-claude-code`

## Hybrid Orchestration (Claude ⇔ Codex)

役割分担: Claude Code = 司令塔（設計・タスク分割・監査）、Codex = 実行部隊（実装・テスト実行）。

推奨パイプライン: **設計（dcc:codex-spec skill）→ 実装委譲（dcc:codex-delegate skill）→ 監査（dcc:codex-auditor agent）**。

- **設計フェーズ**: Codex に委譲する見込みの機能・リファクタ・移行を設計するときは dcc:codex-spec skill を使い、実装ユニットに分割された Codex 向け設計書を書く。これにより後段の委譲品質が決まる。
- Claude Code は実装依頼を以下の基準で自動ルーティングする（ユーザーが実行者を明示した場合はそれに従う）:
  - **dcc:codex-delegate skill で Codex に委譲する**:
    - 設計書・仕様が固まっている実装タスク
    - 複数ファイルにまたがる新規実装
    - 並列化できる独立タスク群
  - **Claude が直接実装する**:
    - 小規模な修正（数ファイル以内の bugfix・調整）
    - デバッグ・原因調査
    - リファクタリング・レビュー・監査

委譲した場合も、成果物の監査（diff レビュー・テスト再実行）と commit は必ず Claude が行う。

## Development Philosophy

### Test-Driven Development (TDD)

- 原則としてテスト駆動開発（TDD）で進める
- 期待される入出力に基づき、まずテストを作成する
- 実装コードは書かず、テストのみを用意する
- テストを実行し、失敗を確認する
- テストが正しいことを確認できた段階でコミットする
- その後、テストをパスさせる実装を進める
- 実装中はテストを変更せず、コードを修正し続ける
- すべてのテストが通過するまで繰り返す
