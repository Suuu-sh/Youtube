#!/usr/bin/env python3
import json, pathlib, urllib.request, urllib.parse, wave, subprocess, shutil, sys
from datetime import date

ROOT=pathlib.Path('/Users/yota/Projects/Automation/Youtube/雑学ニキ')
BGM=pathlib.Path('/Users/yota/Projects/Automation/Youtube/_shared/bgm/dova-syndrome/escort_moppy_sound.mp3')
BGM_HELPER=pathlib.Path('/Users/yota/Projects/Automation/Youtube/_shared/youtube-scheduler/add_bgm_to_video.swift')
RENDER_SRC=ROOT/'assets/generated/zatsugaku_animal_trivia_001/render_animal_short.swift'
UA={'User-Agent':'Mozilla/5.0 Codex zatsugaku builder'}
PAUSE=0.90
REVEAL=0.30

def cat_slug(cat):
    return {
        '動物':'animal','食べ物・飲み物':'food_drink','人体・健康':'body_health','科学・テクノロジー':'science_tech','怖い・危険':'danger'
    }[cat]

DIRECT_ANIMAL={
 'cat':('猫のイラスト','https://www.irasutoya.com/2018/12/blog-post_505.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiJWfKU3FE26gcPLqlNyrs1yh2xPmdOuJMtCvhY-lDsiq3dAkvnkxOr2bNJc0YsYxsnGlIF0DkTDYL4OCOz4XRejNo3HI6nNTvrudWSvNAijtPc3nx41wdvsE7f6jnIAlE-rvVbLagzLZi3/s800/cat01_moyou_black.png'),
 'dog':('犬のイラスト','https://www.irasutoya.com/2018/09/blog-post_17.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjW7EycrlL65CFiwIZzt7NlycjhHna4Zb_zKhRlD3cRPl60GzLiNXqLs0kKchk_uC83rk47F_ZYNizfFYALxJnTMC4pYta1abe3IOVkYPqiyG_4PH1R7Wg-3-EhhyH83jvCJGHUszdn0Awr/s800/dog2_1_idea.png'),
 'octopus':('タコのキャラクター','https://www.irasutoya.com/2013/01/blog-post_31.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiGFEs1w_yylmYo0NvvfVAeZRNLtOr-pLH3LhOl-FOrBuDuDpH0DgVhJXar4fcOn1NOahgU3scWbcvRe9yD3q4KMZ7zhYUVN3toaVgqVQhGqQ7947pfnu4Vf2V0_Be5UDVSWcglfuScUKf1/s800/fish_tako.png'),
 'giraffe':('キリンのキャラクター','https://www.irasutoya.com/2013/03/blog-post_7121.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjS-hDnmFNZvsCdTUl0pO3JoBPG7KfPD1PhPphJsMIcGSCzTpd1yg39aM5eWwZ_kGZ-LmHyKvNU0Z1_fIHDqw2HOIDwXjC0Sv0LaqEDDaSWmy5pLeJYNrrnWXLEWiyG1Gxw-Y3kKESY10M/s1600/giraffe.png'),
 'sloth':('ナマケモノのイラスト','https://www.irasutoya.com/2014/02/blog-post_3983.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEj5V-FVXpkYxeL1r9oNJVr5YNvrwZYRWuwZG9ScvVAglvfNtk6jtTm44zQY4qbQ7R_aApwOlY9hpOFbDOmzfbg4NUBqupuBgPOXWPZ6H68M7ldupzRmk5msL8OZJZJFCuPDITx7u-9iOsvl/s800/animal_namakemono.png'),
}
DIRECT_FOOD={
 'onion':('玉ねぎのイラスト（野菜）','https://www.irasutoya.com/2012/12/blog-post_7617.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgtZffm9F4DhF56L6zbfqLDJ3JsREuzD2xtoox3MkNq9fYq-bZkOS-Ca8v4s3ommlnBjPp9MTVw7WWyYwDccWOKaltCCvqEiJxwKnyNcmyU_GAdBzIv7IxRjsIQOZBUxe3F6EYOeRQF3anF/s400/tamanegi_onion+(1).png'),
 'frozen_food':('冷凍食品のイラスト','https://www.irasutoya.com/2014/11/blog-post_579.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiR4OZrRl8f_42KgZz8u0-_gWyASoiDOnrA-53lHeAlafKdjeEJjoUY4G-ufKQeJOKzswkACuhgA5RdB9vQJy-YU3wXHzGL_wKvmf2TxJRYeZzNmLH5aGrBPEN-UZ0QX-bllE1sMhyphenhyphen1esGA/s400/food_reitou_syokuhin.png'),
 'sweet_potato':('さつまいものイラスト（野菜）','https://www.irasutoya.com/2012/12/blog-post_4388.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEi6cZWEJbC9V0xUwLWVMA8fKU49NOrnQvkVwsibGu9Fi2uGPXP0hc17slpx0yfDX8IRcP24z2n1oPCjx3Y6FYKR_r0QmjTaxfLdljy4tXnhfl_3M8RxIlMuV2uBKHW1PRRZFQgMRIcavRJu/s400/satsumaimo_sweetpotato.png'),
 'freezer_case':('冷凍ショーケースのイラスト','https://www.irasutoya.com/2021/01/blog-post_83.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEi1tbp1mYkBbOZQAAfgnpk9bfJREkSrrB82lYVju_wOM0f0QgRzXkSy7adzF-lebD-BYFApyiHJ97NC3gd4_54y9o1Gz21ny8Ox5OTNoJ4JVNDj-zd-LerDhS_yUWTPEqkHJHg449ZbmZGx/s400/syouhin_tana_reitou_open.png'),
 'fridge':('冷蔵庫に食品をしまう人のイラスト','https://www.irasutoya.com/2017/11/blog-post_53.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjUuDfstlis1RcTtAtBdv2vklE4bwvKLn-4Jl7HtZLGjAff5EgYQ35_SV8g-oD4k6h3LThwrcKpIZ14bkM-tSHEd92OAptSNj9F-sJcSbm6df53u5Ju9pNhjDY6DA4llcM8mlzVIctgBBI/s400/cooking_reizouko_shimau.png'),
}

