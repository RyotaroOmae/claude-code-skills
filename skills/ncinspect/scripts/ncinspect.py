#!/usr/bin/env python3
"""NetCDF ファイルの構造と基本統計を素早く要約表示する。

使い方:
    python3 ncinspect.py <file.nc> [--stats-max-elems N]

巨大変数で固まらないよう、要素数がしきい値を超える数値変数は
間引きスライスで統計を取り、さらに極端に大きいものは統計をスキップする。
"""
import argparse
import math
import sys

try:
    import numpy as np
    from netCDF4 import Dataset
except ImportError as e:
    sys.stderr.write(
        f"[ncinspect] 必要なライブラリが import できません: {e}\n"
        "  -> `ncdump -h <file>` でヘッダだけ確認するフォールバックを検討してください。\n"
    )
    sys.exit(2)

# このしきい値までは（必要なら間引いて）統計を計算する。超える変数は統計をスキップ。
DEFAULT_STATS_MAX = 50_000_000  # 要素数
SAMPLE_TARGET = 2_000_000        # 統計用にサンプリングする目標要素数


def human_shape(dims, shape):
    return ", ".join(f"{d}={n}" for d, n in zip(dims, shape))


def fmt_attr(val):
    s = str(val)
    return s if len(s) <= 80 else s[:77] + "..."


def _sample_slices(shape, target):
    """全次元に stride を配分し、サンプル要素数を target 以下に抑える slice タプルを返す。

    大きい次元から順に間引く。実際にサンプリングする要素数が target を下回るまで
    stride を増やすことで、先頭次元が小さい (2, 5000, 5000) のような変数でも
    巨大スラブを読み込まないようにする。
    """
    def sampled_count():
        c = 1
        for a, m in enumerate(shape):
            c *= len(range(*slices[a].indices(m)))
        return c

    slices = [slice(None)] * len(shape)
    sampled = int(np.prod(shape)) if shape else 1
    # 大きい次元優先で間引く
    for axis, n in sorted(enumerate(shape), key=lambda x: x[1], reverse=True):
        if sampled <= target:
            break
        stride = min(n, max(1, math.ceil(sampled / target)))
        slices[axis] = slice(None, None, stride)
        sampled = sampled_count()  # サンプル後の総要素数を正確に再計算
    return tuple(slices), sampled


def stats_for(var, stats_max):
    """数値変数の (min, max, mean, nan数, note) を返す。非数値や巨大はスキップ。"""
    dt = var.dtype
    if not np.issubdtype(dt, np.number):
        return None
    total = int(np.prod(var.shape)) if var.shape else 1
    if total == 0:
        return None
    note = ""
    try:
        if total > stats_max:
            return (None, None, None, None, f"統計スキップ (要素数 {total:,} > {stats_max:,})")
        if var.shape == ():
            # 0 次元 scalar 変数
            data = var[()]
        elif total > SAMPLE_TARGET:
            slices, sampled = _sample_slices(var.shape, SAMPLE_TARGET)
            data = var[slices]
            note = f"(全次元間引きで約 {sampled:,} 要素をサンプル)"
        else:
            data = var[...]
        # masked array なら欠損 (_FillValue/missing_value) を NaN に変換してから集計
        marr = np.ma.asarray(data).astype("float64")
        arr = marr.filled(np.nan)
        nan_count = int(np.isnan(arr).sum())
        valid = arr[~np.isnan(arr)]
        if valid.size == 0:
            return (None, None, None, nan_count, "全て NaN/欠損")
        return (float(valid.min()), float(valid.max()), float(valid.mean()), nan_count, note)
    except Exception as exc:  # noqa: BLE001
        return (None, None, None, None, f"統計取得失敗: {exc}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--stats-max-elems", type=int, default=DEFAULT_STATS_MAX)
    args = ap.parse_args()

    try:
        ds = Dataset(args.file, "r")
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write(f"[ncinspect] ファイルを開けません: {exc}\n")
        sys.exit(1)

    print(f"=== {args.file} ===")
    fmt = getattr(ds, "data_model", "?")
    print(f"format: {fmt}")

    # 次元
    print("\n[Dimensions]")
    for name, dim in ds.dimensions.items():
        unl = " (unlimited)" if dim.isunlimited() else ""
        print(f"  {name} = {len(dim)}{unl}")

    # global attributes
    gattrs = ds.ncattrs()
    if gattrs:
        print("\n[Global attributes]")
        for a in gattrs:
            print(f"  {a}: {fmt_attr(getattr(ds, a))}")

    # 変数
    print("\n[Variables]")
    for name, var in ds.variables.items():
        units = getattr(var, "units", "") if "units" in var.ncattrs() else ""
        longn = getattr(var, "long_name", "") if "long_name" in var.ncattrs() else ""
        shape_s = human_shape(var.dimensions, var.shape) or "scalar"
        head = f"  {name} [{var.dtype}] ({shape_s})"
        meta = []
        if units:
            meta.append(f"units={units}")
        if longn:
            meta.append(f"'{longn}'")
        if meta:
            head += "  " + " ".join(meta)
        print(head)

        st = stats_for(var, args.stats_max_elems)
        if st is not None:
            vmin, vmax, vmean, nan_count, note = st
            if vmin is not None:
                line = f"      min={vmin:.4g} max={vmax:.4g} mean={vmean:.4g} nan={nan_count}"
            else:
                line = "      " + (note or "(統計なし)")
                note = ""
            if note:
                line += f"  {note}"
            print(line)

    ds.close()


if __name__ == "__main__":
    main()
