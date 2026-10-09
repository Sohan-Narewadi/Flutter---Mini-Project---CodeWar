"""Screenshot every route of the web build at several widths.

Usage: python tools/qa_shots.py [--widths 390,768] [--routes home,rank] [--out docs/qa]
Needs: backend on :8000, `flutter build web --dart-define=API_URL=http://localhost:8000`,
`python -m http.server 8080` in frontend/codewar/build/web. Uses installed Chrome.
"""
import argparse, os, sys, time
from playwright.sync_api import sync_playwright

ROUTES = ['home', 'practice', 'online', 'rank', 'profile', 'battle', 'settings']
BASE = os.environ.get('CODEWAR_URL', 'http://localhost:8080')

def enable_semantics(pg):
    pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()")
    time.sleep(0.8)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--widths', default='390')
    ap.add_argument('--routes', default=','.join(ROUTES))
    ap.add_argument('--out', default='docs/qa')
    ap.add_argument('--height', type=int, default=844)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(channel='chrome')
        for w in [int(x) for x in a.widths.split(',')]:
            h = a.height if w < 700 else 800
            ctx = b.new_context(viewport={'width': w, 'height': h}, device_scale_factor=1.5)
            pg = ctx.new_page()
            pg.on('console', lambda m: print('CONSOLE', m.text[:200]) if m.type == 'error' else None)
            pg.goto(BASE); time.sleep(5)
            pg.screenshot(path=f'{a.out}/{w}_onboarding.png')
            enable_semantics(pg)
            pg.get_by_role('textbox').fill('QA' + str(int(time.time()) % 100000)); time.sleep(.4)
            pg.get_by_role('button', name='Enter the Arena').click(); time.sleep(4)
            for r in a.routes.split(','):
                pg.goto(f'{BASE}/#/{r}'); time.sleep(3)
                pg.screenshot(path=f'{a.out}/{w}_{r}.png'); print('shot', w, r)
            ctx.close()
        b.close()

if __name__ == '__main__':
    main()