def item(k,title,page,img): return {'key':k,'title':title,'page':page,'image_url':img}

DATA={
 '動物': {
  'title_topic':'動物', 'images':[item(k,*v) for k,v in DIRECT_ANIMAL.items()],
  'trivia':[
   ('ラクダのコブは','水ではなく\n脂肪','脂肪','giraffe','ラクダのコブは、水ではなく脂肪。','コブは水タンクではなく、エネルギー源の脂肪をためる場所。'),
   ('猫は','甘さを\n感じにくい','甘さ','cat','猫は、甘さを感じにくい。','猫は甘味受容に関わる遺伝子の働きが弱く、甘さへの反応が薄い。'),
   ('犬は','足の裏で\n汗をかく','足の裏','dog','犬は、足の裏で汗をかく。','犬の汗腺は肉球まわりにあり、体温調整は主にパンティングで行う。'),
   ('タコは','心臓を\n3つ持つ','3つ','octopus','タコは、心臓を3つ持つ。','タコには全身へ送る心臓と、えらへ送る心臓がある。'),
   ('キリンの首は','人間と同じ\n7つの骨','7つ','giraffe','キリンの首は、人間と同じ7つの骨。','首の骨の数は多くの哺乳類で7つ。キリンは1つ1つが長い。')]
 },
 '食べ物・飲み物': {
  'title_topic':'食べ物・飲み物', 'images':[item(k,*v) for k,v in DIRECT_FOOD.items()],
  'trivia':[
   ('玉ねぎは','切ると涙を呼ぶ\n刺激物を作る','刺激物','onion','玉ねぎは、切ると涙を呼ぶ刺激物を作る。','細胞が壊れると目を刺激する成分が発生し、涙で洗い流そうとする。'),
   ('冷凍食品は','急速に凍るほど\n味を保つ','急速','frozen_food','冷凍食品は、急速に凍るほど味を保つ。','急速冷凍は氷の粒を小さくし、食感の劣化を抑えやすい。'),
   ('ヤムと呼ばれても','多くは\nサツマイモ','サツマイモ','sweet_potato','ヤムと呼ばれても、多くはサツマイモ。','アメリカでは柔らかいサツマイモをヤムと呼ぶことがあるが、本来のヤムは別の植物。'),
   ('冷凍焼けは','焦げではなく\n乾燥','乾燥','freezer_case','冷凍焼けは、焦げではなく乾燥。','冷凍庫内で水分が抜け、色や食感が悪くなる品質劣化。'),
   ('停電中の冷蔵庫は','開けないほど\n冷たさを保つ','開けない','fridge','停電中の冷蔵庫は、開けないほど冷たさを保つ。','ドアを開けるほど冷気が逃げ、庫内温度が上がりやすい。')]
 },
 '人体・健康': {
  'title_topic':'人体・健康',
  'images':[
   item('goosebumps','寒がる人のイラスト','https://www.irasutoya.com/2019/09/blog-post_83.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjO77x6RfvxtK5UM4rOhmpaHf0o52lEyagDdKKM2ay-fhvvBPIBwPuKGxT17IYYv1ZNk2jNIx-mIEnOMNxBoR_CuT-rytppvFEhXbapO2C6ZbmxX1IA5r3yyaQXgqRuAtmHOAAZ7vUgRk-Q/s1600/sick_samuke_woman.png'),
   item('nose','検体採取の断面のイラスト','https://www.irasutoya.com/2021/03/blog-post_30.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgjW3SPPLjBv4KwAZo2xAu4cM_jpKZPnSy6ufRh_4xUoVb3Fv5Z9hev4JNw_qwApaxaiCiaCPbgV6BLwIt9kNwE0MzRfGunN-hdGfZVDsZFXbkF__NQsmjnnifyHslgSUq1SvKhye905fwK/s757/kentai_saisyu_hana.png'),
   item('hair','綺麗な髪のイラスト（おばあさん）','https://www.irasutoya.com/2018/10/blog-post_96.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhaLpdZTZUOOVa2H13astn8W1DWbKMqCbk2j4Tsq-4v8bcPxjYGNSfrvEHYbhKa5q220r0wycJZgO5U_fiGe5gbTyNG0tzIZPsaa96Nf3tTbNBsk-8I-I_y8bNGh1RZcSREppJCqst2k5H6/s800/hair_biyou_kirei_obaasan.png'),
   item('stomach','胃もたれのイラスト','https://www.irasutoya.com/2018/05/blog-post_683.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgvp55UmaxLv-21rrgu8mwRs-TSW19aWL39UWr_bDTpRbXvszpUIGj_TceIhOy529RDQ6i1yfjJPMoNTmkBAkkBkoed9pEVedTG9LouftQxwEnYUnNoWW-1Y-UtyHeYBZhX0I9bE4yXDwk/s800/syokuji_imotare_man.png'),
   item('sleep','寝ている人のイラスト','https://www.irasutoya.com/2021/05/blog-post_21.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgZ_DAOF0D2uOj_rVN9F_JyTNpIonTsXRi0rotaQ8yI1_jzmWeYh3e16_A2rfhXd5c2kXCVWRgc-XYZz10g1GvetNq5UF5Kc8iW2qf6ZoseUYS0lGPN__vsJoyZf28L9n_tXuEc374R6p1H/s995/sleep_tracker_man.png')],
  'trivia':[
   ('鳥肌は','小さな筋肉が\n毛を立てる','筋肉','goosebumps','鳥肌は、小さな筋肉が毛を立てる。','毛穴近くの小さな筋肉が縮み、皮膚がぷつぷつ盛り上がる。'),
   ('おいしさは','鼻もかなり\n作る','鼻','nose','おいしさは、鼻もかなり作る。','香りは鼻や喉奥から嗅覚へ届き、味の感じ方を大きく左右する。'),
   ('白髪は','色素が減って\n起きる','色素','hair','白髪は、色素が減って起きる。','髪の色はメラニンで決まり、供給が減ると白っぽく見える。'),
   ('胃の内側は','粘膜で酸から\n守られる','粘膜','stomach','胃の内側は、粘膜で酸から守られる。','胃粘膜は胃酸や消化酵素から胃そのものを守るバリア。'),
   ('睡眠不足は','眠気だけでなく\n集中も落とす','集中','sleep','睡眠不足は、眠気だけでなく集中も落とす。','睡眠が足りないと注意力や判断に影響が出やすい。')]
 },
 '科学・テクノロジー': {
  'title_topic':'科学技術',
  'images':[
   item('mercury','宇宙ペンギンのイラスト','https://www.irasutoya.com/2021/09/blog-post_16.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhACOoXwGeJvC72_xbpGGoYcXzuuOBmO1cqHTCkozXH28qJo8Cuy_F-JhzSB96ZVgFqnXxFsmFDocQySl1att9SQLsauWRcaTVJqzXsV4B0Y0pfKv7wWViyy4LKd8nWyIOXhjSMCdgfy1J2/s835/space_uchu_penguin.png'),
   item('gps','スマホの地図アプリのイラスト','https://www.irasutoya.com/2018/11/blog-post_216.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiZ3kjvCRVO4NSEfK8HBiUqX8y8EixrnBH1oXVsmmZARc-ui04OdtPFWMEkt6nxNCTLAYizS-7IXoBNsXY-xz1Z53Z3SBmSWty1nrhxJWyUc8_sVcs_dAGTZd5U0O3k-h3CHa25K_aqBiQo/s800/smartphone_map_app_man.png'),
   item('diamond','宝石のイラスト','https://www.irasutoya.com/2018/03/blog-post_66.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEj4F7zqkZx-LxJJPLKMnqdUhfYW2kaTIfoZfhblXnCqxG3z6Rl7IZADeDFuo2d-J3Ljr7VW8oPFuhg4hAL8L2LEcDW3buj4zkxp8in02XOKK4-QXpEkel2ewUuW_OFZMfbKjiJJTixDJhU/s800/kouseki_colorful.png'),
   item('rocket','小惑星探査機のイラスト','https://www.irasutoya.com/2020/11/blog-post_41.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhO0OxbfXzXAwqvH43ujqHWP4LRrckVKupSWcJuJLzlYmPuU1cfWwbi5cafpSXn7xTLlsH3yxOsc-KYOZYxAPo1TznKA-0AuxlvwY7mY3QNGjraTdwL_IVFv5ka9ltK8H1BBJRMDdG94shZ/s937/space_syouwakusei_tansaki.png'),
   item('clock','時計のイラスト','https://www.irasutoya.com/2019/09/blog-post.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEi_OI0gJNZ3iM8QQxzqq_7wJ4XziAAAwp1kJYA_bg1QJHZo63CAYwQslTDhKyOA4x9xOgyUMenydaecvTwytfaDYK1T9_MZ03DP4wI9OymV6Q-kJhcEGeO-23n_LGZ7qnWWTUyExvqvKHlm/s1600/kaden_digital_tokei.png')],
  'trivia':[
   ('水星の1日は','1年より\n長い','1年','mercury','水星の一日は、一年より長い。','水星の公転は88地球日、昼夜1サイクルは176地球日。'),
   ('GPSは','衛星の時計で\n場所を測る','時計','gps','GPSは、衛星の時計で場所を測る。','衛星から届く時刻の差を使い、現在地を計算する。'),
   ('天王星と海王星は','ダイヤの雨が\nありうる','ダイヤ','diamond','天王星と海王星は、ダイヤの雨がありうる。','内部の高温高圧で炭素がダイヤ化する可能性がある。'),
   ('青い系外惑星は','ガラスの雨が\n横に降る','ガラス','rocket','青い系外惑星は、ガラスの雨が横に降る。','HD 189733bは超高温・強風で、ガラス質の雨が横殴りになると紹介されている。'),
   ('GPSの時計は','相対性理論で\n補正される','相対性理論','clock','GPSの時計は、相対性理論で補正される。','衛星と地上では時間の進み方が少し違うため、補正が必要。')]
 },
 '怖い・危険': {
  'title_topic':'怖い・危険',
  'images':[
   item('co','ガスコンロのイラスト','https://www.irasutoya.com/2013/05/blog-post_8845.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiyJ5eONVoqQ9x62H2yCuz0zMBxr75gg3QqSmdYkrRqZikWTuPkDp-FvDIJj7PMo5QGzj5TIyISe9a6q0L6oZpsMpkyNrhkrtvphXxmPdGtZRJgNsIsnIw6kNTk2Ydp_foyMh1gZQzi1Hn9/s800/gas_konro.png'),
   item('ocean','海藻がたくさん生えた海のイラスト','https://www.irasutoya.com/2020/11/blog-post_98.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjLgVl76DFszN44S_Xtv7NTOOeOw7VXWgIDNClxQclntOuco8MJ-yL4OzEZ_wQMB4Fy6fctA0-y5R2_80YimciDtMVjB4pZ5uX7hyLFMVINO-2aoi_JM7msVnDqbQVtn235ra3TS6fz6iXZ/s1005/nature_ocean_kaisou.png'),
   item('thunder','雷の魔法使いのイラスト','https://www.irasutoya.com/2017/03/blog-post_532.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhaeK0LJMEtjIc8mVyjtWYB1y2ApJNIdy6P12mnHbr7bPACp9j1I3-NSZe0bVvAI_Pp6-fsShGWQTivYCg-gKg-JCnS4-fSGtuTGfF3NsLDQilwcAznr86mtoqxP82oeldwkUbsQgGxdro_/s800/mahoutsukai_thunder.png'),
   item('hole','落とし穴のイラスト','https://www.irasutoya.com/2015/08/blog-post_36.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjaLlu7s-NQ30a0UAMiVXLd6gIM7MH2gum8ihPlCsV9NjRy8qcpL9mR7GQ6HzMF5uESUWC4UNn2mVWH2DlCWH293ABXZ64W_AtfatJ2x1lLNVfMZFeYz4GjVr9zf7F6_Y0NTi4DTKhmlyI/s800/otoshiana.png'),
   item('heat','マスクを付けた熱中症のイラスト（男の子）','https://www.irasutoya.com/2020/07/blog-post_6.html','https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgmtK62XzfBaoPsEgbhH9H5_WC1ZAivGkbrcpbc4lig4jKWIQ8hlIA9MSZ3chpblzmsJ3R-TFR8lAYT0TyyVVMeaWD3PeDDB4tYaCCEYNs2V3IJPaERKCQNMvoSgC36lb4RXYV6ZRu0vuvJ/s1600/summer_necchusyou_mask_boy.png')],
  'trivia':[
   ('一酸化炭素は','においも色も\nない','におい','co','一酸化炭素は、においも色もない。','一酸化炭素は無色無臭で、気づかないうちに中毒につながる。'),
   ('離岸流は','救助の多くに\n関わる','救助','ocean','離岸流は、救助の多くに関わる。','NOAAはサーフビーチ救助の多くに離岸流が関わると説明。'),
   ('雷は','空気を一瞬で\n超高温にする','超高温','thunder','雷は、空気を一瞬で超高温にする。','雷の通り道の空気は太陽表面の数倍級まで熱くなる。'),
   ('砂浜の深い穴は','崩れると\nかなり危険','危険','hole','砂浜の深い穴は、崩れるとかなり危険。','砂に埋まる事故は短時間でも危険。深い穴は放置しない。'),
   ('暑さは','油断すると\n命に関わる','命','heat','暑さは、油断すると命に関わる。','熱中症は屋外だけでなく、室内でも起きる。')]
 }
}

