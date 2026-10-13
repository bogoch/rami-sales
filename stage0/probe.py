"""Stage 0 probe: can we reach Rami Levy's price-transparency files, and what do they look like?

Connects to the Cerberus FTPS portal (user RamiLevi, empty password), lists files,
finds the Gush Etzion junction store, downloads Stores / PriceFull / PromoFull,
and writes a structural report to stage0/out/report.md plus small samples.
"""
import collections
import gzip
import io
import json
import re
import socket
import sys
import time
import zipfile
from ftplib import FTP_TLS
from pathlib import Path
import xml.etree.ElementTree as ET

HOST = "url.retail.publishedprices.co.il"
USER = "RamiLevi"
OUT = Path(__file__).parent / "out"
OUT.mkdir(parents=True, exist_ok=True)
report = []


def log(line=""):
    print(line, flush=True)
    report.append(line)


def connect():
    ftp = FTP_TLS(HOST, USER, "", timeout=120)
    ftp.trust_server_pasv_ipv4_address = True
    ftp.prot_p()
    return ftp


def list_files(ftp):
    try:
        return [(n, int(f.get("size", 0) or 0)) for n, f in ftp.mlsd() if f.get("type") == "file"]
    except Exception:
        return [(n, 0) for n in ftp.nlst()]


def download(name):
    for attempt in range(4):
        try:
            ftp = connect()
            buf = io.BytesIO()
            ftp.retrbinary("RETR " + name, buf.write)
            ftp.quit()
            return decompress(buf.getvalue())
        except Exception as e:  # noqa: BLE001
            log(f"  download retry {attempt + 1} for {name}: {e!r}")
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(f"failed to download {name}")


def decompress(data):
    if data[:2] == b"\x1f\x8b":
        return gzip.decompress(data)
    if data[:2] == b"PK":
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            return z.read(z.namelist()[0])
    return data


def parse(xml_bytes):
    # Some chains ship UTF-16 or BOM-prefixed files.
    return ET.fromstring(xml_bytes)


def strip(tag):
    return tag.split("}")[-1]


def element_to_dict(el):
    d = {}
    for child in el:
        key = strip(child.tag)
        if len(child):
            d.setdefault(key, []).append(element_to_dict(child))
        else:
            d[key] = (child.text or "").strip()
    return d


def find_repeating(root, min_count=5):
    """Return (tag, elements) for the most common element that has children."""
    counts = collections.Counter()
    for el in root.iter():
        if len(el):
            counts[strip(el.tag)] += 1
    for tag, n in counts.most_common():
        if n >= min_count:
            return tag, [e for e in root.iter() if strip(e.tag) == tag]
    return None, []


