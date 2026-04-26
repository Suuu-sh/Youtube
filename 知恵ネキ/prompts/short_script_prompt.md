# Short Script Prompt

以下を LLM に渡して、45〜60秒の YouTube Shorts 台本を作る。

## 入力

- タイトル:
- フック:
- 視聴者の悩み:
- 実演内容:
- 結果:
- CTA:

## 生成ルール

- 日本語
- 45〜60秒
- 1本1テーマ
- 冒頭2秒で価値を言う
- 説明ではなく**見せる前提**で書く
- 余計な前置き禁止
- 誇大表現禁止
- 画面録画のカット指示を入れる
- 読み上げやすい短文にする

## 出力形式

### 1. spoken_script

ナレーション全文

### 2. shot_list

以下の形式で 5〜7 カット

- cut_01:
  - duration:
  - visual:
  - caption:
- cut_02:
  - duration:
  - visual:
  - caption:

### 3. title_candidates

5案

### 4. description

1案

### 5. hashtags

5〜8個

## 追加指示

- オリジナルの画面録画前提で構成する
- 他人コンテンツの引用前提にしない
- YouTube Shorts に合うテンポにする