SOURCES={
 '動物':['Library of Congress Everyday Mysteries','NOAA Fisheries / Smithsonianなどの一般動物資料'],
 '食べ物・飲み物':['Library of Congress Everyday Mysteries','USDA FSIS'],
 '人体・健康':['NIH','NIDCD','NCBI MeSH'],
 '科学・テクノロジー':['NASA Mercury facts','NIST GPS/atomic clocks','NASA Gravity Assist'],
 '怖い・危険':['CDC Carbon monoxide','NOAA Ocean Service','NOAA/NWS Lightning safety']
}

def read_url(url, data=None, headers=None):
    h=dict(UA); h.update(headers or {})
    req=urllib.request.Request(url, data=data, headers=h)
    with urllib.request.urlopen(req, timeout=30) as r: return r.read()

import re

def first_main_image(page_url):
    html=read_url(page_url).decode('utf-8','ignore')
    urls=re.findall(r'https?://[^"\']+?\.(?:png|jpg|jpeg)', html)
    urls=[u.replace('\\/','/') for u in urls]
    bad=['twitter_card','background','banner','logo','button','avatar','search','thumbnail']
    candidates=[u for u in urls if ('blogger.googleusercontent.com' in u or 'blogspot.com' in u) and not any(x in u.lower() for x in bad)]
    for u in candidates:
        if '/s800/' in u or '/s1600/' in u or '/s757/' in u or '/s835/' in u or '/s937/' in u or '/s1005/' in u:
            return u
    if candidates: return candidates[0]
    raise RuntimeError('no image in '+page_url)

