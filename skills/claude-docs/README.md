# claude-docs

Claude Code の設定・機能を**公式ドキュメントで裏取り**するためのスキル。
記憶や推測で架空の設定キー / JSON ブロックを書いてしまうミスを防ぐ。

## 使い方

- **自動参照**: `settings.json`・hooks・MCP・permissions・slash commands・subagents・
  plugins・skills を編集する前や、「この設定/機能は存在するか」を答える前に Claude Code が参照する。
- **明示呼び出し**: `/claude-docs [調べたいキーや機能名]` で公式ドキュメントを取得して確認する。

## 仕組み

1. 全ページ索引 `https://code.claude.com/docs/llms.txt` から実在ページURLを特定（URLを推測しない）
2. 該当ページの `.md` を取得し、キー名・型・構造・スコープを抜き出す
3. 手元の設定ファイルは現状把握のために読むだけ（既存キーは公式根拠にしない）。矛盾があれば停止して報告
4. 確認できないキー・構造は書かない／「ドキュメント未確認」と明記する

実際の設定編集は `update-config`、API 寄りの質問は `claude-api` に委譲する。
詳細は `SKILL.md` を参照。
