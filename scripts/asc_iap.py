#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
App Store Connect 인앱 상품을 레포의 원본(scripts/asc_iap.json)에 맞춘다. 기본은 미리 보기, --apply 로 올린다.

    python3 scripts/asc_iap.py            # 무엇이 바뀌는지 보기
    python3 scripts/asc_iap.py --apply    # 올리기
    python3 scripts/asc_iap.py --check    # 표만 검사 (이름 30자 · 설명 55자)

세 칸(무료 · Plus · Pro), 유료 칸마다 연 구독과 평생.
    com.burningparchment.app.plus          Plus 평생 (비소모성)
    com.burningparchment.app.pro           Pro 평생 (비소모성, 예전의 '프로' — 기존 구매자는 그대로 Pro)
    com.burningparchment.app.plus.yearly   Plus 연 구독 (그룹 낮은 단계)
    com.burningparchment.app.pro.yearly    Pro 연 구독 (그룹 높은 단계)
    com.burningparchment.app.gift.pro      Pro 선물 (소모성, 값 = Pro 평생)
    com.burningparchment.app.gift.plus     Plus 선물 (소모성, 값 = Plus 평생)
    com.burningparchment.app.tip.*         응원 3단

맞추는 것
  1. 없는 상품을 만든다 — 값, 판매 지역(전부, 새 지역 포함).
  2. 이름 · 설명 — 표대로 모든 언어 (구독 묶음 이름 포함).
  3. 심사 메모 — 아래 REVIEW_NOTES.
  4. 연 구독 첫 해 할인 — 첫 1년 반값, 처음에 한 번 내는 방식(PAY_UP_FRONT), 구독을 파는 모든 지역.
  5. 평생 값 올리기 — PRICE_CHANGES 의 날부터 새 값(그 전날까지는 지금 값). LeeoKit 의 평생 가격 안내와 같은 날.
  6. 심사 이미지 — docs/screenshots/iap-review/<상품 ID>.png 가 있고 아직 안 올렸으면 올린다.
     찍는 법: 앱을 -reviewShot <상품 ID> -reviewShotPrice '$9.99' -skipNotifications YES -forcePro NO
              -AppleLanguages "(en)" 로 띄우고 시뮬레이터 화면을 저장한다(DebugLaunch.swift).