def synth(text, out_path, speaker=13):
    qurl='http://127.0.0.1:50021/audio_query?'+urllib.parse.urlencode({'text':text,'speaker':speaker})
    query=json.loads(read_url(qurl, data=b'', headers={'Content-Type':'application/json'}).decode('utf-8'))
    query['speedScale']=1.15; query['intonationScale']=1.05; query['prePhonemeLength']=0.04; query['postPhonemeLength']=0.05
    surl='http://127.0.0.1:50021/synthesis?'+urllib.parse.urlencode({'speaker':speaker})
    wav=read_url(surl, data=json.dumps(query).encode('utf-8'), headers={'Content-Type':'application/json'})
    out_path.write_bytes(wav)

def write_scene_swift(build, slug):
    (build/'make_scene_images.swift').write_text(f'''
import Foundation
import AppKit
struct Scene: Decodable {{ let imageKey: String }}
let root = URL(fileURLWithPath: "{ROOT}")
let build = root.appendingPathComponent("assets/generated/{slug}")
let src = build.appendingPathComponent("source_images")
let outDir = build.appendingPathComponent("scene_images")
let scenes = try JSONDecoder().decode([Scene].self, from: Data(contentsOf: build.appendingPathComponent("script.json")))
let W: CGFloat = 1080, H: CGFloat = 1920
let palettes: [(NSColor, NSColor)] = [
 (NSColor(calibratedRed:0.98,green:0.90,blue:0.78,alpha:1),NSColor(calibratedRed:1,green:0.97,blue:0.90,alpha:1)),
 (NSColor(calibratedRed:0.90,green:0.95,blue:0.99,alpha:1),NSColor(calibratedRed:0.96,green:0.99,blue:1,alpha:1)),
 (NSColor(calibratedRed:0.93,green:0.96,blue:0.88,alpha:1),NSColor(calibratedRed:0.98,green:1,blue:0.94,alpha:1)),
 (NSColor(calibratedRed:0.99,green:0.91,blue:0.88,alpha:1),NSColor(calibratedRed:1,green:0.98,blue:0.94,alpha:1))]
func drawImage(_ image: NSImage, in rect: NSRect) {{
 let scale = min(rect.width/image.size.width, rect.height/image.size.height)
 let w=image.size.width*scale, h=image.size.height*scale
 let r=NSRect(x:rect.midX-w/2,y:rect.midY-h/2,width:w,height:h)
 let shadow=NSShadow(); shadow.shadowColor=NSColor.black.withAlphaComponent(0.20); shadow.shadowBlurRadius=18; shadow.shadowOffset=NSSize(width:0,height:-10)
 NSGraphicsContext.current?.saveGraphicsState(); shadow.set(); image.draw(in:r.offsetBy(dx:8,dy:-8), from:.zero, operation:.sourceOver, fraction:0.26); NSGraphicsContext.current?.restoreGraphicsState()
 image.draw(in:r, from:.zero, operation:.sourceOver, fraction:1)
}}
try? FileManager.default.removeItem(at: outDir)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for (idx, scene) in scenes.enumerated() {{
 guard let image=NSImage(contentsOf: src.appendingPathComponent(scene.imageKey + ".png")) else {{ fatalError("missing image \\(scene.imageKey)") }}
 let canvas=NSImage(size:NSSize(width:W,height:H)); canvas.lockFocus()
 let (bg,card)=palettes[idx % palettes.count]
 bg.setFill(); NSRect(x:0,y:0,width:W,height:H).fill()
 for i in 0..<14 {{ let x=CGFloat((i*173)%1080)-80; let y=CGFloat((i*281)%1920)-90; NSColor.white.withAlphaComponent(0.23).setFill(); NSBezierPath(ovalIn:NSRect(x:x,y:y,width:210,height:210)).fill() }}
 card.setFill(); NSBezierPath(roundedRect:NSRect(x:38,y:38,width:W-76,height:H-76), xRadius:46, yRadius:46).fill()
 drawImage(image, in:NSRect(x:145,y:655,width:790,height:710))
 canvas.unlockFocus(); let cg=canvas.cgImage(forProposedRect:nil, context:nil, hints:nil)!; let rep=NSBitmapImageRep(cgImage:cg)
 try rep.representation(using:.png, properties:[:])!.write(to: outDir.appendingPathComponent(String(format:"scene_%02d.png", idx+1)))
}}
''', encoding='utf-8')

