# Stage 0 probe report

- DNS url.retail.publishedprices.co.il -> 194.90.26.22
- FTPS login OK as RamiLevi (2.5s)
- Files listed: 1341
- File kinds: {'price': 740, 'pricefull': 193, 'promo': 214, 'promofull': 192, 'stores': 2}
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
- ClubID values: [('0', 2342), ('(1=מועדון חברתי|1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי|1=מועדון נטען|1=לקוחות ארנק)', 20), ('((2=מועדון לקוחות אשראי))&(3=תווי זיכוי מימוש|3=עיגול אגורות|3=מולטיפס תו רמי לוי)', 4), ('((1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי))&(3=ישראכרט מגנטי|3=תווי זיכוי מימוש|3=עיגול אגורות)', 4), ('(1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי)', 4), ('((1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי))&(3=תווי זיכוי מימוש|3=עיגול אגורות|3=מולטיפס תו רמי לוי)', 2), ('(1=מועדון שיווק   השקמה|1=מועדון חברתי)', 1), ('((2=מועדון לקוחות אשראי))&(3=ישראכרט מגנטי|3=תווי זיכוי מימוש|3=עיגול אגורות|3=מולטיפס תו רמי לוי)', 1)]
- IsGiftItem values: [('1', 1174), ('2', 677), ('', 321), ('3', 131), ('4', 40), ('5', 10), ('6', 8), ('7', 6), ('8', 5), ('9', 3)]
- RedemptionLimit values: [('', 2199), ('3', 86), ('2', 51), ('1', 27), ('9', 10), ('4', 4), ('12', 1)]
- groups per promo: [(1, 2328), (2, 50)]
- items per promo (capped 20): [(1, 992), (2, 409), (3, 247), (4, 182), (5, 133), (6, 87), (7, 52), (8, 52), (9, 19), (10, 36), (11, 10), (12, 20), (13, 14), (14, 13), (15, 15), (16, 13), (17, 3), (18, 7), (19, 3), (20, 71)]
- promo-item rows: 13093
- RewardType values: [('3', 6321), ('10', 5321), ('2', 629), ('0', 588), ('1', 234)]
- MinQty values: [('1', 4116), ('2', 3786), ('0.010', 3355), ('3', 876), ('4', 356), ('5990', 175), ('5', 166), ('6', 93), ('8', 77), ('9', 61)]
- MinPurchaseAmount values: [('0.00', 12357), ('', 617), ('75.00', 115), ('99.00', 4)]
  - RewardType 0 examples: פיצה מאמאיה מעדנות 2ב20 מעל 75 מו2 | רבעיית מגבונים 4*72 יח ב10.90 מעל 75 מו2 | אסטוניש מרססים פרמיום 2ב15 מעל 75 מו4 | משחת שיניים קולייט ב8.90 מעל 75 מו2
  - RewardType 1 examples: קריט קרקרים מלוחים 300 גרם 2ב15 | גרעיני תירס 335 גרם רמי לוי 2ב10 | ערמונים 100גרם רמי לוי 3ב10 | עוגיות עלי וופל 100 גרם צוקטה 2ב12
  - RewardType 10 examples: טיטולים פרמיום 2ב55 מו4 | עדשים סוגת 500ג 3ב12 | ריצפז פרש הום 2 ליטר 2ב34 נקודתי | פחית בירה מכבי/גולדסטא 500 מ ל 3ב20 כולל
  - RewardType 2 examples: קופון ריו מרה טונה רמילוי 15% | קופון סופגניות 15 יח ב 1ש ח | קופון חלב הארץ יוגורט 1לי מתנה | קופון יוגורט 150גר חלב הארץ מתנה
  - RewardType 3 examples: חומוס גדול1 ק ג רמי לוי ב9.90 | פתית תלמה ב14.90 נקודתי | יחידת מדפים מעץ במבוק 4 קומות ב49.90 ש ח | פומלית ב5.9 מוגבל ל3

