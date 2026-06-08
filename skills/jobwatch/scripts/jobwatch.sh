#!/usr/bin/env bash
# PBS ジョブ状態と SCALE 解析ログの異常を要約する。
#
# 使い方:
#   bash jobwatch.sh            # 自分の全ジョブ + cwd のログ
#   bash jobwatch.sh <job-id>   # 指定ジョブ + cwd のログ
#   bash jobwatch.sh <dir>      # 指定ディレクトリのログ（+ 自分の全ジョブ）
#
# 破壊的操作は一切しない（参照のみ）。

set -u

ARG="${1:-}"
TARGET_DIR="."
JOB_ID=""

if [ -n "$ARG" ]; then
  if [ -d "$ARG" ]; then
    TARGET_DIR="$ARG"
  elif [[ "$ARG" == */* || "$ARG" == *.log || "$ARG" == .* ]]; then
    # パスらしいのに存在しない → typo の可能性。job-id 扱いにしない。
    echo "エラー: ディレクトリ '$ARG' が見つかりません（パスを確認してください）。" >&2
    exit 1
  else
    JOB_ID="$ARG"
  fi
fi

echo "========== PBS ジョブ状態 =========="
if command -v qstat >/dev/null 2>&1; then
  if [ -n "$JOB_ID" ]; then
    qstat "$JOB_ID" 2>/dev/null || qstat -x "$JOB_ID" 2>/dev/null \
      || echo "(job $JOB_ID は qstat に見つかりません＝終了済みの可能性。ログで確認)"
  else
    out="$(qstat -u "${USER:-$(whoami)}" 2>/dev/null)"
    if [ -n "$out" ]; then
      echo "$out"
    else
      echo "(実行待ち/実行中のジョブはありません。終了済みはログで確認)"
    fi
  fi
else
  echo "(qstat が見つかりません。ログ走査のみ実行します)"
fi

echo
echo "========== ログ異常検知 ($TARGET_DIR) =========="
# 段とログ名の対応
declare -A STAGE=( [s.log]="save_temp" [o.log]="just_output" [l.log]="ledcalc" [n.log]="nondim" )

shopt -s nullglob
found_any=0
for base in s.log o.log l.log n.log; do
  f="$TARGET_DIR/$base"
  [ -f "$f" ] || continue
  found_any=1
  stage="${STAGE[$base]}"
  hits="$(grep -Eni 'ERROR|WARNING|Abort|NaN|Segmentation|Fatal|FAILED' "$f" 2>/dev/null | head -n 20)"
  last="$(tail -n 2 "$f" 2>/dev/null)"
  if [ -n "$hits" ]; then
    echo "--- $base [$stage]  ⚠ 異常あり ---"
    echo "$hits"
  else
    echo "--- $base [$stage]  OK（末尾2行）---"
    echo "$last"
  fi
  echo
done

# その他の *.log も軽く拾う
for f in "$TARGET_DIR"/*.log; do
  b="$(basename "$f")"
  case "$b" in s.log|o.log|l.log|n.log) continue;; esac
  found_any=1
  hits="$(grep -Eni 'ERROR|WARNING|Abort|NaN|Segmentation|Fatal|FAILED' "$f" 2>/dev/null | head -n 10)"
  if [ -n "$hits" ]; then
    echo "--- $b  ⚠ 異常あり ---"
    echo "$hits"
    echo
  fi
done

if [ "$found_any" -eq 0 ]; then
  echo "(ログファイル *.log が $TARGET_DIR に見つかりません)"
fi