def patch_render(build):
    s=RENDER_SRC.read_text()
    s=s.replace('let prefixFontSize: CGFloat = isIntroCard ? 98 : (prefix.count >= 9 ? 92 : 104)', 'let lineCount = prefix.split(separator: "\\n").count\n    let prefixFontSize: CGFloat = isIntroCard ? (lineCount >= 3 ? 78 : (prefix.count >= 16 ? 86 : 98)) : (prefix.count >= 9 ? 92 : 104)')
    s=s.replace('let prefixLineSpacing: CGFloat = isIntroCard ? 24 : 14', 'let prefixLineSpacing: CGFloat = isIntroCard ? (lineCount >= 3 ? 12 : 20) : 14')
    (build/'render_lv1_short.swift').write_text(s, encoding='utf-8')

def write_contact_swift(build, slug, video_name):
    (build/'make_contact_sheet.swift').write_text(f'''
import Foundation
import AVFoundation
import AppKit
struct Manifest: Decodable {{ struct Scene: Decodable {{ let revealAt: Double? }}; let scenes:[Scene]; let segmentAudioFiles:[String]?; let pauseSeconds:Double? }}
func duration(_ path:String)->Double{{ let asset=AVURLAsset(url:URL(fileURLWithPath:path)); return CMTimeGetSeconds(asset.duration) }}
let root=URL(fileURLWithPath:"{ROOT}")
let slug="{slug}"
let manifest=try JSONDecoder().decode(Manifest.self, from:Data(contentsOf:root.appendingPathComponent("assets/generated/\(slug)/manifest.json")))
let videoURL=root.appendingPathComponent("renders/{video_name}")
let outDir=root.appendingPathComponent("renders/check_\(slug)")
try? FileManager.default.removeItem(at:outDir); try FileManager.default.createDirectory(at:outDir, withIntermediateDirectories:true)
let pause=manifest.pauseSeconds ?? 0.0
var durs=(manifest.segmentAudioFiles ?? []).enumerated().map{{ (idx, p) in duration(p) + (idx == (manifest.segmentAudioFiles ?? []).count - 1 ? 0 : pause) }}
let asset=AVURLAsset(url:videoURL); let gen=AVAssetImageGenerator(asset:asset); gen.appliesPreferredTrackTransform=true; gen.maximumSize=CGSize(width:360,height:640)
var times:[(String,Double)]=[]; var cursor=0.0
for i in 0..<manifest.scenes.count {{ let d=i<durs.count ? durs[i] : 2.0; let reveal=manifest.scenes[i].revealAt ?? 0.5; times.append((String(format:"%02d_before",i+1), cursor+max(0.12,d*min(reveal*0.72,0.40)))); times.append((String(format:"%02d_after",i+1), cursor+min(d*max(reveal+0.22,0.72),max(0.15,d-0.12)))); cursor += d }}
var images:[(String,NSImage)]=[]
for (label,t) in times {{ let cg=try gen.copyCGImage(at:CMTime(seconds:t,preferredTimescale:600), actualTime:nil); let img=NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height)); images.append((label,img)); let rep=NSBitmapImageRep(cgImage:cg); try rep.representation(using:.png,properties:[:])!.write(to:outDir.appendingPathComponent("frame_\(label).png")) }}
let cellW:CGFloat=270, cellH:CGFloat=480, labelH:CGFloat=42, cols=4; let rows=Int(ceil(Double(images.count)/Double(cols)))
let sheet=NSImage(size:NSSize(width:CGFloat(cols)*cellW,height:CGFloat(rows)*(cellH+labelH))); sheet.lockFocus(); NSColor.black.setFill(); NSRect(x:0,y:0,width:sheet.size.width,height:sheet.size.height).fill()
let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:22,weight:.bold),.foregroundColor:NSColor.white]
for (idx,(label,img)) in images.enumerated() {{ let col=idx%cols; let row=rows-1-idx/cols; let x=CGFloat(col)*cellW; let y=CGFloat(row)*(cellH+labelH); NSString(string:label).draw(in:NSRect(x:x+8,y:y+cellH+8,width:cellW-16,height:labelH-8),withAttributes:attrs); img.draw(in:NSRect(x:x,y:y,width:cellW,height:cellH), from:.zero, operation:.sourceOver, fraction:1) }}
sheet.unlockFocus(); let cg=sheet.cgImage(forProposedRect:nil,context:nil,hints:nil)!; let rep=NSBitmapImageRep(cgImage:cg); try rep.representation(using:.png,properties:[:])!.write(to:outDir.appendingPathComponent("contact.png"))
try times.map{{ "\($0.0) \(String(format:"%.2f",$0.1))" }}.joined(separator:"\\n").write(to:outDir.appendingPathComponent("times.txt"), atomically:true, encoding:.utf8)
''', encoding='utf-8')