## Discount check (per promo, best item; unit price = DiscountedPrice / MinQty)
- promos computable: 1698 / 2378; unmatched item codes: 4573
- >= 10%: 1320  (and saving >= 3 NIS: 751)
- >= 20%: 720  (and saving >= 3 NIS: 535)
- >= 30%: 364  (and saving >= 3 NIS: 311)
- >= 40%: 157  (and saving >= 3 NIS: 149)
- >= 50%: 75  (and saving >= 3 NIS: 75)
- negative (promo unit price above regular): 46
- our % agrees with DiscountRate field (+-1.5): 1602/1698
### Top 40
  - 100.0% (save 29.9) | קולגייט מברשת גנטל ק | regular 29.9 | promo 29.9 for 5990.0 | DiscountRate 0.0 | קנה ב-59.90 ש ח שסטוביץ - קבל דלי מגבוני | club 0 | RT 0
  - 93.7% (save 14.8) | במבה חטיף בוטנים אסם | regular 15.8 | promo 1.0 for 1.0 | DiscountRate 93.67 | קופון במבה מארז ב1שח-הטבת ביטוח רמילוי | club 0 | RT 3
  - 91.3% (save 13.6) | מיץ תירוש 100% אדום | regular 14.9 | promo 1.3 for 1.0 | DiscountRate 91.28 | קופון מיץ תירוש ב1שח-הטבת ביטוח רמילוי | club 0 | RT 3
  - 90.8% (save 9.9) | עוגת הבית שוקולד צ'י | regular 10.9 | promo 1.0 for 1.0 | DiscountRate 90.83 | קופון עוגת הבית שוקולד ציפס ב1ש-הטבת ביט | club 0 | RT 3
  - 90.2% (save 7.4) | קוקה-קולה זירו נטול | regular 8.2 | promo 1.6 for 2.0 | DiscountRate 90.59 | קופון קולה/זירו 1.5ל 2יח ב1שח-הטבת ביטוח | club 0 | RT 10
  - 88.2% (save 7.5) | שוקולד פרה מריר מעול | regular 8.5 | promo 1.0 for 1.0 | DiscountRate 88.24 | קופון שוקולד פרה ב1שח-הטבת ביטוח רמילוי | club 0 | RT 3
  - 86.1% (save 6.2) | חלב תנובה 3% שומן 1 | regular 7.2 | promo 1.0 for 1.0 | DiscountRate 86.11 | קופון חלב תנובה קרטון 1לי ב1שח | club 0 | RT 3
  - 83.1% (save 4.9) | קוטג' תנובה 9% שומן | regular 5.9 | promo 1.0 for 1.0 | DiscountRate 83.05 | קופון קוטג  250גר תנובה ב1שח | club 0 | RT 3
  - 83.1% (save 4.9) | דנונה פרו 20ג תות | regular 5.9 | promo 1.0 for 1.0 | DiscountRate 83.05 | קופון מעדן יוגורט פרו ב1שח | club 0 | RT 3
  - 82.8% (save 4.8) | גבינה לבנה תנובה 5% | regular 5.8 | promo 1.0 for 1.0 | DiscountRate 82.76 | קופון גבינה לבנה 250גר תנובה 1שח | club 0 | RT 3
  - 79.6% (save 3.9) | שוקו פקק ספורט יטבתה | regular 4.9 | promo 1.0 for 1.0 | DiscountRate 79.59 | קופון שוקו יטבתה פקק ב1ש-הטבת ביטוח רמיל | club 0 | RT 3
  - 78.2% (save 17.9) | שעועית ירוקה רחבה מו | regular 22.9 | promo 10.0 for 2.0 | DiscountRate 78.17 | שעועית רחבה מוקפאת 600 גרם 2ב10 | club 0 | RT 1
  - 75.0% (save 13.42) | גולון עוגיות ללא סוכ | regular 17.9 | promo 8.95 for 2.0 | DiscountRate 50.0 | גולון טווינס לל ס 210גר השני בחצי | club 0 | RT 2
  - 74.9% (save 29.9) | כפכף אופנה קיץ 36-41 | regular 39.9 | promo 10.0 for 1.0 | DiscountRate 74.94 | נעלי קיץ ב-10 ש ח | club 0 | RT 3
  - 74.9% (save 14.9) | כיסא ים פסים | regular 19.9 | promo 15.0 for 3.0 | DiscountRate 15.25 | פטרוזליה/כוסברה/שמיר/נענע מהדרין 3ב15 | club 0 | RT 10
  - 70.7% (save 11.95) | לחם ללא גלוטן 500 גר | regular 16.9 | promo 9.9 for 2.0 | DiscountRate 70.71 | לחם לל ג 2ב9.90 | club 0 | RT 1
  - 69.2% (save 11.0) | משקה קאפרי 3% 1ליטר | regular 15.9 | promo 4.9 for 1.0 | DiscountRate 69.18 | משקה קאו פרי 1 ליטר יטבתה ב4.90 מעל 75 מ | club 0 | RT 3
  - 68.9% (save 10.95) | ג'בטה 380 גר | regular 15.9 | promo 9.9 for 2.0 | DiscountRate 68.87 | לחמניות לל ג 2ב9.90 | club 0 | RT 10
  - 67.4% (save 6.0) | שמן קנולה הולנד 1 לי | regular 8.9 | promo 2.9 for 1.0 | DiscountRate 67.42 | שמן קנולה 1לי ב2.90-אשראי | club 0 | RT 3
  - 67.1% (save 10.0) | דאודורנט ספריי גוף ל | regular 14.9 | promo 4.9 for 1.0 | DiscountRate 67.11 | דאו אקס 150-200 מ ל ב4.90 מעל 75 מו4 | club 0 | RT 3
  - 66.4% (save 19.8) | קמיל בלו תחליב גוף ב | regular 29.8 | promo 10.0 for 1.0 | DiscountRate 66.44 | קופון פישר קמיל תחליב גוף 450מל ב10שח | club 0 | RT 3
  - 65.3% (save 13.0) | קוטל זבובים ויתושים | regular 19.9 | promo 6.9 for 1.0 | DiscountRate 65.33 | קוטל יתושים קיי 600 סנו ב6.90 ביתר מו2 | club 0 | RT 3
  - 65.1% (save 11.0) | טחינה גולמית שומשום | regular 16.9 | promo 5.9 for 1.0 | DiscountRate 65.09 | טחינה גולמית בארכה ב-5.90 מצטרפים | club (1=מועדון חברתי|1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי|1=מועדון נטען|1=לקוחות ארנק) | RT 3
  - 63.8% (save 4.4) | סכין לבן 100 יח | regular 6.9 | promo 10.0 for 4.0 | DiscountRate 63.77 | סכום 100 יח 4ב10 | club 0 | RT 10
  - 62.9% (save 10.0) | דאב שמפו חדש יום יומ | regular 15.9 | promo 5.9 for 1.0 | DiscountRate 62.89 | שמפו/מרכך דאב ב-5.90 מצטרפים | club (1=מועדון חברתי|1=מועדון שיווק   השקמה|1=מועדון לקוחות אשראי|1=מועדון נטען|1=לקוחות ארנק) | RT 3
  - 62.7% (save 25.0) | סל כביסה/אחסון בד 60 | regular 39.9 | promo 14.9 for 1.0 | DiscountRate 62.66 | סל אחסון/כביסה בד 60ליטר ב14.90 | club 0 | RT 3
  - 61.8% (save 16.0) | וויטביקס מולטי קראנץ | regular 25.9 | promo 9.9 for 1.0 | DiscountRate 61.78 | וויטביקס מולטי קראנץ ב9.90 | club 0 | RT 3
  - 61.4% (save 15.9) | מאמאמיה פיצה עם תירס | regular 25.9 | promo 20.0 for 2.0 | DiscountRate 61.39 | פיצה מאמאיה מעדנות 2ב20 מעל 75 מו2 | club 0 | RT 10
  - 60.9% (save 31.0) | שמיכת קיץ זוגי 200*2 | regular 50.9 | promo 19.9 for 1.0 | DiscountRate 60.9 | שמיכת קיץ זוגי/יחיד צבע אחיד ב19.90 | club 0 | RT 3
  - 60.4% (save 9.0) | חמאת בוטנים לל"ס 300 | regular 14.9 | promo 5.9 for 1.0 | DiscountRate 60.4 | חמאת בוטנים שקד תבור ב-5.90 מצטרפים | club 0 | RT 3
  - 60.4% (save 4.78) | סכין שקוף 40 יח | regular 7.9 | promo 12.5 for 4.0 | DiscountRate 60.44 | סכום 40 יח 4ב12.50 | club 0 | RT 10
  - 60.3% (save 12.0) | קורנפלקס אלופים תלמה | regular 19.9 | promo 7.9 for 1.0 | DiscountRate 60.3 | קורנפלקס אלופים 850גר ב7.90-אשראי | club 0 | RT 3
  - 60.1% (save 60.0) | סט מצעים מלא זוגי קא | regular 99.9 | promo 39.9 for 1.0 | DiscountRate 60.06 | סט מצעים מיטה זוגית ב-39.90 ש ח | club 0 | RT 3
  - 59.9% (save 29.9) | מארז (2) מגבות גוף 1 | regular 49.9 | promo 100.0 for 5.0 | DiscountRate 59.92 | מגבות גוף 5 ב-100 ש ח | club 0 | RT 10
  - 59.6% (save 5.9) | מגשיות אלומניום קטנו | regular 9.9 | promo 12.0 for 3.0 | DiscountRate 59.6 | תבניות אלומניום רמי לוי 3ב12 מעל 75 מו6 | club 0 | RT 10
  - 58.5% (save 3.45) | גריסים 500ג רמילוי | regular 5.9 | promo 4.9 for 2.0 | DiscountRate 58.47 | אפונה/גריסים 500 גרם רמי לוי 2ב4.90 | club 0 | RT 10
  - 58.2% (save 13.9) | תרסיס על בסיס שמנים | regular 23.9 | promo 20.0 for 2.0 | DiscountRate 58.16 | פאם אפייה 148 מ ל 2ב20 | club 0 | RT 1
  - 58.2% (save 13.9) | גונסונס בייבי שמפו ק | regular 23.9 | promo 20.0 for 2.0 | DiscountRate 58.16 | שמפו/אלסבון גונסון בייבי 750 מ ל 2ב20 | club 0 | RT 10
  - 58.1% (save 6.8) | אורז פרסי קלאסי סוגת | regular 11.7 | promo 4.9 for 1.0 | DiscountRate 58.12 | אורז פרסי 1 קג ב -4.90 אשראי | club 0 | RT 3
  - 56.9% (save 17.0) | קופסת אוכל מחולקת עם | regular 29.9 | promo 12.9 for 1.0 | DiscountRate 56.86 | סט קופסאות אוכל + בקבוק ב12.90 ש ח | club 0 | RT 3
