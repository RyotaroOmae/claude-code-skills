---
name: ncinspect
description: NetCDF ファイルの中身（次元・変数・属性・座標範囲・基本統計）を素早く要約表示する。SCALE-RM の history 出力や解析パイプライン出力(.nc)の中身確認に使う。解析・プロットの前に「何が入っているか」を把握したいとき。
user-invocable: true
argument-hint: "[path/to/file.nc, optional]"
allowed-tools:
  - Read
  - Glob
  - Bash(/home/omae/micromamba/envs/meteo/bin/python *)
  - Bash(micromamba run -n meteo python *)
  - Bash(python3 *)
  - Bash(ncdump *)
  - Bash(ls *)
---

# /ncinspect — NetCDF の中身を素早く確認

NetCDF ファイルの構造（次元・変数・属性・座標・基本統計）を要約して見せる。
解析やプロットに着手する前の「中身確認」を定型化するためのスキル。

Arguments passed: `$ARGUMENTS`

---

## 対象の決定

`$ARGUMENTS` をパースする。

- **ファイルパスあり**: それを対象にする。
- **引数なし**: cwd 配下の `*.nc` を Glob で探し、候補を一覧提示してどれを見るか尋ねる。
  候補が1つだけならそのまま対象にする。

## 実行

スキル同梱の `scripts/ncinspect.py` を対象ファイルに対して実行する。
**numpy / netCDF4 が入った micromamba 環境 `meteo` の Python を使うこと**
（デフォルトの `python3` には numpy が無い）：

```
/home/omae/micromamba/envs/meteo/bin/python <skill_dir>/scripts/ncinspect.py <file.nc>
```

（`micromamba run -n meteo python ...` でも可）

出力（次元・変数の shape/dtype/units/long_name・global attrs・数値変数の min/max/mean/NaN数）
を整形してユーザーに見せる。`ncdump -h <file>` が使える環境なら、ヘッダだけ素早く見たいときの
代替として併用してよい。

## 結果の扱い

- 単に羅列するのではなく、**そのファイルが何のデータか**（history か解析出力か、
  どの段の出力か、主要変数は何か）を一言で要約してから詳細を示す。
- ユーザーが次にやりたいこと（特定変数のプロット等）があれば、その変数名・次元を
  根拠として示す。

---

## Gotchas（落とし穴・前提知識）

- **SCALE history は MPI ランク分割される**：`history.pe000000.nc` のようにタイルごとに
  分かれている。まず1ファイルで構造を確認し、全領域が必要なら結合が前提だと伝える
  （`pe000000` 以外も `ls` で存在を確認する）。
- **巨大変数を全読みしない**：4次元(time,z,y,x)変数は巨大になりうる。ヘルパーは
  しきい値超の変数を間引き/スライスで統計し、超大は統計をスキップする。固まらせない。
- **時刻は CF units**：`time` は `seconds since YYYY-MM-DD ...` のような単位付き。
  生の数値だけでなく単位込みで解釈する。
- **解析パイプライン出力の素性**：
  - `TemSave_output.nc`（save_temp 段：温度・座標変換）
  - `output.nc`（just_output 段：整形・変数抽出）
  - `LS_output.nc`（ledcalc 段：混合長 Ls・相似パラメータ）
  - `NonDim_output.nc`（nondim 段：無次元化、ζ=z/L_M）
  典型変数: `PT`(温位), `TKE_MYNN`, `Q2`, `u`/`v`/`w`, 各種フラックス。
- `netCDF4` が import できない環境なら、`ncdump -h` にフォールバックして
  最低限ヘッダだけ見せ、Python 環境の用意を促す。
