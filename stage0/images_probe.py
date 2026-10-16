"""Probe candidate product-image sources by barcode (run in CI)."""
import json, random, urllib.request, pathlib

out = pathlib.Path("imgprobe"); out.mkdir(exist_ok=True)
cat = json.load(urllib.request.urlopen("https://bogoch.github.io/rami-sales/catalog/23.json", timeout=60))
rows = [r for r in cat["rows"] if len(r[0]) == 13 and r[0].startswith("729")]
random.seed(1)
sample = random.sample(rows, 30)
UA = {"User-Agent": "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36"}

def get(url):
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.headers.get("Content-Type"), r.read()
    except urllib.error.HTTPError as e:
        return e.code, None, b""
    except Exception as e:
        return str(e)[:60], None, b""

sources = {
    "rl_small": "https://img.rami-levy.co.il/product/{c}/small.jpg",
    "rl_large": "https://img.rami-levy.co.il/product/{c}/large.jpg",
    "rl_plain": "https://img.rami-levy.co.il/product/{c}/{c}.jpg",
}
report = []
hits = {k: 0 for k in list(sources) + ["off"]}
for i, r in enumerate(sample):
    code, name = r[0], r[1]
    line = [code, name]
    for k, tpl in sources.items():
        st, ct, body = get(tpl.format(c=code))
        ok = st == 200 and ct and ct.startswith("image") and len(body) > 1000
        hits[k] += ok
        line.append(f"{k}:{st}:{ct}:{len(body)}")
        if ok and i < 6:
            (out / f"{k}_{code}.jpg").write_bytes(body)
    st, ct, body = get(f"https://world.openfoodfacts.org/api/v2/product/{code}.json?fields=image_front_small_url")
    url = None
    if st == 200:
        try:
            url = json.loads(body).get("product", {}).get("image_front_small_url")
        except Exception:
            pass
    hits["off"] += bool(url)
    line.append(f"off:{bool(url)}")
    report.append(" | ".join(line))
report.insert(0, f"hits out of {len(sample)}: {hits}")
(out / "report.txt").write_text("\n".join(report), encoding="utf-8")
print("\n".join(report))
