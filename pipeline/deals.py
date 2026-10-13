"""Turning raw prices + promotions into ranked deals."""
from __future__ import annotations

import re
from dataclasses import dataclass

from parse import Item, PromoItem, Promotion

MIN_EXPORT_PCT = 10.0  # promos below this are not exported at all
RATE_TOLERANCE = 5.0  # max allowed gap between our % and the chain's DiscountRate


# ---------------------------------------------------------------- unit price
def unit_basis(item: Item) -> tuple[str, float] | None:
    """Return (unit, amount) so that price / amount = price per unit.

    unit is "kg", "l" or "unit"; None when unknown.
    """
    uom = item.unit_of_measure
    q = item.quantity
    if item.weighted or uom == "קילוגרם":
        # weighted items are priced per kg; packaged kg items have Quantity in kg
        if item.weighted:
            return ("kg", 1.0)
        return ("kg", q) if 0.005 <= q <= 50 else None
    if q <= 0:
        return None
    if uom == "100 גרם":
        kg = q / 1000
        return ("kg", kg) if 0.001 <= kg <= 50 else None
    if uom == "100 מיליליטר":
        lit = q / 1000
        return ("l", lit) if 0.001 <= lit <= 50 else None
    if uom == "ליטר":
        return ("l", q) if 0.01 <= q <= 50 else None
    if uom == "יחידות":
        return ("unit", q) if 1 <= q <= 500 else None
    return None


def per_unit(price: float, basis: tuple[str, float] | None) -> float | None:
    if not basis or basis[1] <= 0:
        return None
    return round(price / basis[1], 2)


# ---------------------------------------------------------------- tags
MIN_BASKET_RE = re.compile(r"מעל\s*(\d+)")
LIMIT_RE = re.compile(r"מוגבל\s*ל\s*-?\s*(\d+)|(?:^|\s)מו\s*(\d+)(?!\d)")


def promo_tags(p: Promotion) -> dict:
    d = p.description
    tags: list[str] = []
    info: dict = {}
    club = p.club.strip()
    if club and club != "0":
        tags.append("club")
        info["clubText"] = club
    if p.is_coupon or d.startswith("קופון"):
        tags.append("coupon")
    if "אשראי" in d or (club and "אשראי" in club and "שיווק" not in club):
        tags.append("credit")
    if "מתנה" in d:
        tags.append("gift")
    if "ביטוח" in d:
        tags.append("insurance")
    gmin = max((i.group_min_purchase for i in p.items), default=0.0)
    m = MIN_BASKET_RE.search(d)
    if gmin > 0 or m or any(i.reward_type == "0" for i in p.items):
        tags.append("minBasket")
        if gmin > 0:
            info["minBasket"] = gmin
        elif m:
            info["minBasket"] = float(m.group(1))
    limit = p.redemption_limit
    if not limit:
        m = LIMIT_RE.search(d)
        if m:
            limit = m.group(1) or m.group(2)
    if limit and limit.isdigit() and int(limit) > 0:
        tags.append("limit")
        info["limit"] = int(limit)
    return {"tags": tags, **info}


# ---------------------------------------------------------------- computation
@dataclass
class ItemDeal:
    code: str
    name: str
    regular: float
    promo_unit: float  # effective price for one unit (or per kg when weighted)
    pct: float
    save: float
    buy_qty: float
    unit: str | None
    regular_per_unit: float | None
    promo_per_unit: float | None
    complex: bool


