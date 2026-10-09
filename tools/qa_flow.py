"""Walks the deeper flows (campaign battle, practice problem, online room) and
screenshots each step. Same prerequisites as qa_shots.py.
Usage: python tools/qa_flow.py [--width 390] [--out docs/qa]"""
import argparse, os, time
from playwright.sync_api import sync_playwright

BASE = 'http://localhost:8080'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--width', type=int, default=390)
    ap.add_argument('--height', type=int, default=844)
    ap.add_argument('--out', default='docs/qa')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(channel='chrome')
        ctx = b.new_context(viewport={'width': a.width, 'height': a.height}, device_scale_factor=1.5)
        pg = ctx.new_page()
        pg.on('console', lambda m: print('CONSOLE', m.text[:200]) if m.type == 'error' else None)

        def shot(name, wait=2.0):
            time.sleep(wait)
            pg.screenshot(path=f'{a.out}/{a.width}_{name}.png')
            print('shot', name)

        def click(name, **kw):
            pg.get_by_role('button', name=name, **kw).first.click()

        pg.goto(BASE); time.sleep(5)
        pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); time.sleep(.8)
        pg.get_by_role('textbox').fill('Flow' + str(int(time.time()) % 100000)); time.sleep(.3)
        click('Enter the Arena'); time.sleep(4)
        # Campaign: Continue -> preparation -> battle
        click('Continue'); shot('f1_prepare')
        for label in ('Start Battle', 'Fight', 'Begin'):
            try:
                click(label, exact=False); break
            except Exception:
                pass
        shot('f2_battle', 3)
        # Practice
        pg.goto(f'{BASE}/#/practice'); time.sleep(3)
        click('Surprise me', exact=False); shot('f3_practice_play', 4)
        # Online room
        pg.goto(f'{BASE}/#/online'); time.sleep(3)
        click('Create room'); shot('f4_lobby', 3)
        b.close()


if __name__ == '__main__':
    main()