"""

import json
import os
import sys

from asc import APP_ID, all_pages, call

HERE = os.path.dirname(os.path.abspath(__file__))
NAME_MAX, DESC_MAX = 30, 55
B = "com.burningparchment.app"

# 평생 (비소모성): 상품 → 미국 값
LIFETIMES = {f"{B}.plus": "12.99", f"{B}.pro": "29.99"}

# 연 구독: 상품 → (미국 값, 그룹 단계 — 1 이 가장 높다)
SUBSCRIPTIONS = {f"{B}.pro.yearly": ("9.99", 1), f"{B}.plus.yearly": ("4.99", 2)}
GROUP_NAME = "Burning Parchment Plans"

# 선물 = 소모성. 사는 사람은 아무것도 열리지 않고, 앱이 App Store 오퍼 코드 한 장을 꺼내 보낼 링크로 준다.
GIFTS = {f"{B}.gift.pro": f"{B}.pro", f"{B}.gift.plus": f"{B}.plus"}

# 연 구독 첫 해 (미국 기준 값, 다른 지역은 애플의 같은 값 환산)
FIRST_YEAR = {f"{B}.plus.yearly": "2.49", f"{B}.pro.yearly": "4.99"}

# 평생 값 올리기: 상품 → (새 미국 값, 시작일). LeeoKit `LeeoLadderSchedule.lifetimePriceChange` 와 같은 날.
# 선물은 그 칸 평생과 언제나 같은 값이어야 해서 함께 올린다.
# 2026-11-08 사용자 결정으로 예정(11-17)보다 앞당겨 오늘부터 올린다.
PRICE_CHANGES = {f"{B}.pro": ("29.99", "2026-11-08"), f"{B}.gift.pro": ("29.99", "2026-11-08")}

PLACE = "Settings (gear icon, top right) > Plans & Support"
REVIEW_NOTES = {
    "subscription": ("Auto-renewable subscription. Find it in the paywall that opens when adding a second deadline or a second "
                     f"'Times of my life' count, when choosing a locked theme, or in {PLACE} > Plans."),
    "lifetime": f"One-time purchase that unlocks this tier for life. Find it in the paywall (Lifetime option) or in {PLACE} > Plans.",
    "tip": f"Optional tip that unlocks nothing. {PLACE} > the tip row.",
    "gift": ("Consumable gift purchase. The buyer does not get anything unlocked themselves. After the purchase the app takes "
             "one App Store offer code (a free one-time offer code for the non-consumable {grants}, created in App Store Connect) "
             "and shows an App Store redeem link for the buyer to send. The recipient taps the link and redeems it in the App Store, "
             "which unlocks the tier. The app never unlocks anything with its own codes. Location: " + PLACE + " > Send a Gift."),
}


def review_note(pid, is_sub):
    if pid in GIFTS:
        return REVIEW_NOTES["gift"].format(grants=GIFTS[pid])
    if is_sub:
        return REVIEW_NOTES["subscription"]
    if ".tip." in pid:
        return REVIEW_NOTES["tip"]
    return REVIEW_NOTES["lifetime"]


# MARK: - 표

def load_table():
    t = json.load(open(os.path.join(HERE, "asc_iap.json"), encoding="utf-8"))
    rows, errors = {}, []
    for pid, spec in t["products"].items():
        rows[pid] = {}
        for locale, lang in t["locales"].items():
            f = dict(zip(t["fields"], t["languages"][lang]))
            brand = t["brand"].get(lang, t["brand"]["*"])
            fill = lambda s: s.format(brand=brand, tier=spec.get("tier", ""))
            f = {k: fill(v) for k, v in f.items()}
            name = spec["name"].format(**f)
            desc = f[spec["description"]]
            if len(name) > NAME_MAX:
                errors.append(f"{pid} {locale} 이름 {len(name)}자: {name}")
            if len(desc) > DESC_MAX:
                errors.append(f"{pid} {locale} 설명 {len(desc)}자: {desc}")
            rows[pid][locale] = {"name": name, "description": desc}
    subs = {pid for pid, s in t["products"].items() if s.get("subscription")}
    brands = {loc: t["brand"].get(lang, t["brand"]["*"]) for loc, lang in t["locales"].items()}
    return rows, subs, brands, errors


# MARK: - 맞추기

def sync_localizations(kind, owner, wanted, apply, label):
    list_path, res, rel, rel_type = {
        "iap": (f"/v2/inAppPurchases/{owner}/inAppPurchaseLocalizations?limit=200",
                "inAppPurchaseLocalizations", "inAppPurchaseV2", "inAppPurchases"),
        "sub": (f"/v1/subscriptions/{owner}/subscriptionLocalizations?limit=200",
                "subscriptionLocalizations", "subscription", "subscriptions"),
        "group": (f"/v1/subscriptionGroups/{owner}/subscriptionGroupLocalizations?limit=200",
                  "subscriptionGroupLocalizations", "subscriptionGroup", "subscriptionGroups"),
    }[kind]
    have = {x["attributes"]["locale"]: x for x in all_pages(list_path)} if owner else {}
    n = 0
    for locale, attrs in wanted.items():
        cur = have.get(locale)
        if cur and all(cur["attributes"].get(k) == v for k, v in attrs.items()):
            continue
        if cur and cur["attributes"].get("state") in ("ACTIVE", "APPROVED"):
            # 승인된 상품의 승인된 이름은 API 로 못 고친다(409 UNMODIFIABLE) — 웹에서 사람이 한다.
            print(f"  ⚠️ 웹에서: {label} {locale} 이름을 '{attrs['name']}' 로 (승인된 이름은 API 로 못 고친다)")
            continue
        n += 1
        print(f"  {'고침' if cur else '새로'} {label} {locale}: {attrs['name']}")
        if not apply:
            continue
        if cur:
            call("PATCH", f"/v1/{res}/{cur['id']}", {"data": {"type": res, "id": cur["id"], "attributes": attrs}})
        else:
            call("POST", f"/v1/{res}", {"data": {"type": res, "attributes": {"locale": locale, **attrs},
                                                 "relationships": {rel: {"data": {"type": rel_type, "id": owner}}}}})
    return n


def sync_review_note(kind, item, note, apply):
    if (item["attributes"].get("reviewNote") or "") == note:
        return 0
    print(f"  심사 메모 {item['attributes']['productId']}")
    if apply:
        res, path = ("inAppPurchases", f"/v2/inAppPurchases/{item['id']}") if kind == "iap" \
            else ("subscriptions", f"/v1/subscriptions/{item['id']}")
        call("PATCH", path, {"data": {"type": res, "id": item["id"], "attributes": {"reviewNote": note}}})
    return 1


def all_territories():
    return [{"type": "territories", "id": t["id"]} for t in all_pages("/v1/territories?limit=200")]


def iap_point(iap_id, price):
    return next(p["id"] for p in all_pages(f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200")
                if p["attributes"]["customerPrice"] == price)


def iap_usa_prices(iap_id):
    """미국의 수동 가격들: [(값, 시작일, 끝일)]"""
    sid = call("GET", f"/v2/inAppPurchases/{iap_id}/iapPriceSchedule")["data"]["id"]
    r = call("GET", f"/v1/inAppPurchasePriceSchedules/{sid}/manualPrices?include=inAppPurchasePricePoint,territory&limit=200")
    pts = {i["id"]: i["attributes"]["customerPrice"] for i in r.get("included", []) if i["type"] == "inAppPurchasePricePoints"}
    return [(pts[p["relationships"]["inAppPurchasePricePoint"]["data"]["id"]], p["attributes"].get("startDate"),
             p["attributes"].get("endDate"))
            for p in r["data"] if p["relationships"]["territory"]["data"]["id"] == "USA"]


def set_iap_prices(iap_id, plan):
    """plan: [(미국 값, 시작일 또는 None, 끝일 또는 None)] — 미국 기준, 다른 지역은 애플 환산."""
    refs, included = [], []
    for i, (price, start, end) in enumerate(plan):
        ref = f"${{p{i}}}"
        refs.append({"type": "inAppPurchasePrices", "id": ref})
        included.append({"type": "inAppPurchasePrices", "id": ref, "attributes": {"startDate": start, "endDate": end},
                         "relationships": {"inAppPurchasePricePoint": {"data": {
                             "type": "inAppPurchasePricePoints", "id": iap_point(iap_id, price)}}}})
    call("POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules", "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": refs}}},
        "included": included})


def create_iap(pid, kind, price):
    print(f"  새 상품 {pid} ({kind}, ${price})")
    is_sub = False
    iap = call("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases", "attributes": {
        "name": pid, "productId": pid, "inAppPurchaseType": kind, "reviewNote": review_note(pid, is_sub)},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
    set_iap_prices(iap["id"], [(price, None, None)])
    call("POST", "/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
        "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                          "availableTerritories": {"data": all_territories()}}}})
    return iap


def sync_price_change(item, apply):
    pid = item["attributes"]["productId"]
    new, day = PRICE_CHANGES[pid]
    prices = iap_usa_prices(item["id"])
    import datetime
    if day <= datetime.date.today().isoformat():
        # 그날이 이미 왔으면 지금 값을 새 값 하나로 바꾼다(지난 날짜는 일정에 넣을 수 없다)
        if [(p, s) for p, s, _ in prices] == [(new, None)]:
            return 0
        print(f"  평생 값 {pid}: 지금부터 ${new}")
        if apply:
            set_iap_prices(item["id"], [(new, None, None)])
        return 1
    if any(p == new and s == day for p, s, _ in prices):
        return 0
    now = next((p for p, s, e in prices if s is None), prices[0][0] if prices else None)
    print(f"  평생 값 {pid}: ${now} → {day} 부터 ${new}")
    if apply:
        set_iap_prices(item["id"], [(now, None, day), (new, day, None)])
    return 1


SHOTS = os.path.join(HERE, "..", "docs", "screenshots", "iap-review")


def sync_review_shot(kind, item, apply):
    """kind: iap | sub. 이미 올린 이미지가 있으면 그대로 둔다."""
    import hashlib
    import urllib.request
    pid = item["attributes"]["productId"]
    path = os.path.join(SHOTS, f"{pid}.png")
    if not os.path.exists(path):
        return 0
    res, rel, rel_type, get = {
        "iap": ("inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", "inAppPurchases",
                f"/v2/inAppPurchases/{item['id']}/appStoreReviewScreenshot"),
        "sub": ("subscriptionAppStoreReviewScreenshots", "subscription", "subscriptions",
                f"/v1/subscriptions/{item['id']}/appStoreReviewScreenshot"),
    }[kind]
    if call("GET", get).get("data"):
        return 0
    print(f"  심사 이미지 {pid}")
    if not apply:
        return 1
    data = open(path, "rb").read()
    r = call("POST", f"/v1/{res}", {"data": {"type": res,
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {rel: {"data": {"type": rel_type, "id": item["id"]}}}}})["data"]
    for op in r["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                     headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(req).read()
    call("PATCH", f"/v1/{res}/{r['id']}", {"data": {"type": res, "id": r["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return 1


def ensure_group(apply):
    groups = all_pages(f"/v1/apps/{APP_ID}/subscriptionGroups?limit=50")
    if groups:
        return groups[0]
    print(f"  새 구독 묶음 {GROUP_NAME}")
    if not apply:
        return None
    return call("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups",
        "attributes": {"referenceName": GROUP_NAME},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]


def create_subscription(group, pid, price, level):
    print(f"  새 구독 {pid} (연, ${price}, 단계 {level})")
    sub = call("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
        "name": pid, "productId": pid, "familySharable": False, "subscriptionPeriod": "ONE_YEAR",
        "reviewNote": review_note(pid, True), "groupLevel": level},
        "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group["id"]}}}}})["data"]
    call("POST", "/v1/subscriptionAvailabilities", {"data": {
        "type": "subscriptionAvailabilities", "attributes": {"availableInNewTerritories": True},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}},
                          "availableTerritories": {"data": all_territories()}}}})
    usa = next(p for p in all_pages(f"/v1/subscriptions/{sub['id']}/pricePoints?filter[territory]=USA&limit=200")
               if p["attributes"]["customerPrice"] == price)
    points = {"USA": usa["id"]}
    for p in all_pages(f"/v1/subscriptionPricePoints/{usa['id']}/equalizations?include=territory&limit=200"):
        points.setdefault(p["relationships"]["territory"]["data"]["id"], p["id"])
    from concurrent.futures import ThreadPoolExecutor

    def post(tp):
        t, point = tp
        call("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices",
            "attributes": {"preserveCurrentPrice": False, "startDate": None},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}},
                              "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point}},
                              "territory": {"data": {"type": "territories", "id": t}}}}})
    with ThreadPoolExecutor(6) as ex:
        list(ex.map(post, points.items()))
    print(f"    값 {len(points)}개 지역")
    return sub


def sync_first_year(sub, usa_price, apply):
    have = call("GET", f"/v1/subscriptions/{sub['id']}/introductoryOffers?limit=1")["data"]
    if have:
        return 0
    pid = sub["attributes"]["productId"]
    avail = call("GET", f"/v1/subscriptions/{sub['id']}/subscriptionAvailability")["data"]["id"]
    sold = {t["id"] for t in all_pages(f"/v1/subscriptionAvailabilities/{avail}/availableTerritories?limit=200")}
    print(f"  첫 해 할인 {pid}: ${usa_price} · {len(sold)}개 지역")
    if not apply:
        return 1
    usa = next(p for p in all_pages(f"/v1/subscriptions/{sub['id']}/pricePoints?filter[territory]=USA&limit=200")
               if p["attributes"]["customerPrice"] == usa_price)
    points = {"USA": usa["id"]}
    for p in all_pages(f"/v1/subscriptionPricePoints/{usa['id']}/equalizations?include=territory&limit=200"):
        points[p["relationships"]["territory"]["data"]["id"]] = p["id"]
    for t in sorted(sold):
        if t not in points:
            print(f"    ⚠️ {t}: 같은 값 환산이 없어 건너뜀")
            continue
        call("POST", "/v1/subscriptionIntroductoryOffers", {"data": {
            "type": "subscriptionIntroductoryOffers",
            "attributes": {"duration": "ONE_YEAR", "offerMode": "PAY_UP_FRONT", "numberOfPeriods": 1, "startDate": None},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}},
                              "territory": {"data": {"type": "territories", "id": t}},
                              "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": points[t]}}}}})
    return 1


def main():
    apply = "--apply" in sys.argv
    rows, subs, brands, errors = load_table()
    if errors:
        sys.exit("❌ 표가 길이 제한을 넘는다\n" + "\n".join(errors))
    print(f"✅ 표 검사 통과: 상품 {len(rows)}개 · 언어 {len(next(iter(rows.values())))}개")
    if "--check" in sys.argv:
        return

    n = 0
    iaps = {x["attributes"]["productId"]: x for x in all_pages(f"/v1/apps/{APP_ID}/inAppPurchasesV2?limit=200")}

    # 1. 없는 평생 · 선물
    for pid, price in LIFETIMES.items():
        if pid not in iaps:
            n += 1
            if apply:
                iaps[pid] = create_iap(pid, "NON_CONSUMABLE", price)
            else:
                print(f"  새 상품 {pid} (비소모성, ${price})")
    for gift, grants in GIFTS.items():
        if gift not in iaps:
            n += 1
            price = LIFETIMES[grants]
            if apply:
                iaps[gift] = create_iap(gift, "CONSUMABLE", price)
            else:
                print(f"  새 상품 {gift} (소모성, 값은 {grants} 와 같은 ${price})")

    # 2·3. 이름 · 설명 · 심사 메모 · 평생 값 올리기
    for pid, item in iaps.items():
        if pid in rows:
            n += sync_localizations("iap", item["id"], rows[pid], apply, pid)
            n += sync_review_note("iap", item, review_note(pid, False), apply)
        if pid in PRICE_CHANGES:
            n += sync_price_change(item, apply)
        n += sync_review_shot("iap", item, apply)

    # 연 구독
    group = ensure_group(apply)
    if group is None:
        n += 1
        for pid, (price, level) in SUBSCRIPTIONS.items():
            print(f"  새 구독 {pid} (연, ${price}, 단계 {level})")
            n += 1
    else:
        n += sync_localizations("group", group["id"], {loc: {"name": b} for loc, b in brands.items()}, apply, "구독 묶음")
        have = {s["attributes"]["productId"]: s
                for s in all_pages(f"/v1/subscriptionGroups/{group['id']}/subscriptions?limit=50")}
        for pid, (price, level) in SUBSCRIPTIONS.items():
            if pid not in have:
                n += 1
                if apply:
                    have[pid] = create_subscription(group, pid, price, level)
                else:
                    print(f"  새 구독 {pid} (연, ${price}, 단계 {level})")
                    continue
            s = have[pid]
            n += sync_localizations("sub", s["id"], rows[pid], apply, pid)
            n += sync_review_note("sub", s, review_note(pid, True), apply)
            if pid in FIRST_YEAR:
                n += sync_first_year(s, FIRST_YEAR[pid], apply)
            n += sync_review_shot("sub", s, apply)

    print(f"{'✅ 올림' if apply else '📝 바뀔 것 (--apply 로 올린다)'}: {n}건")


if __name__ == "__main__":
    main()
