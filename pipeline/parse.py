"""Parsing of the price-transparency XML files into plain Python structures."""
from __future__ import annotations

import io
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field


def _tag(el: ET.Element) -> str:
    return el.tag.rsplit("}", 1)[-1]


def _text(el: ET.Element | None, name: str, default: str = "") -> str:
    if el is None:
        return default
    for child in el:
        if _tag(child) == name:
            return (child.text or "").strip()
    return default


def _num(s: str, default: float = 0.0) -> float:
    try:
        return float(s.replace(",", "")) if s else default
    except ValueError:
        return default


def _iter(xml: bytes, wanted: str):
    """Stream elements named `wanted`, clearing them after use."""
    for _, el in ET.iterparse(io.BytesIO(xml), events=("end",)):
        if _tag(el) == wanted:
            yield el
            el.clear()


# ---------------------------------------------------------------- stores
@dataclass
class Store:
    id: str
    name: str
    address: str
    city: str
    zip: str
    type: str


def parse_stores(xml: bytes) -> list[Store]:
    out = []
    for el in _iter(xml, "Store"):
        sid = _text(el, "StoreID") or _text(el, "StoreId")
        if not sid.isdigit():
            continue
        city = _text(el, "City")
        out.append(
            Store(
                id=str(int(sid)),
                name=_text(el, "StoreName"),
                address=_text(el, "Address"),
                city="" if city in ("0", "") else city,
                zip=_text(el, "ZIPCode"),
                type=_text(el, "StoreType"),
            )
        )
    return out


# ---------------------------------------------------------------- prices
@dataclass
class Item:
    code: str
    name: str
    manufacturer: str
    price: float
    quantity: float
    unit_of_measure: str
    weighted: bool
    updated: str


def parse_prices(xml: bytes) -> dict[str, Item]:
    out: dict[str, Item] = {}
    for el in _iter(xml, "Item"):
        code = _text(el, "ItemCode")
        price = _num(_text(el, "ItemPrice"))
        if not code or price <= 0:
            continue
        name = _text(el, "ManufactureItemDescription") or _text(el, "ItemName")
        short = _text(el, "ItemName")
        if len(short) > len(name):
            name = short
        out[code] = Item(
            code=code,
            name=" ".join(name.split()),
            manufacturer=_text(el, "ManufactureName"),
            price=price,
            quantity=_num(_text(el, "Quantity")),
            unit_of_measure=_text(el, "UnitOfMeasure"),
            weighted=_text(el, "bIsWeighted") == "1",
            updated=_text(el, "PriceUpdateTime"),
        )
    return out


# ---------------------------------------------------------------- promos
@dataclass
class PromoItem:
    code: str
    reward_type: str
    min_qty: float
    discounted_price: float
    discount_rate: float
    weighted: bool
    group_min_purchase: float


@dataclass
class Promotion:
    id: str
    description: str
    start: str
    end: str
    club: str
    is_coupon: bool
    redemption_limit: str
    remarks: str
    items: list[PromoItem] = field(default_factory=list)


def parse_promos(xml: bytes) -> list[Promotion]:
    out = []
    for el in _iter(xml, "Promotion"):
        promo = Promotion(
            id=_text(el, "PromotionID"),
            description=" ".join(_text(el, "PromotionDescription").split()),
            start=_text(el, "PromotionStartDateTime"),
            end=_text(el, "PromotionEndDateTime"),
            club=_text(el, "ClubID") or _text(el, "ClubId"),
            is_coupon=_text(el, "AdditionalIsCoupon") == "1",
            redemption_limit=_text(el, "RedemptionLimit"),
            remarks=_text(el, "Remarks"),
        )
        for group in el.iter():
            if _tag(group) != "Group":
                continue
            gmin = _num(_text(group, "MinPurchaseAmount"))
            for it in group.iter():
                if _tag(it) != "PromotionItem":
                    continue
                code = _text(it, "ItemCode")
                if not code:
                    continue
                promo.items.append(
                    PromoItem(
                        code=code,
                        reward_type=_text(it, "RewardType"),
                        min_qty=_num(_text(it, "MinQty"), 1.0),
                        discounted_price=_num(_text(it, "DiscountedPrice")),
                        discount_rate=_num(_text(it, "DiscountRate")),
                        weighted=_text(it, "bIsWeighted") == "1",
                        group_min_purchase=gmin,
                    )
                )
        if promo.id:
            out.append(promo)
    return out
