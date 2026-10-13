"""Daily build: download Rami Levy transparency files and publish static JSON.

Output (in --out):
  meta.json                 generation info
  categories.json           category list for the app
  stores.json               all stores with coordinates and deal counts
  deals/<storeId>.json      ranked deals (>= MIN_EXPORT_PCT) for one store
  catalog/<storeId>.json    every product in the store (compact rows) for search / tracking / barcode

History (in --history, persisted on the `history` branch):
  <storeId>.json.gz         {"prices": {code: {YYYYMMDD: price}}, "promos": {promoId: firstSeen}}
"""
from __future__ import annotations

import argparse
import gzip
import json
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).parent))

import geocode  # noqa: E402
import portal  # noqa: E402
from categories import Categorizer  # noqa: E402
from deals import MIN_EXPORT_PCT, build_deals, per_unit, unit_basis  # noqa: E402
from parse import parse_prices, parse_promos, parse_stores  # noqa: E402

TZ = ZoneInfo("Asia/Jerusalem")
HISTORY_DAYS = 30
SCHEMA = 1


def dump(path: Path, obj) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    path.write_text(data, encoding="utf-8")
    return len(data.encode())


def load_history(path: Path) -> dict | None:
    try:
        return json.loads(gzip.decompress(path.read_bytes()))
    except FileNotFoundError:
        return None


def save_history(path: Path, hist: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gzip.compress(json.dumps(hist, separators=(",", ":")).encode(), 9))


