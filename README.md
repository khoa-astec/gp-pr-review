# gp-pr-review

Laravel（PHP 8）+ React のプルリクエストを、**本番で実際に障害になる観点** でレビューする Claude Code スキルです。
スタイルの指摘ではなく、「この行で、ユーザーに何が起きるか」を行番号付きで返します。構文チェック付き。
GitHub への投稿はユーザーの承認後のみです。

A Claude Code skill that reviews pull requests in Laravel + React code for bugs that reach production,
with syntax checks. It posts to GitHub only after you approve.

## インストール / Install
```
/plugin marketplace add khoa-astec/gp-pr-review
/plugin install gp-pr-review@gp-pr-review
```

## 使い方 / Usage
```
/pr-review 1234
「このPRをレビューして https://github.com/<org>/<repo>/pull/1234」
```
構文チェックだけ使う場合:
```
bash scripts/check_syntax.sh app/Foo.php resources/js/Bar.jsx
```
（PHP はローカルの php、無ければ Docker の php イメージ。JS/TS は node_modules 内の esbuild を使用）

## 観点 / Checklist
1. 処理の成功前にフラグや行を保存し、失敗を `try/catch` でログだけ出して握りつぶしていないか（データと実体の食い違い）
2. 戻り値の無視（`Storage::put()` の false、`{success:false}` を返すAPIラッパー など）
3. `config/` 以外での `env()`（本番で `config:cache` すると null になる）
4. 並び順・競合（クライアント時刻とサーバー時刻、未検証の値で作るキャッシュキー）
5. N+1、インデックス不足、長すぎるトランザクション
6. 「軽量版」としてコピーしたコンポーネントで、元にあったガード（権限・契約チェック等）が抜けていないか
7. React の hooks（早期 return 後の hooks、依存配列、選択切替時の state リセット）
8. ローリングデプロイ中に別タスクをまたぐ処理

## 実績 / Results（2026-10、マージ済みの実PR）
トークのメッセージ順序を直すPR（8ファイル）を後追いでレビュー:

| 項目 | 結果 |
|---|---|
| 既存レビュー指摘の確認 | 2件中1件は対応済みと確認。もう1件は **修正漏れが2箇所** 残っていることを発見（写真削除後にスクロール位置が飛ぶ可能性） |
| 新規の指摘 | 使われなくなった検索条件（別メッセージに写真が紐付く可能性のある分岐）1件、テスト追加の提案 1件 |
| 構文チェック | PHP 4ファイル・JS 4ファイルすべて OK |
| 所要時間 | 約4分 |

同じ手順の構文チェックで、当日の修正2件（PHP・JSX）も事前に確認済み。
