#!/usr/bin/env python3
"""앱스토어 마케팅 스크린샷 생성 — HTML 조판 → 헤드리스 Chrome 렌더링.

    python3 scripts/make_marketing_screenshots.py ko
    python3 scripts/make_marketing_screenshots.py en
    python3 scripts/make_marketing_screenshots.py ja

원본은 docs/screenshots/raw-<lang>/ 의 시뮬레이터 캡처(1320x2868)를 쓰고,
결과는 docs/screenshots/marketing-<lang>/ 에 **제출 규격 1242x2688 그대로** 나온다.
리사이즈가 아니라 캔버스 자체가 그 크기라서 글자가 뭉개지지 않는다.

다음 릴리즈 때는 원본만 다시 찍어 이 스크립트를 그대로 돌리면 된다.
"""
import subprocess, sys, pathlib

ROOT   = pathlib.Path(__file__).resolve().parent.parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H   = 1242, 2688          # App Store Connect 제출 규격

# 앱의 색을 그대로 쓴다 — 마케팅 이미지가 앱과 다른 세계처럼 보이면 안 된다.
CREAM, CREAM_INK, CREAM_SUB = "#f5efe2", "#241c12", "#7a6a55"
NIGHT, NIGHT_INK, NIGHT_SUB = "#100d08", "#f3ece0", "#8a7a66"
BEZEL,  BEZEL_EDGE          = "#17140f", "#3b332a"