def process_store(store_id, price_file, promo_file, dl, cat, out, hist_dir, today, generated):
    t0 = time.time()
    items = parse_prices(dl.get(price_file.name))
    promos = parse_promos(dl.get(promo_file.name)) if promo_file else []

    # ---- history: daily regular price + first-seen date per promotion
    hpath = hist_dir / f"{store_id}.json.gz"
    hist = load_history(hpath)
    first_run = hist is None
    hist = hist or {"prices": {}, "promos": {}}
    cutoff = (datetime.strptime(today, "%Y%m%d") - timedelta(days=HISTORY_DAYS)).strftime("%Y%m%d")
    prices_h = hist["prices"]
    for code, it in items.items():
        row = prices_h.setdefault(code, {})
        row[today] = it.price
    for code in list(prices_h):
        row = {d: p for d, p in prices_h[code].items() if d > cutoff}
        if row:
            prices_h[code] = row
        else:
            del prices_h[code]
    promos_h = hist["promos"]
    iso_today = f"{today[:4]}-{today[4:6]}-{today[6:]}"
    for p in promos:
        if p.id not in promos_h:
            # On the very first run we don't know what is new; fall back to the promo start date.
            promos_h[p.id] = p.start[:10] if first_run and p.start else iso_today
    active = {p.id for p in promos}
    hist["promos"] = {k: v for k, v in promos_h.items() if k in active}
    save_history(hpath, hist)

    def min30(code):
        row = prices_h.get(code)
        return min(row.values()) if row else None

    # ---- deals
    deals = build_deals(promos, items, cat, hist["promos"], iso_today)
    for d in deals:
        for it in d["items"]:
            m = min30(it["code"])
            if m is not None and m < it["regular"] - 0.01:
                it["min30"] = m
    dump(out / "deals" / f"{store_id}.json", {
        "schema": SCHEMA,
        "store": store_id,
        "generated": generated,
        "source": {"prices": price_file.name, "promos": promo_file.name if promo_file else None},
        "minPct": MIN_EXPORT_PCT,
        "deals": deals,
    })

    # ---- catalog (compact rows) + set of codes currently on promotion
    on_promo: dict[str, str] = {}
    for d in deals:
        for it in d["items"]:
            on_promo.setdefault(it["code"], d["id"])
    rows = []
    for code, it in items.items():
        basis = unit_basis(it)
        m = min30(code)
        rows.append([
            code,
            it.name,
            it.manufacturer,
            it.price,
            basis[0] if basis else None,
            per_unit(it.price, basis),
            list(cat(it.name)),
            m if m is not None and m < it.price - 0.01 else None,
            on_promo.get(code),
        ])
    dump(out / "catalog" / f"{store_id}.json", {
        "schema": SCHEMA,
        "store": store_id,
        "generated": generated,
        "cols": ["code", "name", "manuf", "price", "unit", "perUnit", "cats", "min30", "promoId"],
        "rows": rows,
    })
    # category coverage stats (for tuning categories.json)
    import collections
    cov = collections.Counter(c for row in rows for c in row[6])
    uncat = [row[1] for row in rows if not row[6]]
    words = collections.Counter(w for n in uncat for w in n.split()[:2] if len(w) > 2 and not w[0].isdigit())
    dump(out / "stats" / f"{store_id}.json", {
        "items": len(rows),
        "categorized": len(rows) - len(uncat),
        "perCategory": dict(cov.most_common()),
        "topUncategorizedWords": words.most_common(150),
        "dealsUncategorized": [d["desc"] for d in deals if not d["cats"]][:100],
    })
    good30 = sum(1 for d in deals if d["pct"] >= 30 and d["save"] >= 3)
    return {
        "store": store_id,
        "items": len(items),
        "promos": len(promos),
        "deals": len(deals),
        "good30": good30,
        "secs": round(time.time() - t0, 1),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="site")
    ap.add_argument("--history", default="history")
    ap.add_argument("--stores", help="comma separated store ids or 'all' (default: data/config.json)")
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args()
    out, hist_dir = Path(args.out), Path(args.history)
    now = datetime.now(TZ)
    today = now.strftime("%Y%m%d")
    generated = now.isoformat(timespec="seconds")

    files = portal.list_files()
    print(f"listed {len(files)} files")
    stores_file = max((f for f in files if f.kind == "stores"), key=lambda f: f.ts)
    dl = portal.Downloader()
    stores = parse_stores(dl.get(stores_file.name))
    print(f"stores: {len(stores)} from {stores_file.name}")

    price_files = portal.latest_by_store(files, "pricefull")
    promo_files = portal.latest_by_store(files, "promofull")
    if args.stores:
        wanted_list = args.stores.split(",")
    else:
        wanted_list = json.loads((Path(__file__).parent / "data" / "config.json").read_text(encoding="utf-8"))["stores"]
    wanted = None if "all" in wanted_list else {str(int(x)) for x in wanted_list}
    targets = [s for s in stores if s.id in price_files and (wanted is None or s.id in wanted)]
    print(f"stores with PriceFull: {len(targets)}")

    cat = Categorizer()
    results, failures = {}, []
    with ThreadPoolExecutor(max_workers=args.threads) as ex:
        futs = {
            ex.submit(process_store, s.id, price_files[s.id], promo_files.get(s.id), dl, cat, out, hist_dir, today, generated): s.id
            for s in targets
        }
        for fut in as_completed(futs):
            sid = futs[fut]
            try:
                r = fut.result()
                results[sid] = r
                print(f"  store {sid}: {r}")
            except Exception:  # noqa: BLE001
                failures.append(sid)
                print(f"  store {sid} FAILED")
                traceback.print_exc()

    coords = geocode.resolve([s for s in stores if s.id in results])
    store_rows = []
    for s in stores:
        c = coords.get(s.id, {})
        r = results.get(s.id)
        store_rows.append({
            "id": s.id,
            "name": s.name,
            "address": s.address,
            "city": s.city,
            "lat": c.get("lat"),
            "lon": c.get("lon"),
            "coordSrc": c.get("src"),
            "hasData": r is not None,
            "deals": r["deals"] if r else 0,
            "items": r["items"] if r else 0,
        })
    dump(out / "stores.json", {"schema": SCHEMA, "generated": generated, "defaultStore": "23", "stores": store_rows})
    dump(out / "categories.json", {"schema": SCHEMA, "categories": cat.public()})
    dump(out / "meta.json", {
        "schema": SCHEMA,
        "generated": generated,
        "date": today,
        "storesFile": stores_file.name,
        "storesOk": len(results),
        "storesFailed": failures,
    })
    (out / "index.html").write_text(
        "<!doctype html><meta charset=utf-8><title>rami-sales data</title>"
        f"<p dir=rtl>נתוני מבצעים רמי לוי · עודכן {generated} · {len(results)} סניפים."
        " <a href=stores.json>stores.json</a> · <a href=deals/23.json>deals/23.json</a></p>",
        encoding="utf-8",
    )
    located = sum(1 for r in store_rows if r["lat"] is not None)
    print(f"done: {len(results)} ok, {len(failures)} failed, {located}/{len(store_rows)} stores located")
    # fail the run (so GitHub emails) only if most stores failed
    return 1 if len(results) < max(1, len(targets) // 2) else 0


if __name__ == "__main__":
    sys.exit(main())
