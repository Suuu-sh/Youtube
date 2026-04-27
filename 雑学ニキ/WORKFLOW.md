# 雑学ニキ 制作・投稿手順

## 目的

雑学解説系の Shorts / 動画を、知恵ネキとは別の素材・手順・検証基準で制作する。

## 材料の置き場所

- 企画: `ideas/`
- リサーチメモ・出典メモ: `ideas/` または `metadata/`
- 画像・音声・manifest: `assets/generated/stock/<level>/<category_key>/<id>/`
- メタデータ: `metadata/stock/<level>/<category_key>/<id>/metadata.md`
- 動画: `renders/stock/<level>/<category_key>/<id>/`
- 投稿・予約・検証ログ: `automation/`
- ブランド素材: `branding/`

## 動画作成の基本手順

1. テーマを選ぶ。
2. 出典確認・事実確認を行う。
3. 台本を作る。
4. 雑学ニキ用のトーン、画作り、音声で素材を作る。
5. 雑学ニキ用のレンダースクリプトで動画を書き出す。
6. 誤情報、出典、字幕、権利、AI生成開示の必要性を確認する。
7. 雑学ニキ用の投稿手順で private アップロードする。
8. 問題なければ公開または予約公開する。

## 投稿方針

- 知恵ネキ用の素材・BGM・ログを混ぜない。
- 出典が必要な内容は、メタデータまたは制作メモに残す。
- 投稿手順が固まったら、このファイルへ具体的なコマンドや確認項目を追記する。


## Lv運用ルール

- 雑学は `Lv1`〜`Lv5` で管理する。
- 基本運用は `Lv1` と `Lv2` を中心にする。
- `Lv3` と `Lv4` はたまに出すアクセント枠にする。
- `Lv5` はごく稀に出す特別枠にして、博士レベル感を残す。
- 大カテゴリはまず `動物`、`食べ物・飲み物`、`人体・健康`、`科学・テクノロジー`、`怖い・危険` の5種類を主軸にする。
- 動画の最後には `いくつわかりましたか？` カードを入れて、コメントしやすくする。

目安:

- Lv1: 知って損しない、日常で刺さる、広く分かる。
- Lv2: 知ってたらちょっとすごい、会話に使いやすい。
- Lv3: 知ってたら普通にすごい、理由や仕組みが少し深い。
- Lv4: 知ってたらかなりすごい、数字・研究・専門性が強い。
- Lv5: 知ってたら博士レベル、希少性と意外性が高い。

## Private upload・コメント運用

- 動画作成が完了したら、原則として毎回 YouTube へ Private upload する。
- ログインは Automation プロファイル（`automationai1223@gmail.com`）を使う。
- ユーザーから明示がない限り、Public化や予約公開はしない。
- 投稿ごとにコメント案を作り、メタデータと完了報告に含める。
- コメント案は短い誘導だけにせず、各雑学の補足を番号付きで書く。

## BGMルール

- 動画作成時は、原則として `Escort / もっぴーさうんど（DOVA-SYNDROME）` をBGMとして薄く入れる。
- BGMファイル: `/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3`
- 標準音量はナレーション `1.0`、BGM `0.50`。声が聞き取りづらい場合はBGMを `0.35〜0.45` に下げる。
- 動画説明欄に `BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）` を入れる。
- レンダー後、BGMが声を邪魔していないか必ず確認する。

## 現在の自動投稿ワークフロー

### 基本方針

4時 automation は在庫補充用の動画制作まで行う。手動制作は単発依頼時だけ行い、通常投稿は automation が stock YAML を読んで YouTube API の定型処理まで行う。

```text
4時 automation:
  リサーチ → 不足レベル判定 → MP4 / contact sheet / metadata / stock YAML を作る

API automation:
  YAMLを読む → Private upload → publishAt予約 → 固定コメント投稿
```

### 動画作成後の完了条件

自動投稿に回す動画を作ったら、完了報告前に次を満たす。

1. 最新MP4が `renders/stock/<level>/<category_key>/<id>/` にある。
2. contact sheet を作成し、視覚確認済み。
3. タイトル、説明文、固定コメント案がある。
4. `metadata/stock/<level>/<category_key>/<id>/stock.yaml` を作成済み。
5. YAMLの `status` は `stock`。
6. `topic_key` と `fact_summary` があり、過去投稿と重複しない。
7. `ruby scripts/zatsugaku_inventory.rb validate` が通る。

### category_key

| category_key | カテゴリ |
| --- | --- |
| `animal` | 動物 |
| `food_drink` | 食べ物・飲み物 |
| `body_health` | 人体・健康 |
| `science_tech` | 科学・テクノロジー |
| `scary_danger` | 怖い・危険 |

### 投稿時刻

| カテゴリ | 公開 | コメント |
| --- | --- | --- |
| 動物 | 07:30 | 07:35 |
| 食べ物・飲み物 | 12:00 | 12:05 |
| 人体・健康 | 18:00 | 18:05 |
| 科学・テクノロジー | 21:00 | 21:05 |
| 怖い・危険 | 25:00（翌日01:00） | 25:05（翌日01:05） |

### レベル運用

- 月・水・金: Lv1
- 火・木: Lv2
- 土: Lv3
- 日: Lv4
- 毎月末: Lv5（曜日より優先）

### YAML作成時の注意

- `video_path` と `contact_sheet_path` は絶対パスにする。
- `topic_key` は英数字・snake_caseで、同じ内容なら同じキーになるようにする。
- `fact_summary` は重複検知用に、動画全体の事実内容を短く書く。
- 新規stockを考える前に `metadata/stock/**/stock.yaml` の同カテゴリ `topic_key` / `fact_summary` を確認し、同じ題材・同じ食品・同じ人体部位・同じ危険/技術テーマの被りすぎを避ける。完全な再利用禁止ではないが、動物カテゴリでは既存1本あたり同じ動物種の被りを最大1体までにする。2体以上（例: 猫・犬・ナマケモノのうち2つ以上）が被る案は、ほぼ同じ投稿に見えやすいので差し替える。
- 下書き後に `ruby scripts/zatsugaku_inventory.rb overlap-report --category <category_key>` で被り候補を確認し、共有topic tokenが2個以上出る場合は原則テーマを差し替える。動物カテゴリで共有topic tokenが1個だけなら許容できる。
- `comment_text` は公開後にそのまま投稿されるため、視聴者向けの完成文にする。
- `publish_at`、`comment_after_at`、`video_id`、`last_error` は stock 登録時点では空でよい。

### 手動アップロードについて

現在の通常運用では、完成動画を手動でYouTube Studioへアップロードしない。
手動アップロードするのは、ユーザーが明示的に依頼した場合だけ。