def main():
    t0 = time.time()
    log("# Stage 0 probe report")
    log()
    try:
        ip = socket.gethostbyname(HOST)
        log(f"- DNS {HOST} -> {ip}")
        ftp = connect()
        log(f"- FTPS login OK as {USER} ({time.time() - t0:.1f}s)")
    except Exception as e:  # noqa: BLE001
        log(f"- **CONNECTION FAILED**: {e!r}")
        (OUT / "report.md").write_text("\n".join(report), encoding="utf-8")
        sys.exit(1)

    files = list_files(ftp)
    ftp.quit()
    log(f"- Files listed: {len(files)}")
    kinds = collections.Counter(re.sub(r"[0-9].*", "", n.lower()) for n, _ in files)
    log(f"- File kinds: {dict(kinds)}")
    (OUT / "file_list.txt").write_text("\n".join(f"{n}\t{s}" for n, s in sorted(files)), encoding="utf-8")

    # --- Stores
    stores_files = sorted([n for n, _ in files if n.lower().startswith("store")])
    log(f"- Stores files: {stores_files[-3:]}")
    if not stores_files:
        log("- **No Stores file found**")
    stores_root = parse(download(stores_files[-1]))
    tag, store_els = find_repeating(stores_root, 3)
    stores = [element_to_dict(e) for e in store_els]
    log(f"- Stores parsed: {len(stores)} (element <{tag}>)")
    (OUT / "stores.json").write_text(json.dumps(stores, ensure_ascii=False, indent=1), encoding="utf-8")
    if stores:
        log(f"- Store fields: {list(stores[0].keys())}")

    def store_text(s):
        return " ".join(str(v) for v in s.values() if isinstance(v, str))

    gush = [s for s in stores if re.search(r"גוש|עציון|אפרת", store_text(s))]
    log("- Candidate Gush Etzion stores:")
    for s in gush:
        log(f"  - {json.dumps(s, ensure_ascii=False)}")
    store_id = None
    if gush:
        sid = gush[0].get("StoreId") or gush[0].get("StoreID") or gush[0].get("storeid")
        store_id = str(int(sid)) if sid and sid.isdigit() else sid
    log(f"- Chosen store id: {store_id}")
    if not store_id:
        (OUT / "report.md").write_text("\n".join(report), encoding="utf-8")
        return

    def latest(prefix):
        pat = re.compile(rf"^{prefix}\d+-0*{store_id}-", re.I)
        cands = sorted(n for n, _ in files if pat.match(n))
        return cands[-1] if cands else None

    # --- PriceFull
    log()
    log("## PriceFull")
    pf = latest("pricefull")
    log(f"- file: {pf} ({dict(files).get(pf)} bytes compressed)")
    prices = {}
    if pf:
        root = parse(download(pf))
        tag, els = find_repeating(root)
        items = [element_to_dict(e) for e in els]
        log(f"- items: {len(items)} (element <{tag}>)")
        log(f"- fields: {list(items[0].keys()) if items else []}")
        for k in ("UnitQty", "UnitOfMeasure", "QtyInPackage", "bIsWeighted", "ItemType", "AllowDiscount", "ItemStatus"):
            vals = collections.Counter(i.get(k, "<missing>") for i in items)
            log(f"- {k} top values: {vals.most_common(8)}")
        with_unit_price = sum(1 for i in items if i.get("UnitOfMeasurePrice") not in (None, "", "0", "0.00"))
        log(f"- items with UnitOfMeasurePrice: {with_unit_price}/{len(items)}")
        (OUT / "pricefull_sample.json").write_text(json.dumps(items[:40], ensure_ascii=False, indent=1), encoding="utf-8")
        prices = {i.get("ItemCode"): i for i in items}

    # --- PromoFull
    log()
    log("## PromoFull")
    pr = latest("promofull")
    log(f"- file: {pr} ({dict(files).get(pr)} bytes compressed)")
    if pr:
        root = parse(download(pr))
        promos = [element_to_dict(e) for e in root.iter() if strip(e.tag) == "Promotion"]
        if not promos:
            tag, els = find_repeating(root)
            promos = [element_to_dict(e) for e in els]
        log(f"- promotions: {len(promos)}")
        fields = collections.Counter(k for p in promos for k in p)
        log(f"- fields (count): {fields.most_common()}")
        for k in ("RewardType", "DiscountType", "MinQty", "MaxQty", "AllowMultipleDiscounts", "IsWeightedPromo",
                  "ClubId", "AdditionalIsCoupon", "AdditionalGiftCount", "AdditionalIsTotal", "AdditionalMinBasketAmount",
                  "Remarks"):
            vals = collections.Counter(json.dumps(p.get(k, "<missing>"), ensure_ascii=False) for p in promos)
            log(f"- {k} top values: {vals.most_common(8)}")

        def items_of(p):
            out = []
            for grp in p.get("PromotionItems", []):
                for it in grp.get("Item", []):
                    out.append(it)
            return out

        n_items = collections.Counter(min(len(items_of(p)), 10) for p in promos)
        log(f"- items per promo (capped 10): {sorted(n_items.items())}")
        (OUT / "promofull_sample.json").write_text(json.dumps(promos[:60], ensure_ascii=False, indent=1), encoding="utf-8")

        # quick look at discounts for single-item, single-qty promos
        log()
        log("## Quick discount check (single item promos)")
        rows = []
        for p in promos:
            its = items_of(p)
            if len(its) != 1:
                continue
            code = its[0].get("ItemCode")
            base = prices.get(code)
            try:
                dp = float(p.get("DiscountedPrice") or 0)
                mq = float(p.get("MinQty") or 1) or 1
                bp = float(base.get("ItemPrice")) if base else 0
            except ValueError:
                continue
            if bp <= 0 or dp <= 0:
                continue
            unit = dp / mq if mq > 1 and dp > bp else dp
            pct = round(100 * (1 - unit / bp), 1)
            rows.append((pct, base.get("ItemName"), bp, dp, mq, p.get("PromotionDescription"), p.get("ClubId")))
        rows.sort(reverse=True)
        log(f"- computable: {len(rows)}; >=30%: {sum(r[0] >= 30 for r in rows)}; >=20%: {sum(r[0] >= 20 for r in rows)}")
        for r in rows[:25]:
            log(f"  - {r[0]}% | {r[1]} | regular {r[2]} | promo {r[3]} x{r[4]} | {r[5]} | club {r[6]}")
        for r in rows[len(rows) // 2: len(rows) // 2 + 5]:
            log(f"  - (median-ish) {r[0]}% | {r[1]} | {r[2]} -> {r[3]} x{r[4]} | {r[5]}")

    log()
    log(f"Total time: {time.time() - t0:.1f}s")
    (OUT / "report.md").write_text("\n".join(report), encoding="utf-8")


if __name__ == "__main__":
    main()
