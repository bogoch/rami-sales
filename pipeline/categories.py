"""Keyword-based product categorization (the transparency files have no categories)."""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

DATA = Path(__file__).parent / "data" / "categories.json"
PREFIX = "[הובלמשכ]"
NON_FOOD_GROUPS = {"בית וטיפוח"}


def _term_re(term: str) -> str:
    return rf"(?:^|[\s/\-(\"'.,])(?:{PREFIX})?{re.escape(term)}"


def load(path: Path = DATA) -> list[dict]:
    cats = json.loads(path.read_text(encoding="utf-8"))["categories"]
    for c in cats:
        c["_inc"] = re.compile("|".join(_term_re(t) for t in c["include"])) if c["include"] else None
        starts = c.get("includeStart", [])
        c["_start"] = re.compile("|".join(rf"^ {re.escape(t)}" for t in starts)) if starts else None
        c["_exc"] = re.compile("|".join(_term_re(t) for t in c["exclude"])) if c["exclude"] else None
    return cats


class Categorizer:
    def __init__(self, path: Path = DATA) -> None:
        self.cats = load(path)

    @lru_cache(maxsize=200_000)
    def __call__(self, name: str) -> tuple[str, ...]:
        text = " " + " ".join(name.replace("״", '"').replace("׳", "'").split()) + " "
        out = []
        for c in self.cats:
            hit = (c["_inc"] is not None and c["_inc"].search(text)) or (c["_start"] is not None and c["_start"].search(text))
            if not hit:
                continue
            if c["_exc"] is not None and c["_exc"].search(text):
                continue
            out.append(c)
        # Non-food wins: a shower gel "with grapefruit scent" is not fruit.
        non_food = [c for c in out if c["group"] in NON_FOOD_GROUPS]
        if non_food:
            out = non_food
        return tuple(c["id"] for c in out)

    def public(self) -> list[dict]:
        return [{"id": c["id"], "name": c["name"], "group": c["group"]} for c in self.cats]
