from playwright.sync_api import sync_playwright
import time

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 430, "height": 932})  # iPhone-like viewport

    # 1. Main page
    page.goto('http://localhost:9000', wait_until='networkidle')
    page.wait_for_timeout(3000)  # Wait for video to load
    page.screenshot(path='/tmp/main_page.png')
    print("Screenshot 1: Main page saved")

    # 2. Look for tag elements and click one
    # First, let's inspect what's on the page
    content = page.content()

    # Find tag elements
    tags = page.locator('.tag').all()
    print(f"Found {len(tags)} tag elements on main page")

    if tags:
        # Click the first tag
        tag_text = tags[0].text_content()
        print(f"Clicking tag: {tag_text}")
        tags[0].click()
        page.wait_for_timeout(3000)  # Wait for tag page to render
        page.screenshot(path='/tmp/tag_page.png')
        print("Screenshot 2: Tag page saved")

        # Scroll down a bit to see more grid items
        page.evaluate("document.querySelector('.list-page')?.scrollBy(0, 500)")
        page.wait_for_timeout(2000)
        page.screenshot(path='/tmp/tag_page_scrolled.png')
        print("Screenshot 3: Tag page scrolled saved")
    else:
        print("No tags found, trying to find clickable elements")
        # Take a full page screenshot to see what's there
        page.screenshot(path='/tmp/main_full.png', full_page=True)

        # Let's also check the DOM structure
        html_snippet = page.evaluate("""
            () => {
                const slide = document.querySelector('.slide.active');
                if (slide) return slide.innerHTML.substring(0, 2000);
                return document.body.innerHTML.substring(0, 3000);
            }
        """)
        print(f"Active slide HTML:\n{html_snippet}")

    browser.close()