# (파일명, 레이아웃, 어두운 배경인가, 헤드라인, 서브카피, crop)
#
# crop 은 "화면 위에서부터 이만큼만 남긴다"는 비율이다. 회고 책처럼 내용이
# 화면 위쪽에만 있고 아래가 텅 빈 화면은, 그대로 넣으면 검은 여백이 절반을
# 차지한다. 위쪽만 잘라 크게 보여주고 아랫단은 캔버스 밖으로 흘려보낸다.
SHOTS = {
 "ko": [
  ("01-week-dark.png",     "hero-bleed",  False, "남은 시간이<br>눈앞에서 타들어갑니다", "하루 · 한 주 · 한 달 · 한 해",        None),
  ("02-month-light.png",   "hero-bleed",  True,  "라이트도, 다크도",                     "기기 설정을 따르거나 직접 고르세요",  None),
  ("03-urn-dark.png",      "left-text",   False, "하루의 끝은<br>재로 남습니다",         "적어 둔 것들이 그 주 항아리에 쌓여요", None),
  ("04-flow-light.png",    "hero-bleed",  True,  "시간을 어디에 썼는지",                 "분포 그래프와 잔불 달력으로 한눈에",  None),
  ("05-book-dark.png",     "top-crop",    False, "지난 재를 다시 읽어보세요",            "양피지 위에 남긴 한 줄들",            0.58),
  ("06-settings-dark.png", "flat-rotate", False, "취침 시간부터<br>화면 테마까지",       "당신에게 맞게 맞춰 쓰세요",           None),
  # ── 프로 ──
  ("07-theme-dark.png",    "hero-bleed",  True,  "불꽃의 빛깔을<br>골라 보세요",         "프로 테마 · 달빛 한지 · 청자 · 노을",   None),
  ("08-poster-dark.png",   "text-bottom", False, "꺼 둔 밤들을<br>한 장에",             "프로 · 모은 조각을 포스터와 카드로",     None),
  ("09-year-light.png",    "top-crop",    False, "한 해의 재를<br>한눈에",              "프로 · 열두 달이 어디로 흘렀는지",       0.62),
  ("10-book-pdf.png",      "pages",       False, "회고를<br>책 한 권으로",              "프로 · 날짜별 쪽으로 묶은 PDF",         None),
 ],
 "en": [
  ("01-week-dark.png",     "hero-bleed",  False, "Watch your time<br>burn away", "Day, week, month, year",                      None),
  ("02-month-light.png",   "hero-bleed",  True,  "Light or dark",                "Follow your device, or choose your own",       None),
  ("03-urn-dark.png",      "left-text",   False, "Every day ends<br>as ash",     "What you write settles into that week's urn",  None),
  ("04-flow-light.png",    "hero-bleed",  True,  "See where<br>your time went",  "A distribution graph and an ember calendar",   None),
  ("05-book-dark.png",     "top-crop",    False, "Read your ashes again",        "The lines you left on the parchment",          0.58),
  ("06-settings-dark.png", "flat-rotate", False, "From bedtime<br>to theme",     "Set it up the way you like",                   None),
  # ── Pro ──
  ("07-theme-dark.png",    "hero-bleed",  True,  "Pick the color<br>of your flame",    "Pro themes: Moonlit Hanji, Celadon, Dusk",  None),
  ("08-poster-dark.png",   "text-bottom", False, "All your nights<br>on one page",     "Pro turns kept fragments into posters",     None),
  ("09-year-light.png",    "top-crop",    False, "A whole year<br>of ash",             "Pro shows where twelve months went",        0.62),
  ("10-book-pdf.png",      "pages",       False, "Your reflections,<br>bound as a book", "Pro exports a PDF, a page for every day", None),
 ],
 "ja": [
  ("01-week-dark.png",     "hero-bleed",  False, "残り時間が<br>目の前で燃えていく", "一日・一週間・一か月・一年",              None),
  ("02-month-light.png",   "hero-bleed",  True,  "ライトも、ダークも",               "端末の設定に合わせるか、自分で選べます",  None),
  ("03-urn-dark.png",      "left-text",   False, "一日の終わりは<br>灰になって残る", "書いたことはその週の壺に積もります",      None),
  ("04-flow-light.png",    "hero-bleed",  True,  "時間を何に<br>使ったのか",         "分布グラフと火種カレンダーでひと目で",    None),
  ("05-book-dark.png",     "top-crop",    False, "残した灰を読み返す",               "羊皮紙に残したひとことたち",              0.58),
  ("06-settings-dark.png", "flat-rotate", False, "就寝時間から<br>テーマまで",       "自分に合わせて使えます",                  None),
  # ── Pro ──
  ("07-theme-dark.png",    "hero-bleed",  True,  "炎の色合いを<br>選べます",         "Proテーマ・月明かりの韓紙・青磁・夕焼け", None),
  ("08-poster-dark.png",   "text-bottom", False, "消した夜を<br>一枚に",             "Pro・集めたかけらをポスターとカードに",   None),
  ("09-year-light.png",    "top-crop",    False, "一年の灰を<br>ひと目で",           "Pro・12か月がどこへ流れたか",             0.62),
  ("10-book-pdf.png",      "pages",       False, "ふりかえりを<br>一冊の本に",       "Pro・日付ごとのページでPDFに",            None),
 ],
 "zh-Hant": [
  ("01-week-dark.png",     "hero-bleed",  False, "剩餘的時間<br>在眼前燃燒", "一天、一週、一個月、一年",                  None),
  ("02-month-light.png",   "hero-bleed",  True,  "淺色或深色",               "跟隨裝置設定，或自己挑選",                  None),
  ("03-urn-dark.png",      "left-text",   False, "每一天的盡頭<br>都化為灰燼", "寫下的內容會落進當週的灰罐",              None),
  ("04-flow-light.png",    "hero-bleed",  True,  "時間都花在<br>哪裡了",       "分布圖與餘燼月曆，一目瞭然",              None),
  ("05-book-dark.png",     "top-crop",    False, "重讀你留下的灰燼",           "那些留在羊皮紙上的字句",                  0.58),
  ("06-settings-dark.png", "flat-rotate", False, "從就寢時間<br>到主題",       "照自己的習慣來設定",                      None),
  # ── Pro ──
  ("07-theme-dark.png",    "hero-bleed",  True,  "挑選火焰<br>的顏色",         "Pro 主題：月光韓紙、青瓷、晚霞",          None),
  ("08-poster-dark.png",   "text-bottom", False, "熄滅的夜晚<br>集成一張",     "Pro・把收集的碎片做成海報與卡片",         None),
  ("09-year-light.png",    "top-crop",    False, "一整年的灰燼<br>一目瞭然",   "Pro・十二個月流向了哪裡",                 0.62),
  ("10-book-pdf.png",      "pages",       False, "把回顧<br>裝訂成一本書",     "Pro・依日期逐頁匯出 PDF",                 None),
 ],
 "ru": [
  ("01-week-dark.png", "hero-bleed", False, "Время сгорает<br>на ваших глазах", "День, неделя, месяц, год", None),
  ("02-month-light.png", "hero-bleed", True, "Светлая или тёмная", "По настройке устройства или на ваш выбор", None),
  ("03-urn-dark.png", "left-text", False, "Каждый день<br>становится пеплом", "Написанное оседает в урне этой недели", None),
  ("04-flow-light.png", "hero-bleed", True, "Куда ушло<br>ваше время", "График распределения и календарь углей", None),
  ("05-book-dark.png", "top-crop", False, "Перечитайте свой пепел", "Строки, оставленные на пергаменте", 0.58),
  ("06-settings-dark.png", "flat-rotate", False, "От времени сна<br>до темы", "Настройте всё под себя", None),
  # ── Pro ──
  ("07-theme-dark.png", "hero-bleed", True, "Выберите цвет<br>своего пламени", "Темы Pro: лунная ханджи, селадон, закат", None),
  ("08-poster-dark.png", "text-bottom", False, "Все погасшие ночи<br>на одном листе", "Pro превращает осколки в постеры", None),
  ("09-year-light.png", "top-crop", False, "Целый год<br>пепла", "Pro показывает, куда ушли двенадцать месяцев", 0.62),
  ("10-book-pdf.png", "pages", False, "Ваши записи<br>книгой", "Pro: PDF по странице на каждый день", None),
 ],
 "fr": [
  ("01-week-dark.png", "hero-bleed", False, "Regardez votre temps<br>se consumer", "Jour, semaine, mois, année", None),
  ("02-month-light.png", "hero-bleed", True, "Clair ou sombre", "Suivez votre appareil ou choisissez", None),
  ("03-urn-dark.png", "left-text", False, "Chaque jour finit<br>en cendres", "Ce que vous écrivez rejoint l’urne de la semaine", None),
  ("04-flow-light.png", "hero-bleed", True, "Où est passé<br>votre temps", "Un graphique et un calendrier des braises", None),
  ("05-book-dark.png", "top-crop", False, "Relisez vos cendres", "Les lignes laissées sur le parchemin", 0.58),
  ("06-settings-dark.png", "flat-rotate", False, "Du coucher<br>au thème", "Réglez-la à votre façon", None),
  # ── Pro ──
  ("07-theme-dark.png", "hero-bleed", True, "Choisissez la couleur<br>de votre flamme", "Thèmes Pro : hanji, céladon, crépuscule", None),
  ("08-poster-dark.png", "text-bottom", False, "Toutes vos nuits<br>sur une page", "Pro transforme les fragments en affiches", None),
  ("09-year-light.png", "top-crop", False, "Une année<br>de cendres", "Pro montre où sont passés douze mois", 0.62),
  ("10-book-pdf.png", "pages", False, "Vos bilans<br>reliés en livre", "Pro : un PDF, une page par jour", None),
 ],
 "it": [
  ("01-week-dark.png", "hero-bleed", False, "Guarda il tuo tempo<br>consumarsi", "Giorno, settimana, mese, anno", None),
  ("02-month-light.png", "hero-bleed", True, "Chiaro o scuro", "Segui il dispositivo o scegli tu", None),
  ("03-urn-dark.png", "left-text", False, "Ogni giorno finisce<br>in cenere", "Ciò che scrivi si deposita nell’urna della settimana", None),
  ("04-flow-light.png", "hero-bleed", True, "Dove è andato<br>il tuo tempo", "Un grafico e un calendario delle braci", None),
  ("05-book-dark.png", "top-crop", False, "Rileggi la tua cenere", "Le righe lasciate sulla pergamena", 0.58),
  ("06-settings-dark.png", "flat-rotate", False, "Dal riposo<br>al tema", "Impostala a modo tuo", None),
  # ── Pro ──
  ("07-theme-dark.png", "hero-bleed", True, "Scegli il colore<br>della tua fiamma", "Temi Pro: hanji, celadon, tramonto", None),
  ("08-poster-dark.png", "text-bottom", False, "Tutte le tue notti<br>su un foglio", "Pro trasforma i frammenti in poster", None),
  ("09-year-light.png", "top-crop", False, "Un anno<br>di cenere", "Pro mostra dove sono andati dodici mesi", 0.62),
  ("10-book-pdf.png", "pages", False, "Le tue riflessioni<br>in un libro", "Pro: un PDF, una pagina al giorno", None),
 ],
}

