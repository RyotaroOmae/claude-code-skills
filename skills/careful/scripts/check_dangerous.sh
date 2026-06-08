#!/usr/bin/env bash
# 与えられたコマンド文字列の破壊度を分類して1行で返す。
#   DANGER: 不可逆・高リスク（必ず確認）
#   WARN:   状況次第でリスク（一言添えて確認）
#   OK:     特に危険なパターンは検出されず
#
# 使い方:  bash check_dangerous.sh '<command string>'
# 注意: コマンドは実行しない。文字列のパターンマッチのみ。

set -u

cmd="${*:-}"
if [ -z "$cmd" ]; then
  echo "OK: (空のコマンド)"
  exit 0
fi

# --- DANGER パターン -------------------------------------------------
danger_patterns=(
  'rm[[:space:]]+(-[a-zA-Z]*[rf][a-zA-Z]*|--recursive|--force)' # rm -r/-f/分割/long option
  'rm[[:space:]]+.*[*?]'                                          # rm + ワイルドカード
  'git[[:space:]]+push[[:space:]].*--force'                       # force push
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]].*(-[a-zA-Z]*f|--force)'        # clean -f / -d -f / --force
  'git[[:space:]]+branch[[:space:]]+-D'
  'git[[:space:]]+checkout([[:space:]]+--)?[[:space:]]+\.'        # checkout . / checkout -- .
  'git[[:space:]]+checkout[[:space:]].*-f'                        # checkout -f
  'git[[:space:]]+restore([[:space:]]+--staged)?[[:space:]]+\.'   # restore . / restore --staged .
  '\bDROP[[:space:]]+(TABLE|DATABASE)\b'
  '\bTRUNCATE\b'
  '\bmkfs\b'
  '\bdd[[:space:]]+.*of=/dev/'
  '>[[:space:]]*/dev/sd'
  ':\(\)\{.*:\|:&\};:'                                            # fork bomb
)

# --- WARN パターン ---------------------------------------------------
warn_patterns=(
  '\brm[[:space:]]'                       # 上記以外の rm
  '\bmv[[:space:]].*[*?]'                 # mv + ワイルドカード
  'chmod[[:space:]]+-R'
  'chown[[:space:]]+-R'
  '\btruncate\b'
  '[^>]>[[:space:]]*[^>&|]'               # 単一 > リダイレクト（上書きの可能性）
  '\bcp[[:space:]].*'                     # cp（上書きの可能性）
  'git[[:space:]]+push\b'                 # 通常 push（外部反映）
  '\bDELETE[[:space:]]+FROM\b'
  '\b(pjsub|qsub|sbatch)\b'              # ジョブ投入（計算資源消費）
)

for p in "${danger_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$p"; then
    echo "DANGER: 不可逆・高リスクの可能性。実行前に必ず確認してください。 [matched: $p]"
    exit 0
  fi
done

for p in "${warn_patterns[@]}"; do
  if echo "$cmd" | grep -Eiq "$p"; then
    echo "WARN: 状況次第でリスクあり（上書き/外部反映/資源消費など）。一言添えて確認を。 [matched: $p]"
    exit 0
  fi
done

echo "OK: 既知の破壊的パターンは検出されませんでした。"
