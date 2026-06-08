---
name: careful
description: 慎重モードに入る。rm -rf・force push・reset --hard・既存ファイル上書き・大量削除など不可逆な操作を実行する前に、必ず正確なコマンドを提示して明示的な確認を取らせる。データ消失やリポジトリ破壊を避けたい作業の前に使う。
user-invocable: true
allowed-tools:
  - Read
  - Bash(bash *)
  - Bash(ls *)
  - Bash(git status:*)
---

# /careful — 慎重モード（破壊的操作ガード）

このスキルが呼ばれたら、**このセッションの残りの間**、不可逆・破壊的な操作を
実行する前に必ずユーザーへ正確なコマンドを提示し、明示的な承認（y/n）を得てから実行する。
承認が取れるまで実行しない。

Arguments passed: `$ARGUMENTS`（特定対象や追加で警戒したい操作があれば指定）

---

## 適用するポリシー（宣言）

慎重モードに入ったことをユーザーに一言伝え、以降は次を徹底する：

1. **不可逆操作は実行前に必ず確認**する。対象（下記）に当たるコマンドは、
   そのまま実行せず「これから何を・どこに対して行うか」を1〜2行で説明し承認を求める。
2. 可能なら**安全な代替を先に提案**する：ドライラン（`--dry-run`, `-n`）、
   バックアップ（コピーしてから）、対話確認付き（`rm -i`, `mv -i`）、
   `git stash`/ブランチ退避など。
3. 判断に迷うコマンドは `scripts/check_dangerous.sh` に通して危険度を自己チェックする：
   ```
   bash <skill_dir>/scripts/check_dangerous.sh '<実行しようとするコマンド>'
   ```
   `DANGER:` なら必ず確認、`WARN:` なら一言添えて確認、`OK:` ならそのまま実行可。

## 警戒する操作（不可逆になりうるもの）

- `rm -rf` / `rm -r` / ワイルドカード削除 / 大量ファイルの削除・移動
- `git push --force` / `--force-with-lease`、`git reset --hard`、`git clean -fd`、
  `git checkout .` / `git checkout -- .`、`git restore .`、ブランチ削除 `git branch -D`
- **既存ファイルの上書き**（特に大きい・自分で作っていない `*.nc` や実験出力、
  リダイレクト `>` での上書き、`cp`/`mv` による上書き）
- DB/テーブル破壊（`DROP`, `TRUNCATE`, `DELETE` without WHERE）
- `chmod -R` / `chown -R` の広範囲適用、`truncate`、`> file` での空化
- 外部公開・送信を伴う操作（push, デプロイ, アップロード）も一度確認する

## Gotchas

- このスキルは**このセッション内の振る舞いを制御するだけ**で、ツール自体を
  ブロックする恒久的な仕組みではない。新しいセッションでは再度呼ぶ必要がある。
- 恒久的に強制したい場合は `settings.json` の `PreToolUse` フックで実装できる
  （`update-config` スキルが使える）。本スキルはその軽量版。
- ユーザーが「もう確認不要」と明示したら、その対象に限り確認を省いてよい。