FONTS = {
    "ko": '-apple-system, "Apple SD Gothic Neo", "Noto Sans KR", sans-serif',
    "en": '-apple-system, "SF Pro Display", Helvetica, sans-serif',
    "ja": '-apple-system, "Hiragino Sans", "Hiragino Kaku Gothic ProN", sans-serif',
    "zh-Hant": '-apple-system, "PingFang TC", "Heiti TC", sans-serif',
    "ru": '-apple-system, "SF Pro Display", Helvetica, sans-serif',
    "fr": '-apple-system, "SF Pro Display", Helvetica, sans-serif',
    "it": '-apple-system, "SF Pro Display", Helvetica, sans-serif',
}
HEAD_SIZE = {"ko": 88, "en": 96, "ja": 84, "zh-Hant": 84, "ru": 88, "fr": 92, "it": 92}
SUB_SIZE  = {"ko": 42, "en": 44, "ja": 40, "zh-Hant": 40, "ru": 42, "fr": 43, "it": 43}


def base_css(lang, dark):
    ink = NIGHT_INK if dark else CREAM_INK
    sub = NIGHT_SUB if dark else CREAM_SUB
    bg  = NIGHT     if dark else CREAM
    glow = ("box-shadow: 0 0 180px rgba(214,120,44,.30), 40px 70px 110px rgba(0,0,0,.55);"
            if dark else
            "box-shadow: 50px 80px 110px rgba(60,40,20,.22), 16px 26px 44px rgba(60,40,20,.14);")
    return f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:{bg}; font-family:{FONTS[lang]}; position:relative; }}
