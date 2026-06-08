---
name: jobwatch
description: PBS バッチジョブの状態を qstat で確認し、実験ディレクトリのログ(s/o/l/n.log)から ERROR/WARNING/NaN を検出して要約する。SCALE 解析パイプラインのジョブが通ったか・どの段で失敗したかを素早く確認したいときに使う。
user-invocable: true
argument-hint: "[job-id または実験ディレクトリ, optional]"
allowed-tools:
  - Read
  - Glob
  - Bash(bash *)
  - Bash(qstat:*)
  - Bash(tail:*)
  - Bash(grep:*)
  - Bash(ls *)
---

# /jobwatch — PBS ジョブ監視＋ログ異常検知

PBS ジョブの状態と、SCALE 解析パイプラインのログ異常をまとめて確認する。

Arguments passed: `$ARGUMENTS`

---

## 対象の決定

`$ARGUMENTS` をパースする。

- **job-id**: そのジョブの状態を `qstat <id>`（無ければ `qstat -x <id>`）で確認。
- **ディレクトリ**: その実験ディレクトリのログを対象にする。
- **引数なし**: `qstat -u $USER` で自分の全ジョブを確認し、cwd（または直近の実験
  ディレクトリ）のログを対象にする。

## 実行

スキル同梱の `scripts/jobwatch.sh` を使う：

```
bash <skill_dir>/scripts/jobwatch.sh [job-id|dir]
```

ジョブ状態の表と、ログから抽出した異常行（`ERROR|WARNING|Abort|NaN|Segmentation`）を
受け取り、次の観点で要約する：

- **今どうなっているか**（待機/実行中/終了/qstat に無い＝終了済み）。
- **失敗していれば、どの段か**（下記のログ対応で特定）と、ログの該当行を引用。
- **次の一手**（再実行すべき段、修正候補、`run.conf`/`params.f90` の確認点など）。

## Gotchas

- **PBS 状態記号**: `Q`=待機, `R`=実行中, `H`=保留, `E`=終了処理中, `C`=完了。
- **終了したジョブは `qstat` から消える**。さらに **`C`（完了）でも中身は失敗している
  ことがある** → 状態だけで判断せず、必ずログを grep で確認する。履歴は `qstat -x`。
- **ログ名と Fortran 段の対応**（失敗段の切り分けに必須）:
  - `s.log` = save_temp（温度・座標変換）
  - `o.log` = just_output（整形・変数抽出）
  - `l.log` = ledcalc（混合長 Ls・相似パラメータ）
  - `n.log` = nondim（無次元化）
  パイプラインは直列なので、最初に異常が出た段以降は実行されていない／無効な可能性。
- **継続監視**したい場合は、`/loop 5m /jobwatch <id>` で定期実行できる旨を案内する。
- `qstat` が無い環境（ログだけ確認したいとき）でも、ログ走査だけは動くようにする。
