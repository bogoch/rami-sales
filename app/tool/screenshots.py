"""Take phone-sized screenshots of the web build (CI visual check)."""
import sys
import time
from playwright.sync_api import sync_playwright

url, out = sys.argv[1], sys.argv[2]
with sync_playwright() as p:
    b = p.chromium.launch()
    for scheme in ("light", "dark"):
        ctx = b.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=2,
                            color_scheme=scheme, locale="he-IL", is_mobile=True, has_touch=True)
        page = ctx.new_page()
        page.on("console", lambda m: print("console:", m.text))
        page.goto(url)
        time.sleep(12)
        page.screenshot(path=f"{out}/home-{scheme}.png")
        if scheme == "light":
            page.mouse.wheel(0, 700)
            time.sleep(1.5)
            page.screenshot(path=f"{out}/home-scrolled.png")
            page.mouse.wheel(0, -2000)
            time.sleep(1.5)
            page.mouse.click(195, 430)
            time.sleep(2.5)
            page.screenshot(path=f"{out}/sheet.png")
        ctx.close()
    b.close()