def compute_item(pi: PromoItem, item: Item) -> ItemDeal | None:
    bp = item.price
    dp = pi.discounted_price
    mq = pi.min_qty
    rt = pi.reward_type
    if bp <= 0:
        return None
    complex_ = False
    weighted = pi.weighted or item.weighted or 0 < mq < 1
    if weighted:
        buy_qty = 1.0
        unit_price = dp
    elif mq > 50:
        # MinQty used as a purchase threshold (e.g. "buy for 59.90 get X") - not computable
        buy_qty = 1.0
        unit_price = bp
        complex_ = True
    else:
        buy_qty = max(mq, 1.0)
        if rt == "2" and buy_qty >= 2:
            # "second at half price" style: DiscountedPrice applies to one of the units
            unit_price = (bp * (buy_qty - 1) + dp) / buy_qty
        else:
            unit_price = dp / buy_qty
    if dp <= 0 and not complex_:
        complex_ = True
        unit_price = bp
    pct = round(100 * (1 - unit_price / bp), 1)
    if not complex_:
        if pct <= 0 or pct >= 99.5:
            complex_ = True
        elif rt != "2" and pi.discount_rate > 0 and abs(pct - pi.discount_rate) > RATE_TOLERANCE:
            complex_ = True
    basis = unit_basis(item)
    return ItemDeal(
        code=item.code,
        name=item.name,
        regular=bp,
        promo_unit=round(unit_price, 2),
        pct=pct if not complex_ else 0.0,
        save=round(bp - unit_price, 2) if not complex_ else 0.0,
        buy_qty=buy_qty,
        unit=basis[0] if basis else None,
        regular_per_unit=per_unit(bp, basis),
        promo_per_unit=per_unit(unit_price, basis) if not complex_ else None,
        complex=complex_,
    )


def build_deals(
    promos: list[Promotion],
    items: dict[str, Item],
    categorize,
    first_seen: dict[str, str],
    today: str,
) -> list[dict]:
    out = []
    for p in promos:
        computed: list[ItemDeal] = []
        seen_codes = set()
        for pi in p.items:
            if pi.code in seen_codes:
                continue
            item = items.get(pi.code)
            if not item:
                continue
            seen_codes.add(pi.code)
            d = compute_item(pi, item)
            if d:
                computed.append(d)
        if not computed:
            continue
        good = [d for d in computed if not d.complex]
        best_pct = max((d.pct for d in good), default=0.0)
        best_save = max((d.save for d in good), default=0.0)
        is_complex = not good
        if not is_complex and best_pct < MIN_EXPORT_PCT:
            continue
        if is_complex and not (p.description.startswith("קופון") or any(pi.reward_type == "0" for pi in p.items)):
            # keep complex promos only when they look intentional (coupons, basket conditions);
            # the rest are almost always data errors
            if all(pi.min_qty <= 50 for pi in p.items):
                continue
        meta = promo_tags(p)
        if is_complex:
            meta["tags"].append("complex")
        computed.sort(key=lambda d: (d.complex, -d.pct, -d.save))
        # order categories by how many items in the promo carry them (best item breaks ties),
        # so cats[0] is the promo's primary category
        counts: dict[str, int] = {}
        for d in computed:
            for c in categorize(d.name):
                counts[c] = counts.get(c, 0) + 1
        best_cats = categorize(computed[0].name)
        order = {c["id"]: i for i, c in enumerate(getattr(categorize, "cats", []))}
        cats = sorted(counts, key=lambda c: (-counts[c], c not in best_cats, order.get(c, 999)))
        out.append(
            {
                "id": p.id,
                "desc": p.description,
                "start": p.start[:10],
                "end": p.end[:10],
                "firstSeen": first_seen.get(p.id, today),
                "pct": best_pct,
                "save": best_save,
                "buyQty": computed[0].buy_qty,
                "cats": cats,
                **meta,
                "items": [
                    {
                        "code": d.code,
                        "name": d.name,
                        "regular": d.regular,
                        "promo": d.promo_unit,
                        "pct": d.pct,
                        "save": d.save,
                        "unit": d.unit,
                        "regPU": d.regular_per_unit,
                        "promoPU": d.promo_per_unit,
                        **({"complex": True} if d.complex else {}),
                    }
                    for d in computed
                ],
            }
        )
    out.sort(key=lambda x: (-x["pct"], -x["save"]))
    return out
