---
name: adversarial-review
description: correctness-reviewer を2体だけ立て、コード/解析スクリプトのバグと本来の目的との整合を独立にレビューさせ、互いの指摘を反証し合わせてから、生き残った指摘だけを統合報告する。2体による adversarial review に特化。多観点の網羅レビューが要るときは team-review を使う。
user-invocable: true
argument-hint: "[レビュー対象: ファイル/ディレクトリ/差分, optional]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Agent
  - TeamCreate
  - TeamDelete
  - SendMessage
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# adversarial-review — correctness-reviewer 2体の反証レビュー

`correctness-reviewer` を **2体だけ**立て、対象を独立にレビューさせ、
**互いの指摘を反証し合わせて**、反証を生き残った指摘だけを統合するスキル。
このセッションがチームのリードになって統括する。

観点を増やしたい（性能・科学的正しさ等）場合は `team-review` を使う。本スキルは
「**バグ＋本来の目的との整合**を、独立した2視点で厳しく潰す」ことに絞る。

Arguments passed: `$ARGUMENTS`（レビュー対象）

---

## 前提チェック

1. `TeamCreate` が使えること（Agent teams 有効＝`settings.json` の env に
   `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`、設定後に起動した新セッション）。
   使えなければ中断し、代替に `/codex-review` を提案する。
2. `~/.claude/agents/correctness-reviewer.md` が存在すること。無ければ中断して知らせる。

---

## レビュー対象の決定

`$ARGUMENTS` をパースする。

- パス → 存在確認して対象に。
- 引数なし → cwd が git 管理下なら未コミット差分（無ければブランチ差分）。git 外なら対象を確認。
- 巨大すぎる対象はファイル/モジュール単位に絞るよう確認する。

---

## 実行手順

1. **チーム作成**: `TeamCreate`（例 `team_name: "adv-<対象名>"`、`description` に目的）。
2. **2体起動**: `Agent` ツールで `subagent_type: correctness-reviewer` を**2体**、
   `name` を `reviewer-a` / `reviewer-b` として spawn。各 spawn プロンプトに必ず含める:
   - 対象パスと前提（teammate はリードの履歴を引き継がない）
   - **互いを意識せず、まず独立にレビュー**すること
   - **結果は必ず lead（このセッション）へ `SendMessage` で返す**こと（初回レビュー→反証結果→完了の各段階）
3. **独立レビュー**: レビュータスクを割り当てる（`TaskCreate`＋`TaskUpdate(owner)` が使える環境なら
   それで、無ければ spawn プロンプト/`SendMessage` で指示）。lead は**両者から初回レビューを
   `SendMessage` で受領するまで待つ**（inbox は自動配信なので polling しない）。
4. **反証フェーズ（核心）**: 両者の初回指摘が出たら、`SendMessage` で
   **相手の指摘を1件ずつ反証させる**。各指摘について
   「再現できるか / 本当に目的に反するか / 誤検知ではないか」を検証させ、
   - 両者が合意した指摘 → 確定
   - 反証された指摘 → 却下（理由を記録）
   - 合意できない指摘 → 「論点が残る」として両者の主張を併記
   teammate 間通信は自動配信。リードは inbox を polling しない。
5. **統合**: リードが重複排除し、上記の確定/却下/論点残りに整理する。

---

## 出力フォーマット

- **確定した指摘**（重要度順）: **[重要度: high|medium|low] <ファイル>:<行> — <一言>** / 内容 / 推奨修正 /
  （どちらが指摘し、反証を経て残ったか）
- **却下された指摘**: 一行で「指摘→却下理由」（再浮上防止のため簡潔に残す）
- **論点が残った指摘**: 両者の主張を併記し、人間の判断に委ねる
- 問題が無ければ "no issues found"。

---

## 後片付け（必須・異常時も）

チーム作成直後に、使った `team_name` と teammate 名（`reviewer-a`/`reviewer-b`）を控えておく。
**正常終了でも途中で失敗しても、必ず後片付けを試みる**（teammate を起動した以上、放置しない）。

1. 完了後、両 teammate に `SendMessage` の `{type: "shutdown_request"}` を送り、終了を待つ。
2. 全員終了後に `TeamDelete`（active member 残存だと失敗するので順序厳守）。
3. 片付けは必ずリードが行う。

**異常時（片方が無応答 / 反証が中断 / `TeamDelete` が失敗）:**
- 残っている全 teammate に改めて `{type: "shutdown_request"}` を送って待つ。
- それでも `TeamDelete` が失敗するなら、無理に消さず、**`team_name`・残存 member・
  `~/.claude/teams/<team_name>/config.json` の場所・手動復旧手順**をユーザーに報告して止める。
- レビュー自体が失敗しても、ここまで得られた部分的な指摘は破棄せず報告する。

---

## 注意

- teammate はレビュー目的。読み取り＋再現確認に留め、対象を書き換えさせない。
- リードは2体の結論を尊重して統合に徹する。ただし反証フェーズで明らかな誤りに気づけば指摘してよい。
- 同じ型を2体起動できない環境だった場合は、`correctness-reviewer.md` を複製した
  別名定義（`name` のみ変更）を使う。
- Task 系ツール（TaskCreate/TaskUpdate/TaskList）はチームの標準的な調整機構だが、
  使えない場合でも spawn プロンプトと `SendMessage` だけでタスク割当・進捗・反証依頼は完結できる。
