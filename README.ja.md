[日本語](README.ja.md) | [English](README.md)

# statusline.sh

Claude Codeのステータスライン表示シェルスクリプト

## 概要

このスクリプトは、Claude Codeのステータスラインにモデル名、トークン使用量、5時間使用率、リセット時刻を読みやすい形式で表示します。

## 必要環境

- `jq` コマンドがインストールされていること
- Claude Codeの認証情報が `~/.claude/.credentials.json` に保存されていること

## インストール

スクリプトをダウンロード

```bash
curl -o ~/.claude/statusline.sh https://raw.githubusercontent.com/masanorih/statusline.sh/refs/heads/main/statusline.sh
chmod +x ~/.claude/statusline.sh
```

## セットアップ

Claude Code設定ファイル（`~/.claude/settings.json`）のstatuslineを編集してください。

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

## 機能

- 現在のモデル名を表示
- 累積トークン数を表示（1000以上は「k」単位で表示）
- 5時間使用率をパーセンテージで表示
- 次のリセット時刻を表示
- APIからの使用データをキャッシュして不要なAPI呼び出しを削減

## 使い方

Claude Codeを起動すると、ステータスラインに以下のような情報が表示されます。

```
Model: Sonnet 4.5 | Total Tokens: 0 | 5h Usage: 0.00% | 5h Resets: 24:00
```

## 出力フィールド

| フィールド | 説明 |
|-------|-------------|
| Model | 現在のモデル名 |
| Total Tokens | 累積トークン数（入力 + 出力） |
| 5h Usage | 5時間使用率（パーセンテージ） |
| 5h Resets | 次のリセット時刻（HH:MM形式） |

## キャッシュ

使用データは `~/.claude/.usage_cache.json` にキャッシュされます。キャッシュはリセット時刻まで有効で、キャッシュの有効期限が切れると、スクリプトは自動的にAPIから最新のデータを取得します。

## サポートプラットフォーム

- Linux（GNU date）
- macOS（BSD date）

このスクリプトは両プラットフォームのdateコマンドに対応するように設計されています。
