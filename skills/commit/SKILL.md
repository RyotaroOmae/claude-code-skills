---
name: commit
description: CLAUDE.md のコミットメッセージ規約に従って git コミットを作成する。何を・なぜ変えたかを具体的に書き、曖昧な「update X.py」を避ける。秘密情報の混入チェックと、main/master 上での誤コミット防止も行う。
user-invocable: true
argument-hint: "[補足メッセージ, optional]"
allowed-tools:
  - Read
  - Bash(git status:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git branch:*)
  - Bash(git rev-parse:*)
---

# /commit — 規約準拠の git コミット

`~/.claude/CLAUDE.md` のコミットメッセージ規約に従い、明確で具体的な
コミットメッセージを作成してコミットする。

Arguments passed: `$ARGUMENTS`（あれば、メッセージの意図・背景の補足として使う）

---

## 手順

1. **変更を把握する**
   - `git status` と `git diff --staged` を見る。
   - ステージ済みがある場合は、それを対象にする（追加で add するか確認してもよい）。
   - ステージ済みが無い場合: 未ステージ変更（`git diff` / `git status`）があれば
     内容を見せ、何を add するかをユーザーに確認してから `git add` する
     （勝手に全部 add しない）。**変更が一切無ければ中断**する。

2. **メッセージ草案を作る**（規約準拠）
   - 形式: `ファイル名: 具体的な変更内容`（変更の主対象が分かるように）。
   - **何を・なぜ**変えたかを簡潔に。曖昧な `update X.py` は禁止。
   - 良い例: `plot_mynn.py: add vertical profile plot for TKE and mixing length`
   - 複数ファイル/論点なら本文（body）に箇条書きで補足してよい。
   - `$ARGUMENTS` があれば「なぜ」の補足として反映する。

3. **確認 → コミット**
   - 草案をユーザーに提示し、承認を得てからコミットする。
   - コミットメッセージ末尾に必ず次の1行を付ける（harness 規約）:
     ```
     Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
     ```

## Gotchas

- **コミットすべき変更が一切無ければ中断**（誤って空コミットしない）。
  ステージ済みが無くても未ステージ変更があれば、上記手順1で add 可否を確認してから進める。
- **秘密情報・環境変数を差分に含めない**（CLAUDE.md 禁止事項）。
  diff に API キー・トークン・パスワード・`.env` 値らしきものを見つけたら、
  コミットせず警告し、除外を促す。
- **main / master 上なら先にブランチ作成を提案**する（harness 規約）。
  `git rev-parse --abbrev-ref HEAD` で現在ブランチを確認。
- **コミットの言語はリポジトリに合わせる**。`git log --oneline -10` で既存の
  傾向を見て、英語リポジトリなら英語（規約の例も英語形式）、日本語なら日本語で。
- ユーザーが push を頼んでいない限り push しない（コミットまで）。
