---
name: jobwatch
description: PBS バッチジョブの状態を qstat で確認し、実験ディレクトリのログ(s/o/l/n.log)から ERROR/WARNING/NaN を検出して要約する。SCALE 解析パイプラインのジョブが通ったか・どの段で失敗したかを素早く確認したいときに使う。富岳(PJM)のジョブスクリプトやログを scp してきて診断する「富岳ログ診断モード」も持つ。
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

---

## 富岳ログ診断モード（PJM）

富岳のジョブは gale から直接 `pjstat` できないため、**ジョブスクリプトとログを scp して
きたものを診断する** のが実際の運用。引数のディレクトリに `#PJM` を含むスクリプトや
`log.txt`, `*_LOG*`, `output.*/stderr.*` があればこのモードで見る。

### ジョブスクリプトのチェックポイント

- `#PJM -L "node=N"` × `#PJM --mpi "max-proc-per-node=M"` = 総MPIプロセス数。これが
  SCALE の conf 側 `PRC_NUM_X × PRC_NUM_Y` と一致しているか **必ず照合** する。
- `#PJM -x PJM_LLIO_GFSCACHE=/vol000X:...` — 使う vol が全部列挙されているか
  （列挙漏れの vol 上のファイルは読めず、無言で失敗することがある）。
- `#PJM -S` があれば stats/stderr が `output.<jobid>/` に分かれて出る。そこも見る。
- `mpiexec` の前に環境 setup（spack 等）が走っているか。

### SCALE 特有の落ち方（実事例ベース）

- **`*_LOG` が空のまま終了** → 実行開始前に死んでいる。MPIプロセス数と PRC_NUM の不一致、
  または入力ファイル（boundary/init）のパス・分割数不一致を疑う。
- **`SIGBUS (BUS_ADRERR)`** → Parallel NetCDF / `FILE_HISTORY_AGGREGATE` 絡みや
  メモリアライメントを疑う。AGGREGATE を切って切り分ける。
- **`MPI_ABORT ... errorcode -1`** → LOG ファイルの末尾に SCALE 自身のエラーメッセージが
  出ているはず。stderr ではなく `*_LOG_d0*` を grep する。
- **バイナリ入力の読み込み異常**（値がデタラメ等）→ GrADS 形式入力の **エンディアン**
  （big endian `>f4` で書いたか）と record 構成を確認。変換スクリプト側の問題が多い。
- **pp は通るが init が失敗** → pp 出力 (topo/landuse) は正常でも、ATM/SFC/LND の
  変換データ（grd）の格子数・レベル数・時刻の不一致がありうる。`namelist.grads` と
  実ファイルサイズ（= nx×ny×nz×4 bytes × 変数数）の整合を計算して確かめる。
