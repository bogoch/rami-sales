"""Store coordinates: manual overrides > cached geocode > Nominatim lookup (cached)."""
from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

DATA = Path(__file__).parent / "data"
CACHE = DATA / "store_coords.json"
OVERRIDES = DATA / "store_overrides.json"
UA = "rami-sales/0.1 (github.com/bogoch/rami-sales)"


def _load(p: Path) -> dict:
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def _nominatim(q: str) -> tuple[float, float] | None:
    url = "https://nominatim.openstreetmap.org/search?" + urllib.parse.urlencode(
        {"q": q, "format": "json", "limit": 1, "countrycodes": "il,ps", "accept-language": "he"}
    )
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            res = json.loads(r.read().decode())
    except Exception as e:  # noqa: BLE001
        print(f"  geocode error for {q!r}: {e!r}")
        return None
    finally:
        time.sleep(1.1)  # Nominatim usage policy: max 1 req/s
    if not res:
        return None
    return float(res[0]["lat"]), float(res[0]["lon"])


def resolve(stores, max_lookups: int = 40) -> dict[str, dict]:
    """Return {store_id: {lat, lon, src}} and update the cache file."""
    overrides = _load(OVERRIDES)
    cache = _load(CACHE)
    out: dict[str, dict] = {}
    lookups = 0
    for s in stores:
        if s.id in overrides:
            out[s.id] = {**overrides[s.id], "src": "manual"}
            continue
        key = f"{s.id}|{s.name}|{s.address}|{s.city}"
        hit = cache.get(s.id)
        if hit and hit.get("key") == key:
            if hit.get("lat") is not None:
                out[s.id] = {"lat": hit["lat"], "lon": hit["lon"], "src": hit.get("src", "geocode")}
            continue
        if lookups >= max_lookups:
            continue
        queries = []
        if s.address and s.city:
            queries.append(f"{s.address}, {s.city}")
        queries.append(f"רמי לוי {s.name}")
        if s.city:
            queries.append(f"רמי לוי {s.city}")
        if s.address:
            queries.append(s.address)
        found = None
        for q in queries:
            lookups += 1
            found = _nominatim(q)
            if found:
                break
        cache[s.id] = {"key": key, "lat": found[0] if found else None, "lon": found[1] if found else None, "src": "geocode"}
        if found:
            out[s.id] = {"lat": found[0], "lon": found[1], "src": "geocode"}
    CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    return out
