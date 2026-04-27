# 雑学ニキ automation

雑学ニキ用のアップロードログ、予約投稿ログ、検証ログを置く。
知恵ネキの automation とは混ぜない。

## API automation policy

04:00 ジョブは、まず当日分の YAML stock を YouTube Data API で Private upload して `publishAt` を設定する。その後、次に在庫が不足する投稿日を先読みして、該当レベルの5カテゴリ分を追加制作する。
アップロード成功レスポンスの `id` は `video_id` として YAML に保存し、コメントジョブはこの `video_id` を使う。

## 6 automation jobs

1. `scripts/zatsugaku_api_automation.sh plan-0400`
   - 動画作成前の情報収集として、公開RSS/Atomをスクレイピングして `research/daily/<今日>.md` と `.json` を作成
   - 04時台だけ、今日の曜日/月末ルールからレベルを決定して5カテゴリから1本ずつ stock を選択
   - 選択した YAML を `status: scheduled` に更新し、Private upload + `publishAt` 設定を行う
   - 返ってきた `video_id` を YAML に保存
   - `next-missing-set` で、今日以降の投稿日をシミュレーションし、次に不足する日付・レベルを判定
   - 判定されたレベルで5カテゴリ分の新規動画 / metadata / stock YAML を追加制作

2. `scripts/zatsugaku_api_automation.sh comment-0735`
   - 07:35 に `comment_after_at` が来た動画へ YouTube API でコメント追加

3. `scripts/zatsugaku_api_automation.sh comment-1205`
   - 12:05 に `comment_after_at` が来た動画へ YouTube API でコメント追加

4. `scripts/zatsugaku_api_automation.sh comment-1805`
   - 18:05 に `comment_after_at` が来た動画へ YouTube API でコメント追加

5. `scripts/zatsugaku_api_automation.sh comment-2105`
   - 21:05 に `comment_after_at` が来た動画へ YouTube API でコメント追加

6. `scripts/zatsugaku_api_automation.sh comment-2335`
   - 23:35 に `comment_after_at` が来た動画へ YouTube API でコメント追加

`scripts/zatsugaku_api_automation.sh run` は後方互換用のまとめ実行として残す。

## Daily slots

| category_key | category | publishAt | comment after |
| --- | --- | --- | --- |
| animal | 動物 | 07:30 | 07:35 |
| food_drink | 食べ物・飲み物 | 12:00 | 12:05 |
| body_health | 人体・健康 | 18:00 | 18:05 |
| science_tech | 科学・テクノロジー | 21:00 | 21:05 |
| scary_danger | 怖い・危険 | 23:30 | 23:35 |

## Stock render layout

stock 用のレンダー済み動画と確認素材は、次の単位でまとめる。

```text
renders/stock/<level>/<category_key>/<id>/
```

この中に `*_bgm050.mp4`、`*_raw.mp4`、`contact.png`、確認用フレーム、`times.txt` を置く。
`metadata/stock/**/stock.yaml` の `video_path` / `contact_sheet_path` は、このフォルダ内の絶対パスにする。

生成素材は同じ粒度で `assets/generated/stock/<level>/<category_key>/<id>/` に置く。
古い実験素材、未使用MP4、手動アップロードログ、一時ファイルは残さない。

## 04:00 stock replenishment rule

4時ジョブは「明日分を固定で作る」のではなく、今日以降の投稿日を順番に見て、次に不足する5本セットを追加する。

1. 今日以降の日付を順番に見る。
2. 曜日/月末ルールから、その日の投稿レベルを決める。
3. その日が既に5カテゴリすべて予約済みなら、その日は充足扱い。
4. 未予約なら、同じレベルの stock が5カテゴリ分あるかをシミュレーション上で消費して確認する。
5. どこかのカテゴリが足りない最初の日付が、4時ジョブで新規制作する対象。

例: 月曜時点で火曜用の `Lv2` stock が5カテゴリ分ある場合、火曜は充足扱いになる。次の不足日が水曜なら、水曜のレベルである `Lv1` を5カテゴリ分追加制作する。

## YouTube API env

Codex automation の実行環境に以下を設定する。

```bash
YOUTUBE_CLIENT_ID=...
YOUTUBE_CLIENT_SECRET=...
YOUTUBE_REFRESH_TOKEN=...
```

ローカルの Codex automation では、次の git 管理外ファイルが存在すれば `scripts/zatsugaku_api_automation.sh` が自動で読み込む。

```text
/Users/yota/.codex/secrets/youtube_zatsugaku_api.env
```

このファイルに実値を保存し、リポジトリには絶対にコミットしない。

OAuth scope:

- `https://www.googleapis.com/auth/youtube.upload`
- `https://www.googleapis.com/auth/youtube.force-ssl`

## Safe local checks

```bash
scripts/zatsugaku_api_automation.sh dry-run
scripts/zatsugaku_api_automation.sh run
scripts/zatsugaku_api_automation.sh plan-0400
scripts/zatsugaku_api_automation.sh comment-0735
ruby scripts/zatsugaku_inventory.rb validate
```
