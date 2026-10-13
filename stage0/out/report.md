# Stage 0 probe report

- DNS url.retail.publishedprices.co.il -> 194.90.26.22
- FTPS login OK as RamiLevi (2.4s)
- Files listed: 1339
- File kinds: {'price': 740, 'pricefull': 192, 'promo': 214, 'promofull': 191, 'stores': 2}
- Stores files: ['Stores7290058140886-000-20261011-050500.xml', 'Stores7290058140886-000-20261012-050501.xml']
- Stores parsed: 99 (element <Store>)
- Store fields: ['StoreID', 'BikoretNo', 'StoreType', 'StoreName', 'Address', 'City', 'ZIPCode']
- Candidate Gush Etzion stores:
  - {"StoreID": "023", "BikoretNo": "8", "StoreType": "1", "StoreName": "גוש עציון", "Address": "צומת גוש עציון", "City": "0", "ZIPCode": "9043500"}
- Chosen store id: 23

## PriceFull
- file: PriceFull7290058140886-001-023-20261013-001009.gz (1004119 bytes compressed)
- items: 13193 (element <Item>)
- fields: ['PriceUpdateTime', 'ItemCode', 'LastSaleDateTime', 'ItemType', 'ItemName', 'ManufactureName', 'ManufactureCountry', 'ManufactureItemDescription', 'UnitQty', 'Quantity', 'UnitOfMeasure', 'bIsWeighted', 'QtyInPackage', 'ItemPrice', 'UnitOfMeasurePrice', 'AllowDiscount', 'ItemStatus']
- UnitQty top values: [('לא ידוע', 8862), ('יחידות', 3322), ('קילוגרם', 969), ('מטרים', 40)]
- UnitOfMeasure top values: [('100 גרם', 5834), ('יחידות', 3322), ('100 מיליליטר', 2129), ('קילוגרם', 969), ('ליטר', 892), ('מטרים', 40), ('לא ידוע', 3), ('100 מטרים', 2)]
- QtyInPackage top values: [('לא ידוע', 13193)]
- bIsWeighted top values: [('0', 12535), ('1', 658)]
- ItemType top values: [('1', 13193)]
- AllowDiscount top values: [('1', 13193)]
- ItemStatus top values: [('', 13193)]
- items with UnitOfMeasurePrice: 13185/13193

## PromoFull
- file: PromoFull7290058140886-001-023-20261013-001105.gz (359274 bytes compressed)
- promotions: 2378
- fields (count): [('PromotionUpdateTime', 2378), ('AllowMultipleDiscounts', 2378), ('PromotionID', 2378), ('PromotionDescription', 2378), ('PromotionStartDateTime', 2378), ('PromotionEndDateTime', 2378), ('PromotionStartHour', 2378), ('PromotionEndHour', 2378), ('PromotionDays', 2378), ('RedemptionLimit', 2378), ('MinNoOfItemOffered', 2378), ('ClubID', 2378), ('IsGiftItem', 2378), ('AdditionalIsCoupon', 2378), ('AdditionalRestrictions', 2378), ('Remarks', 2378), ('Groups', 2378)]
- RewardType top values: [('"<missing>"', 2378)]
- DiscountType top values: [('"<missing>"', 2378)]
- MinQty top values: [('"<missing>"', 2378)]
- MaxQty top values: [('"<missing>"', 2378)]
- AllowMultipleDiscounts top values: [('"0"', 2378)]
- IsWeightedPromo top values: [('"<missing>"', 2378)]
- ClubId top values: [('"<missing>"', 2378)]
- AdditionalIsCoupon top values: [('"0"', 2036), ('"1"', 342)]
- AdditionalGiftCount top values: [('"<missing>"', 2378)]
- AdditionalIsTotal top values: [('"<missing>"', 2378)]
- AdditionalMinBasketAmount top values: [('"<missing>"', 2378)]
- Remarks top values: [('""', 2036), ('"קופון שובר מגוון תלמה בקניית 8 יחידות"', 2), ('"קופון ריו מרה טונה רמילוי 15%"', 1), ('"קופון סופגניות 15 יח ב 1ש ח"', 1), ('"משקאות חלבון גו 2 יח ב-7.90 מצטרפים"', 1), ('"קופון מתנה דלי 750ג חלב הארץ"', 1), ('"קופון חלב הארץ יוגורט 1לי מתנה"', 1), ('"קופון יוגורט 150גר חלב הארץ מתנה"', 1)]
- items per promo (capped 10): [(0, 2378)]

## Quick discount check (single item promos)
- computable: 0; >=30%: 0; >=20%: 0

Total time: 19.3s