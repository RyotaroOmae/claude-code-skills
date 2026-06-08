---
name: claude-docs
description: Claude Code の設定・機能を公式ドキュメントで確認するためのスキル。settings.json / environment variables / .claude directory / CLAUDE.md / hooks / MCP / permissions / slash commands / subagents / plugins / skills を編集する前や「この設定キー/機能は存在するか」を答える前に、公式ドキュメントを取得して裏取りし、架空の設定ブロックや存在しないキーをでっち上げないようにする。
user-invocable: true
argument-hint: "[調べたい設定キー・機能名・トピック, optional]"
allowed-tools:
  - WebFetch
  - WebSearch
  - Read
  - Glob
---

# claude-docs — Claude Code 設定/機能の公式裏取り

settings.json などを編集する前、または「この設定/機能は存在するか」を答える前に、
**記憶や推測ではなく公式ドキュメントを実際に取得して確認する**ためのスキル。

目的は、過去にあった「実在しない設定キーや架空の JSON ブロックを追加してしまう」
ミスを防ぐこと。**ドキュメントで現物を確認できないキー・構造・機能は書かない / 断定しない。**

Arguments passed: `$ARGUMENTS`（調べたい設定キーや機能名があれば優先トピックにする）

---

## 一次情報源（実在を確認済み）

| 用途 | URL |
|---|---|
| **全ページ索引（必ずここから）** | `https://code.claude.com/docs/llms.txt` |
| 各ページの整形済み本文 | 索引の `...page.md` をそのまま取得 |

主要ページ（**検索ヒント**であり最終根拠ではない。最終根拠は常に索引に掲載された実URL）:

- 設定全般: `https://code.claude.com/docs/en/settings.md`
- 環境変数: `https://code.claude.com/docs/en/env-vars.md`
- hooks リファレンス: `https://code.claude.com/docs/en/hooks.md`
- MCP: `https://code.claude.com/docs/en/mcp.md`
- permissions: `https://code.claude.com/docs/en/permissions.md`
- subagents: `https://code.claude.com/docs/en/sub-agents.md`
- plugins: `https://code.claude.com/docs/en/plugins.md`
- skills: `https://code.claude.com/docs/en/skills.md`
- `.claude` ディレクトリ: `https://code.claude.com/docs/en/claude-directory.md`

> ⚠️ **URL を推測しない。** 上表は記憶補助に過ぎない。**初回は必ず `llms.txt` を取得して
> 該当ページの実URLを確認する**（上表のURLが古くなっている可能性があるため）。
> `.md` を付けると本文だけが取れる。

---

## 手順

1. **索引を取る。** `llms.txt` を WebFetch し、調べたいトピックに対応する実在ページURLを特定する。
   上表のURLを覚えていても、初回はこの索引で実URLを必ず裏取りする。
2. **該当ページの `.md` を取得**し、設定キー名・JSON 構造・取りうる値・デフォルト・スコープを抜き出す。
   **このページが唯一の公式根拠**。以降の提示・断定はここで見えた範囲に限る。
3. **手元の現物を確認する（現状把握のみ）。** 編集対象の `settings.json` / `.mcp.json` 等を Read する。
   ただし**既存ファイルにあるキーは公式根拠にはならない**（過去の誤生成・非推奨・環境依存・ユーザー独自の可能性があるため）。
   現物は「いま何があるか」を知る材料に留め、正否の判断は必ずドキュメント側で行う。
4. ドキュメントだけで判断できないときは `WebSearch`（`allowed_domains: ["code.claude.com","docs.claude.com"]`）で補う。

---

## 設定タイプ別・最低限集める情報

編集や回答の前に、以下が**ドキュメント上で確認できているか**をチェックする。
1つでも欠けていたら、そのまま書かずに確認・調査する。

- **settings.json のキー追加**: 正確なキー名 / 値の型 / 取りうる値 / 置き場所（user/project/local のスコープ）
- **hooks**: イベント名が実在するか（例: `PreToolUse` 等） / `hooks`→イベント→`matcher`→`hooks`→`type` の入れ子構造 / `type` の許容値
- **MCP サーバ**: 定義ファイル/キー / transport 種別（stdio・sse・http など）/ 必須フィールド
- **permissions**: `allow`/`deny`/`ask` のどれか / ルール文字列の正確な書式（例: `Bash(npm test:*)`）
- **slash commands / subagents / skills / plugins**: 配置ディレクトリ / frontmatter の必須フィールド / ファイル命名規則

---

## 出力と禁止事項

- 設定ブロックを提示するときは、**根拠にした公式ページURLを併記**する。
- ドキュメントで確認できなかったキー・構造は提示しない。どうしても言及するなら
  「**ドキュメント未確認**」と明記し、推測である旨を区別して伝える。
- 「たぶんこういうキーがあるはず」で JSON を組み立てない。実在確認が先。
- **既存ファイルにしか無いキー**を根拠に追加・複製・断定しない。ドキュメントで裏が取れなければ
  「ドキュメント未確認」として扱い、ユーザーに判断を委ねる。
- **ドキュメントと現物が矛盾する場合は停止する。** 差分をユーザーに報告し、公式に確認できた範囲だけを変更する。
  ドキュメントで確認できない構造を新規に作らない。
- ドキュメント取得に失敗したら、その旨と未確認リスクを報告し、勝手に記憶で補完しない。

---

## 関連スキルへの委譲

- **設定ファイルを実際に編集する手順** → `update-config`（本スキルで裏取り → update-config で適用、の順）
- **API / SDK / モデルID / 料金など API 寄りの質問** → `claude-api`
- 本スキルは「Claude Code の設定・機能の**情報収集と裏取り**」に専念する。

---

## 軽微な確認の例外（過剰調査の禁止）

**同セッションで該当の公式ページを既に取得済み**なら、再取得せずそれを根拠にしてよい。
これが唯一の例外。手元の `settings.json` に実例があっても、それは公式根拠の代わりにはならない
（過去の誤生成かもしれない）。迷う基準は「**そのキー/構造を公式ドキュメントで見たか**」。
見ていない・うろ覚えなら必ず取得する。
