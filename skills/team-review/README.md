# team-review

Agent teams を使って、複数のレビュアー teammate にコード/解析スクリプトを
多観点でレビューさせ、**互いの指摘を反証し合わせて**から統合報告するスキル。

## 前提
- `settings.json` の `env` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`（設定後に起動した新セッション）
- `~/.claude/agents/` にレビュアー定義（`correctness-reviewer` / `perf-reviewer` / `science-reviewer`）

## 使い方
- `/team-review [対象]` — 対象はファイル/ディレクトリ/差分/観点指示。引数なしなら git 差分。
- このセッションがチームのリードになり、teammate を立て→反証させ→統合し→片付けまで行う。

## 仕組み
TeamCreate でチーム作成 → Agent ツールで teammate 起動 → タスク割当 →
SendMessage で反証フェーズ → リードが重複排除して重要度順に統合 → shutdown → TeamDelete。

## 使い分け
- 重い/網羅的な検証 → `team-review`
- 手軽な単体レビュー → `codex-review` / `code-review`

詳細は `SKILL.md`。
