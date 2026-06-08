# adversarial-review

`correctness-reviewer` を**2体だけ**立て、コード/解析スクリプトのバグと
本来の目的との整合を独立にレビューさせ、**互いの指摘を反証し合わせて**、
生き残った指摘だけを統合報告するスキル。

## 前提
- Agent teams 有効（`env` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`、設定後の新セッション）
- `~/.claude/agents/correctness-reviewer.md`

## 使い方
`/adversarial-review [対象]` — 対象はファイル/ディレクトリ/差分。引数なしなら git 差分。

## 流れ
TeamCreate → correctness-reviewer を reviewer-a / reviewer-b で2体起動 →
各自独立レビュー → SendMessage で相手の指摘を1件ずつ反証 →
確定/却下/論点残りに整理して統合 → shutdown → TeamDelete。

## 使い分け
- 2体で確実性重視（バグ＋目的整合）→ `adversarial-review`（本スキル）
- 性能・科学的正しさ等も含む多観点 → `team-review`
- 手軽な単体レビュー → `codex-review` / `code-review`

詳細は `SKILL.md`。
