---
name: codex
description: Codex (MCP) になんでも依頼するための汎用スキル。引数で渡された自然言語の指示を Codex にそのまま実行させる。コード生成・調査・質問応答・リファクタ提案など、用途を限定しない汎用窓口。
user-invocable: true
allowed-tools:
  - mcp__codex__codex
  - mcp__codex__codex-reply
  - Read
  - Bash(pwd)
  - Bash(ls *)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(git branch:*)
  - Bash(wc *)
---

# /codex — Codex への汎用依頼

MCP 経由で接続されている Codex (`mcp__codex__codex`) を呼び出し、
ユーザーの指示を**そのまま**実行させるための汎用スキル。
レビュー専用の [/codex-review](../codex-review/SKILL.md) と違い、
用途を限定しない。コード生成・調査・解説・リファクタ提案など何でも投げる。

Arguments passed: `$ARGUMENTS`

---

## 引数の扱い

`$ARGUMENTS` をユーザーからの Codex へのプロンプトとして扱う。

- **引数なし**: 「Codex に何を依頼しますか？ 例: `/codex このファイルをリファクタして` 」
  と返して終了。勝手にプロンプトを作らない。
- **引数あり**: それを Codex へのメインプロンプトとして使う。
  ファイルパスやディレクトリが含まれていれば、Codex 側で `cwd` 基準で
  読めるのでそのまま渡してよい。

---

## Codex 呼び出し

`mcp__codex__codex` を以下の設定で呼ぶ：

- **`cwd`**: 現在の作業ディレクトリ (絶対パス)
- **`sandbox`**: **必ず `"danger-full-access"`** を指定する。
  このサーバ (CentOS 7 / kernel 3.10) では Landlock も bubblewrap も
  利用できず、`read-only` / `workspace-write` を指定すると sandbox 初期化に
  失敗して Codex 呼び出しがエラーで落ちる。よって `read-only` を既定にする
  運用は採れない。安全側の制御は **このスキル内で** 行う：
    - 読み取り依頼 (調査・解説・質問応答など) でも `danger-full-access` で渡す。
      Codex に「ファイルへの書き込み・実行は不要、読み取りと回答のみ行うこと」と
      プロンプトで明示する。
    - 変更依頼 (編集・リファクタ・生成) は通常通り依頼してよい。
    - `rm`・外部送信・パッケージインストール等の破壊的/副作用の大きい依頼は
      従来通り**事前にユーザーへ確認**してから投げる (sandbox に頼れないので
      この確認が唯一の歯止め)。
- **`approval-policy`**: `"never"` (非対話で完結させる)
- **`model`**: 指定しない (MCP 側のデフォルトに任せる)
- **`config`**: `{"model_reasoning_effort": "high"}` を指定する。
- **`prompt`**: 下記テンプレート

### プロンプトテンプレート

```
以下はユーザーからの依頼です。指示に従って作業 / 回答してください。
作業ディレクトリ: <cwd>

# 依頼内容
<$ARGUMENTS をそのまま埋め込む>

# 出力方針
- 前置きや自己紹介は不要。要求された成果物 / 回答そのものを返す。
- コード変更を伴う場合は、変更したファイルと差分の要約を最後に列挙する。
- 不明点があり推測で進めるとリスクが高いときは、推測せず質問を返す。
```

---

## 結果の扱い

1. Codex の出力を**そのまま**ユーザーに見せる。要約や言い換えで上書きしない。
2. Codex が `threadId` を返してきたら、
   「`mcp__codex__codex-reply` で続きの会話が可能です (threadId: `<id>`)」
   と一言添える。
3. Codex 呼び出しが失敗 (MCP 未接続など) したら、エラー内容と
   `claude mcp list` で接続状態を確認するよう案内する。

---

## 実装メモ

- **二重作業を避ける**: Codex に投げたら自分で同じ作業を並行してやらない。
  Codex の応答を尊重する。ユーザーが「Claude 側でもやって」と明示したときだけ
  自前で動く。
- **sandbox は常に `danger-full-access`**: このサーバでは他の sandbox モードが
  使えないため選択肢がない。代わりに、プロンプトで Codex に意図 (読み取りのみ /
  編集可) を明示し、破壊的操作はユーザー確認を経るルールで安全性を担保する。
- **Codex 呼び出しが失敗したら自分で代行しない**: sandbox エラー・MCP 切断
  などで Codex が動かなかった場合は、エラー内容を報告して止める。ユーザーが
  「Claude 側でやって」と明言したときだけ自前で動く。
- **機微情報**: ユーザーが明示しない限り、`.env` や鍵ファイルを Codex に
  読ませない。
- **レビュー依頼が来たら**: 「コードレビュー」「review」が主目的の依頼は
  [/codex-review](../codex-review/SKILL.md) を勧める (専用テンプレートがある)。