### Around 30%
  - 32.0% (save 4.7) | משקה שקדים אלפרו ללת | 14.7 -> 20.0 for 2.0 | משקאות אלפרו 1 ליטר 2ב20
  - 32.0% (save 1.57) | שמיר רמי לוי | 4.9 -> 10.0 for 3.0 | נענע/פטרוזליה/כוסברה/שמיר רמי לוי 3ב10
  - 32.0% (save 1.57) | סרדינים מרוקאים בשמן | 4.9 -> 10.0 for 3.0 | סרדינים מרוקאים בשמן סויה 3ב10
  - 32.0% (save 1.57) | סוכר לבן 1 ק"ג שטודן | 4.9 -> 10.0 for 3.0 | סוכר 1 ק ג רמי לוי 3ב10
  - 31.9% (save 2.2) | פריניב מיץ לימון לתי | 6.9 -> 9.4 for 2.0 | מיץ לימונענע טבעי 500 מ ל פריניב 2ב10 כו
  - 31.7% (save 6.95) | תחבושות כותנה עם אני | 21.9 -> 29.9 for 2.0 | תחבושות כותנה צויס 2ב29.90
  - 31.7% (save 6.0) | רביעיית מגבונים בביש | 18.9 -> 12.9 for 1.0 | רביעיית מגבונים סטיטץ ב12.90
  - 31.7% (save 4.6) | לחם דגנים פלוס 500 ג | 14.5 -> 9.9 for 1.0 | חליה/לחמניות/לחם דגנים ברמן ב9.90
  - 31.7% (save 4.6) | גרנה פדנו מגורד 100 | 14.5 -> 9.9 for 1.0 | גרנה פדנו מגורדת מחלבות גד 100גרם ב9.90
  - 31.6% (save 10.4) | קמיל בלו אקסטרה סופט | 32.9 -> 45.0 for 2.0 | קמיל בלו אקסטרה סופט אלסבון 1ל 2ב45