def make(category):
    cfg=DATA[category]
    slug=f"zatsugaku_{cat_slug(category)}_lv1_001"
    build=ROOT/'assets/generated'/slug; src=build/'source_images'; sc=build/'scene_images'
    build.mkdir(parents=True, exist_ok=True); src.mkdir(parents=True, exist_ok=True); sc.mkdir(parents=True, exist_ok=True)
    # download images
    meta=[]
    for it in cfg['images']:
        out=src/(it['key']+'.png')
        if not out.exists():
            try:
                out.write_bytes(read_url(it['image_url']))
            except Exception:
                it['image_url']=first_main_image(it['page'])
                out.write_bytes(read_url(it['image_url']))
        meta.append({**it,'file':str(out)})
    (build/'source_meta.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
    # script
    title = f"知って損しない\n{cfg['title_topic']}の雑学 Lv1"
    scenes=[{'kind':'title','prefixText':title,'suffixText':'','imageKey':cfg['images'][0]['key'],'voice':f"知って損しない、{cfg['title_topic']}の雑学、レベルワン。"},
            {'kind':'prompt','prefixText':'詳細は\nコメント欄','suffixText':'','imageKey':cfg['images'][1]['key'],'voice':'詳細はコメント欄。'}]
    for pre,suf,hi,img,voice,detail in cfg['trivia']:
        scenes.append({'prefixText':pre,'suffixText':suf,'highlightWords':[hi],'imageKey':img,'voice':voice,'revealAt':REVEAL,'detail':detail})
    scenes.append({'kind':'final','prefixText':'いくつ\nわかりましたか？','suffixText':'','imageKey':cfg['images'][-1]['key'],'voice':'いくつわかった？'})
    (build/'script.json').write_text(json.dumps(scenes,ensure_ascii=False,indent=2),encoding='utf-8')
    write_scene_swift(build, slug); subprocess.check_call(['swift', str(build/'make_scene_images.swift')])
    # voice
    segs=[]
    for i,scene in enumerate(scenes,1):
        p=build/f'voice_scene_{i:02d}.wav'; synth(scene['voice'], p); segs.append(str(p))
    out_voice=build/'voice.wav'; params=None; frames=[]
    for idx,fp in enumerate(segs):
        with wave.open(fp,'rb') as w:
            if params is None: params=w.getparams()
            frames.append(w.readframes(w.getnframes()))
        if idx != len(segs)-1:
            nch, sw, fr = params.nchannels, params.sampwidth, params.framerate
            frames.append(b'\x00' * int(PAUSE*fr) * nch * sw)
    with wave.open(str(out_voice),'wb') as w:
        w.setparams(params)
        for frs in frames: w.writeframes(frs)
    # manifest
    manifest={'width':1080,'height':1920,'fps':18,'pauseSeconds':PAUSE,'segmentAudioFiles':segs,'scenes':[],'badge':'','footer':''}
    for i,scene in enumerate(scenes,1):
        manifest['scenes'].append({'subtitle':scene['prefixText']+(('\n'+scene['suffixText']) if scene.get('suffixText') else ''),'highlightWords':scene.get('highlightWords',[]),'imageFile':str(sc/f'scene_{i:02d}.png'),'tag':'','title':'','prefixText':scene['prefixText'],'suffixText':scene.get('suffixText',''),'revealAt':scene.get('revealAt',REVEAL)})
    (build/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    patch_render(build)
    raw=ROOT/'renders'/f'{slug}_raw.mp4'; final=ROOT/'renders'/f'{slug}_bgm050.mp4'
    subprocess.check_call(['swift', str(build/'render_lv1_short.swift'), str(build/'manifest.json'), str(out_voice), str(raw)])
    subprocess.check_call(['swift', str(BGM_HELPER), str(raw), str(BGM), str(final), '1.0', '0.50'])
    write_contact_swift(build, slug, final.name); subprocess.check_call(['swift', str(build/'make_contact_sheet.swift')])
    # metadata
    comment_lines=['動画の補足👇','']
    for n,scn in enumerate(scenes[2:-1],1):
        comment_lines.append(f'{n}. {scn["prefixText"]}{scn["suffixText"].replace(chr(10), "")}')
        comment_lines.append(scn['detail'])
        comment_lines.append('')
    comment_lines.append('いくつわかりましたか？')
    title_meta=f'知って損しない{cfg["title_topic"]}の雑学 Lv1 #雑学 #shorts'
    desc=f'{cfg["title_topic"]}のLv1雑学を短く紹介。\n\n音声: VOICEVOX: 青山龍星\nBGM: Escort / もっぴーさうんど（DOVA-SYNDROME）\nイラスト: いらすとや'
    md=f'''# {cfg['title_topic']}の雑学 Lv1 001\n\n- 生成日: {date.today().isoformat()}\n- カテゴリ: {category}\n- レベル: Lv1\n- 動画: `{final}`\n- 確認用コンタクトシート: `{ROOT/'renders'/('check_'+slug)/'contact.png'}`\n- 音声: VOICEVOX: 青山龍星\n- BGM: Escort / もっぴーさうんど（DOVA-SYNDROME）\n\n## 動画タイトル案\n\n{title_meta}\n\n## 説明文案\n\n{desc}\n\n## 固定コメント案\n\n{chr(10).join(comment_lines)}\n\n## 画面構成\n\n'''
    for i,sn in enumerate(scenes,1): md += f"{i}. {sn['prefixText'].replace(chr(10),' / ')}" + (f" / {sn.get('suffixText','').replace(chr(10),' / ')}" if sn.get('suffixText') else '') + "\n"
    md += '\n## 参照メモ\n\n' + ''.join(f'- {x}\n' for x in SOURCES[category])
    md += '\n## いらすとや素材\n\n' + ''.join(f"- {m['title']}: {m['page']}\n" for m in meta)
    (ROOT/'metadata/generated'/f'{slug}.md').write_text(md,encoding='utf-8')
    # duration
    dur=subprocess.check_output(['python3','-c',f"import AVFoundation,Foundation;print('x')"], stderr=subprocess.DEVNULL) if False else b''
    print(json.dumps({'category':category,'slug':slug,'video':str(final),'contact':str(ROOT/'renders'/('check_'+slug)/'contact.png'),'metadata':str(ROOT/'metadata/generated'/f'{slug}.md')}, ensure_ascii=False))

if __name__=='__main__':
    cats=list(DATA.keys())
    if len(sys.argv)>1: cats=sys.argv[1:]
    for c in cats: make(c)
