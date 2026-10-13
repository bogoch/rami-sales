import json, sys, tempfile
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1]))
import build
from categories import Categorizer

PRICES = """<?xml version="1.0" encoding="utf-8"?><Root><Items>
<Item><ItemCode>1</ItemCode><ItemName>חלב תנובה 3% שומן 1 ליטר</ItemName><ManufactureName>תנובה</ManufactureName><ManufactureItemDescription>חלב תנובה 3% שומן 1 ליטר</ManufactureItemDescription><Quantity>1.00</Quantity><UnitOfMeasure>ליטר</UnitOfMeasure><bIsWeighted>0</bIsWeighted><ItemPrice>7.20</ItemPrice></Item>
<Item><ItemCode>2</ItemCode><ItemName>גולון עוגיות ללא סוכר</ItemName><Quantity>210</Quantity><UnitOfMeasure>100 גרם</UnitOfMeasure><bIsWeighted>0</bIsWeighted><ItemPrice>17.90</ItemPrice></Item>
<Item><ItemCode>3</ItemCode><ItemName>מלפפון</ItemName><Quantity>1</Quantity><UnitOfMeasure>קילוגרם</UnitOfMeasure><bIsWeighted>1</bIsWeighted><ItemPrice>6.90</ItemPrice></Item>
<Item><ItemCode>4</ItemCode><ItemName>כיסא ים פסים</ItemName><Quantity>1</Quantity><UnitOfMeasure>יחידות</UnitOfMeasure><bIsWeighted>0</bIsWeighted><ItemPrice>19.90</ItemPrice></Item>
<Item><ItemCode>5</ItemCode><ItemName>שמיר רמי לוי</ItemName><Quantity>1</Quantity><UnitOfMeasure>יחידות</UnitOfMeasure><bIsWeighted>0</bIsWeighted><ItemPrice>4.90</ItemPrice></Item>
<Item><ItemCode>6</ItemCode><ItemName>חומוס רמי לוי 1 ק"ג</ItemName><Quantity>1000</Quantity><UnitOfMeasure>100 גרם</UnitOfMeasure><bIsWeighted>0</bIsWeighted><ItemPrice>10.90</ItemPrice></Item>
</Items></Root>"""

def promo(pid, desc, items, club="0", coupon="0", limit="", gmin="0.00"):
    its = "".join(f"<PromotionItem><ItemCode>{c}</ItemCode><RewardType>{rt}</RewardType><MinQty>{mq}</MinQty><DiscountRate>{dr}</DiscountRate><DiscountedPrice>{dp}</DiscountedPrice><bIsWeighted>0</bIsWeighted></PromotionItem>" for c, rt, mq, dp, dr in items)
    return f"""<Promotion><PromotionID>{pid}</PromotionID><PromotionDescription>{desc}</PromotionDescription><PromotionStartDateTime>2026-10-01T00:00:00.000</PromotionStartDateTime><PromotionEndDateTime>2026-10-31T23:59:00.000</PromotionEndDateTime><RedemptionLimit>{limit}</RedemptionLimit><ClubID>{club}</ClubID><AdditionalIsCoupon>{coupon}</AdditionalIsCoupon><Remarks/><Groups><Group><GroupID>1</GroupID><MinPurchaseAmount>{gmin}</MinPurchaseAmount><PromotionItems>{its}</PromotionItems></Group></Groups></Promotion>"""

PROMOS = "<Root><Promotions>" + "".join([
    promo("A", "קופון חלב תנובה קרטון 1לי ב1שח", [("1", "3", "1", "1.00", "86.11")], coupon="1"),
    promo("B", "גולון טווינס השני בחצי", [("2", "2", "2", "8.95", "50")]),
    promo("C", "מלפפון ב3.9 מוגבל ל3", [("3", "3", "0.010", "3.90", "43.48")]),
    promo("D", "פטרוזליה/שמיר 3ב15", [("4", "10", "3", "15", "15.25"), ("5", "10", "3", "15", "-2")]),
    promo("E", "חומוס ב10.50", [("6", "3", "1", "10.50", "3.67")]),
    promo("F", "טחינה מצטרפים", [("1", "3", "1", "5.90", "18.06")], club="(1=מועדון חברתי)", gmin="75.00"),
]) + "</Promotions></Root>"

class FakeDL:
    def get(self, name):
        return (PRICES if name == "p" else PROMOS).encode()

class F:
    def __init__(self, n): self.name = n

def test_build():
    with tempfile.TemporaryDirectory() as d:
        out, hist = Path(d) / "site", Path(d) / "hist"
        r = build.process_store("23", F("p"), F("q"), FakeDL(), Categorizer(), out, hist, "20261013", "x")
        deals = {x["id"]: x for x in json.loads((out / "deals/23.json").read_text())["deals"]}
        assert deals["A"]["pct"] == 86.1 and "coupon" in deals["A"]["tags"], deals["A"]
        assert deals["B"]["pct"] == 25.0, deals["B"]
        assert deals["C"]["pct"] == 43.5 and deals["C"]["limit"] == 3, deals["C"]
        # chair mismatched with the herbs promo is complex; herbs item not computable either (pct ~ -2)... D herbs: 15/3=5 > 4.90 regular -> complex
        assert "D" not in deals or "complex" in deals["D"]["tags"], deals.get("D")
        assert "E" not in deals  # 3.7% -> below export threshold
        assert {"club", "minBasket"} <= set(deals["F"]["tags"]) and deals["F"]["minBasket"] == 75.0, deals["F"]
        assert "milk" in deals["A"]["cats"], deals["A"]["cats"]
        assert deals["A"]["items"][0]["regPU"] == 7.2 and deals["A"]["items"][0]["unit"] == "l"
        cat = json.loads((out / "catalog/23.json").read_text())
        rows = {row[0]: row for row in cat["rows"]}
        assert rows["6"][4] == "kg" and rows["6"][5] == 10.9, rows["6"]
        assert rows["2"][5] == 85.24, rows["2"]
        assert rows["1"][8] == "A" or rows["1"][8] == "F"
        print(r)

def test_categories():
    c = Categorizer()
    assert "milk" in c("חלב תנובה 3% שומן 1 ליטר")
    assert "milk" not in c("שוקו יטבתה")
    assert "choco_milk" in c("שוקו פקק ספורט יטבתה")
    assert "plant_milk" in c("משקה שקדים אלפרו ללא סוכר")
    assert "milk" not in c("משקה שקדים אלפרו")
    assert "vegetables" in c("מלפפון")
    assert "fruit" not in c("מיץ תפוזים פריגת")
    assert "soft_drinks" in c("מיץ תפוזים פריגת")
    assert "cheese" in c("קוטג' תנובה 9% שומן")
    assert "eggs" in c("ביצים L 12 יח")
    assert "alcohol" in c("יין אמירים רזרב רוזה")
    assert "hygiene" in c("שמפו דאב חדש")
    assert "cleaning" in c("נייר טואלט לילי")

if __name__ == "__main__":
    test_build(); test_categories(); print("ok")