### Some negatives
  - -0.5% | אמירים רזרב רוזה 750 | 19.9 -> 60.0 for 3.0 | DR 0.99 | יין אמירים 750מל 3ב60 כולל | RT 10
  - -5552.2% | מלפפון | 6.9 -> 3.9 for 0.01 | DR 43.48 | מלפפון ב3.9 מוגבל ל3 | RT 3
  - -5583.5% | אננס מובחר | 13.9 -> 7.9 for 0.01 | DR 43.17 | אננס מובחר ב7.9 מוגבל ל3 | RT 3
  - -5635.3% | בטטה | 6.8 -> 3.9 for 0.01 | DR 42.65 | בטטה ב3.9 מוגבל ל3 | RT 3
  - -5809.1% | חציל | 6.6 -> 3.9 for 0.01 | DR 40.91 | חציל ב3.9 מוגבל ל3 | RT 3
  - -6145.3% | רביעייה מנות פילה סל | 79.9 -> 49.9 for 0.01 | DR 37.55 | מנות סלמון קפוא ב49.90 מעל 75 מו3 | RT 10
  - -6510.2% | עגבניה | 5.9 -> 3.9 for 0.01 | DR 33.9 | עגבניה ב3.9 מוגבל ל3 | RT 3
  - -6544.3% | אגס תפוח | 14.9 -> 9.9 for 0.01 | DR 33.56 | אגס תפוח ב9.9 מוגבל ל3 | RT 3

Total time: 21.3s