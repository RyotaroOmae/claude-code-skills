---
name: team-review
description: Agent teams を使い、複数のレビュアー teammate にコード/解析スクリプトを多観点で検証させ、互いの指摘を反証し合わせてから統合報告する。バグ・本来の目的との整合・性能・科学的正しさを並行レビューしたいときに使う。adversarial review / チームレビュー / 複数エージェントでの検証。
user-invocable: true
argument-hint: "[レビュー対象: ファイル/ディレクトリ/差分/自然言語の指示, optional]"
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

# team-review — Agent teams による多観点・反証つきコード検証

複数のレビュアー teammate を立て、対象コードを**別々の観点で並行レビュー**させ、
**互いの指摘を反証し合わせて**から、合意できた指摘だけを統合して報告するスキル。

このセッション自身が**チームのリード**になって全体を統括する。

Arguments passed: `$ARGUMENTS`（レビュー対象。ファイル/ディレクトリ/差分/観点の指示）

---

## 前提チェック（最初に必ず）

1. Agent teams が有効か確認する。`TeamCreate` ツールが使えなければ、機能が無効
   （`settings.json` の `env` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` が必要、
   かつ**設定後に起動した新セッション**であること）。無効ならその旨を伝えて中断し、
   代替として単体の `/codex-review` や `/code-review` を提案する。
2. レビュアー定義が `~/.claude/agents/` にあるか確認（`correctness-reviewer` /
   `perf-reviewer` / `science-reviewer`）。無い型は使わない。

---

## レビュー対象の決定

`$ARGUMENTS` をパースする。

- **パス（ファイル/ディレクトリ）**: 存在確認し、それを対象にする。
- **自然言語の観点指示**: 追加観点としてリードの指示に混ぜる。
- **引数なし**: cwd が git 管理下なら未コミット差分（無ければブランチ差分）を対象にする。
  git 外なら「対象を指定してください」と確認する。
- 巨大すぎる対象（数千行〜）は、ファイル/モジュール単位に絞るようユーザーに確認する。

---

## チーム編成（対象に応じて選ぶ）

| 対象の性質 | 推奨 teammate |
|---|---|
| 一般のコード | correctness ×2、perf ×1 |
| 解析スクリプト（数値・物理・統計） | science ×1、correctness ×1〜2、（重い処理があれば perf ×1） |
| 軽い検証 | correctness ×1、science ×1 |

> トークンを使うので、性能が論点でないなら perf を外すなど**必要最小の編成**にする。
> 同じ型を複数立てる場合は teammate 名で区別する（例 `correctness-a` / `correctness-b`）。

---

## 実行手順

1. **チーム作成**: `TeamCreate`（例 `team_name: "review-<対象名>"`, `description` に目的）。
2. **teammate 起動**: `Agent` ツールで、`team_name`・`name`・`subagent_type`（上のレビュアー型）
   を指定して必要数を spawn する。spawn プロンプトには必ず含める:
   - 対象パスとレビューの焦点（teammate はリードの会話履歴を引き継がないため前提も明示）
   - **結果は必ず lead（このセッション）へ `SendMessage` で返す**こと（初回レビュー→反証結果→完了の各段階）
3. **タスク割当**: `TaskCreate` で観点ごとのレビュータスクを作り、`TaskUpdate` の `owner` で
   各 teammate に割り当てる（Task 系が使えない環境なら spawn プロンプト/`SendMessage` で代替）。
   lead は**各 teammate から初回レビューを `SendMessage` で受領するまで待つ**
   （inbox は自動配信なので polling しない）。
4. **反証フェーズ**: 各自の初回指摘が出たら、`SendMessage` で互いの指摘を反証させる。
   **全ての非自明な指摘は、最低1名（別 teammate）に反証確認させる**こと。
   観点が重なる teammate 同士（例: correctness-a と correctness-b）は相手の指摘を相互検証する。
   **その観点を1体しか立てていない場合（perf/science 単独など）は、その指摘を lead が反証確認する。**
   どこからも反証を受けていない指摘は「**未反証**」、lead が確認したものは「**lead 確認済み**」と区別する。
5. **統合**: 全 teammate の結論が出たら、リード（このセッション）が指摘を重複排除し、
   反証を生き残った指摘を重要度順にまとめる。各指摘に反証ステータス（合意/lead確認済み/未反証）を添える。

---

## 出力フォーマット

最終報告はリードが作る。

- 観点ごとではなく**重要度順**に統合する。各指摘に「どの観点の誰が出し、反証で残ったか」を添える。
- **[重要度: high|medium|low] <ファイル>:<行> — <一言>** / 問題内容 / 推奨修正
- 反証で却下された指摘は「検討したが却下（理由）」として簡潔に残す（再浮上防止）。
- 問題が無ければ "no issues found" と明記。

---

## 後片付け（必須・異常時も）

チーム作成直後に、使った `team_name` と全 teammate 名を控えておく。
**正常終了でも途中で失敗しても、必ず後片付けを試みる**（teammate を起動した以上、放置しない）。

1. 完了したら各 teammate に `SendMessage` で `{type: "shutdown_request"}` を送り、
   全員のシャットダウンを待つ。
2. 全員終了後に `TeamDelete` でチームとタスクを削除する
   （active member が残っていると失敗するので順序を守る）。
3. 片付けは必ずリードが行う。

**異常時（teammate 無応答 / レビュー中断 / `TeamDelete` 失敗）:**
- 残る全 teammate に改めて `{type: "shutdown_request"}` を送って待つ。
- それでも `TeamDelete` が失敗するなら、無理に消さず、**`team_name`・残存 member・
  `~/.claude/teams/<team_name>/config.json` の場所・手動復旧手順**をユーザーに報告して止める。
- レビューが途中で失敗しても、得られた部分的な指摘は破棄せず報告する。

---

## 注意

- teammate はリードの権限を引き継ぐ。レビュー目的なので読み取り＋再現確認に留め、
  対象の書き換えはさせない（修正は別途、人の確認後に行う）。
- teammate 定義の `skills` / `mcpServers` は teammate 起動時には適用されない
  （project/user 設定から読まれる）。レビューに必要な前提は spawn プロンプトに書く。
- リードが勝手にレビューを代行せず、teammate の結論を尊重して統合に徹する。
  ただし反証フェーズで明らかな誤りを見つけたら指摘してよい。

---

## 関連スキルとの違い

- `team-review`（本スキル）: **複数エージェントで多観点・反証つき**。重いが網羅的。
- `codex-review`: 外部 Codex 1体による汎用レビュー。手軽。
- `code-review`: 差分に対する組み込みレビュー。

軽い確認は `codex-review` / `code-review`、重要な検証は本スキル、と使い分ける。