.headline {{ font-size:{HEAD_SIZE[lang]}px; font-weight:800; color:{ink};
             letter-spacing:-2px; line-height:1.28; }}
.sub {{ font-size:{SUB_SIZE[lang]}px; font-weight:500; color:{sub}; letter-spacing:-1px; line-height:1.4; }}
.phone {{ background:{BEZEL}; border-radius:104px; border:3px solid {BEZEL_EDGE}; padding:22px; {glow} }}
.phone img {{ width:100%; display:block; border-radius:84px; }}
"""

LAYOUTS = {
    "hero-bleed": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 70px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:900px; }
""",
    "left-text": """
.headline { text-align:left; margin:260px 0 0 100px; }
.sub { text-align:left; margin:44px 100px 0 104px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:250px; top:940px; }
.phone { width:790px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:150px; }
.phone { width:800px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:110px; padding:0 70px; }
.sub { text-align:center; margin-top:42px; padding:0 70px; }
""",
    "flat-rotate": """
.headline { text-align:center; margin-top:240px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 70px; }
.wrap { position:absolute; left:225px; top:850px; }
.phone { width:790px; transform:rotate(-5deg); }
""",
    # 위쪽만 잘라낸 화면을 크게 보여주고, 잘린 아랫단은 배경으로 스며들게 한다.
    # 딱 끊긴 단면이 그냥 떠 있으면 "잘못 잘린 이미지" 처럼 보인다.
    # 회고 책 PDF 의 쪽(표지 + 본문 2쪽)을 부채꼴로 펼친다. 기기 대신 종이를 보인다.
    "pages": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 70px; }
.pages { position:absolute; left:0; right:0; top:880px; height:1700px; }
.page { position:absolute; width:800px; border-radius:14px; overflow:hidden;
        box-shadow: 40px 60px 100px rgba(60,40,20,.28), 10px 18px 36px rgba(60,40,20,.16); }
.page img { width:100%; display:block; }
.p2 { left:400px; top:170px; transform:rotate(8deg); }
.p1 { left:220px; top:70px;  transform:rotate(-1deg); }
.p0 { left:40px;  top:230px; transform:rotate(-9deg); }
""",
    "top-crop": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 70px; }
.wrap { position:absolute; left:0; right:0; top:900px; display:flex; justify-content:center; }
.phone { width:1040px; padding-bottom:0; border-bottom:none;
         border-radius:104px 104px 0 0;
         -webkit-mask-image: linear-gradient(to bottom, #000 74%, rgba(0,0,0,0) 100%); }
.phone img { border-radius:84px 84px 0 0; }
""",
}

TEXT_FIRST  = '<div class="headline">{h}</div><div class="sub">{s}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{h}</div><div class="sub">{s}</div>'
PAGES       = '<div class="headline">{h}</div><div class="sub">{s}</div><div class="pages">{imgs}</div>'
HTML = '<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def main(lang, only=None):
    src  = ROOT / "docs" / "screenshots" / f"raw-{lang}"
    out  = ROOT / "docs" / "screenshots" / f"marketing-{lang}"
    work = ROOT / "docs" / "screenshots" / ".build"
    out.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)

    for fname, layout, dark, head, sub, crop in SHOTS[lang]:
        if only and fname != only:
            continue
        shot = src / fname
        if crop:
            from PIL import Image
            im = Image.open(shot)
            im = im.crop((0, 0, im.width, int(im.height * crop)))
            shot = work / f"{lang}-crop-{fname}"
            im.save(shot)
        if layout == "pages":
            # 10-book-pdf.png → raw 의 10-book-p0/p1/p2.png (PDF 쪽을 그대로 그린 것)
            stem = fname.split("-")[0]
            imgs = "".join(f'<div class="page p{i}"><img src="{(src / f"{stem}-book-p{i}.png").as_uri()}"></div>'
                           for i in (2, 1, 0))
            body = PAGES.format(h=head, s=sub, imgs=imgs)
        else:
            tpl = PHONE_FIRST if layout == "text-bottom" else TEXT_FIRST
            body = tpl.format(h=head, s=sub, img=shot.as_uri())
        css = base_css(lang, dark) + LAYOUTS[layout]
        html = work / f"{lang}-{fname.replace('.png','.html')}"
        html.write_text(HTML.format(css=css, body=body), encoding="utf-8")
        png = out / fname
        subprocess.run([CHROME, "--headless=new", f"--screenshot={png}",
                        f"--window-size={W},{H}", "--force-device-scale-factor=1",
                        "--hide-scrollbars", "--disable-gpu", html.as_uri()],
                       check=True, capture_output=True)
        print(f"rendered {png.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "ko",
         sys.argv[2] if len(sys.argv) > 2 else None)
