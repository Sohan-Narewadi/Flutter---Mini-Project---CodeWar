"""End-to-end online match with two real browsers.

Player A creates a Race room, player B joins with the code, A starts, A submits
the reference solution (read from the dev database) and both see the results.
Same prerequisites as qa_shots.py. Usage: python tools/qa_online.py [--out docs/qa]
"""
import argparse, os, re, sqlite3, time
from playwright.sync_api import sync_playwright

BASE = os.environ.get('CODEWAR_URL', 'http://localhost:8080')
DB = os.path.join(os.path.dirname(__file__), '..', 'backend', 'codewar.db')


def semantics_text(pg):
    return pg.evaluate("Array.from(document.querySelectorAll('flt-semantics')).map(e => e.innerText || '').join('\\n')")


def wait_for(pg, pred, timeout=25, what='condition'):
    end = time.time() + timeout
    while time.time() < end:
        txt = semantics_text(pg)
        if pred(txt):
            return txt
        time.sleep(0.5)
    raise AssertionError(f'timed out waiting for {what}. Page text:\n{semantics_text(pg)[:600]}')


def register(pg, name):
    pg.goto(BASE); time.sleep(5)
    pg.evaluate("document.querySelector('flt-semantics-placeholder')?.click()"); time.sleep(.8)
    pg.get_by_role('textbox').fill(name); time.sleep(.3)
    pg.get_by_role('button', name='Enter the Arena').click(); time.sleep(3.5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='docs/qa')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stamp = str(int(time.time()) % 100000)
    with sync_playwright() as p:
        b = p.chromium.launch(channel='chrome')
        ctxA = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=1.5)
        ctxB = b.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=1.5)
        A, B = ctxA.new_page(), ctxB.new_page()
        for pg, tag in ((A, 'A'), (B, 'B')):
            pg.on('console', lambda m, t=tag: print(f'[{t}] CONSOLE', m.text[:160]) if m.type == 'error' else None)

        register(A, 'Alice' + stamp)
        register(B, 'Bob' + stamp)
        print('registered both players')

        # A creates a room
        A.goto(f'{BASE}/#/online'); time.sleep(3)
        A.get_by_role('button', name='Create room').click()
        txt = wait_for(A, lambda t: re.search(r'\bROOM\b', t) is not None, what='lobby')
        code = re.search(r'\n([A-Z2-9]{6})\n', '\n' + txt + '\n')
        assert code, f'room code not found in: {txt[:300]}'
        code = code.group(1)
        print('room code', code)
        A.screenshot(path=f'{a.out}/online_A_lobby.png')

        # B joins with the code
        B.goto(f'{BASE}/#/online'); time.sleep(3)
        B.get_by_role('textbox').fill(code); time.sleep(.3)
        try:
            B.get_by_role('button', name='Join room').click(timeout=8000)
        except Exception:
            B.screenshot(path=f'{a.out}/fail_B.png'); A.screenshot(path=f'{a.out}/fail_A.png'); print('B text:', semantics_text(B)[:400]); raise
        wait_for(B, lambda t: code in t, what='B in the lobby')
        wait_for(A, lambda t: ('Bob' + stamp) in t, what='A sees Bob join')
        print('both players are in the lobby')
        B.screenshot(path=f'{a.out}/online_B_lobby.png')

        # A starts the match
        A.get_by_role('button', name='Start match').click()
        txt = wait_for(A, lambda t: re.search(r'\bRun\b', t) and 'Submit' in t, timeout=40, what='match to start')
        wait_for(B, lambda t: 'Submit' in t, timeout=20, what='B match view')
        time.sleep(1)
        A.screenshot(path=f'{a.out}/online_A_match.png')
        B.screenshot(path=f'{a.out}/online_B_match.png')
        print('match started on both browsers')

        # Find the problem title and its reference solution in the dev DB
        con = sqlite3.connect(DB)
        row = None
        for line in [l.strip() for l in txt.split('\n') if l.strip()]:
            r = con.execute('select reference_solution from questions where title=? order by rowid desc limit 1', (line,)).fetchone()
            if r and r[0]:
                row = (line, r[0])
                break
        assert row, 'could not match a problem title to a stored reference solution'
        print('problem:', row[0])

        # A types the solution (insert_text is one paste-like edit, so auto-indent stays out of the way)
        editor = A.get_by_role('textbox').first
        editor.click()
        A.keyboard.press('Control+a')
        A.keyboard.insert_text(row[1])
        time.sleep(.5)
        A.get_by_role('button', name='Submit').click()
        wait_for(A, lambda t: 'Victory' in t, timeout=40, what='A victory screen')
        wait_for(B, lambda t: 'Match over' in t or 'Draw' in t or 'Victory' in t, timeout=40, what='B results')
        time.sleep(2)
        A.screenshot(path=f'{a.out}/online_A_results.png')
        B.screenshot(path=f'{a.out}/online_B_results.png')
        ta, tb = semantics_text(A), semantics_text(B)
        assert 'RP' in ta and 'RP' in tb, 'rating changes missing'
        print('RESULTS A:', [l for l in ta.split('\n') if 'RP' in l or 'XP' in l])
        print('RESULTS B:', [l for l in tb.split('\n') if 'RP' in l or 'XP' in l])
        print('ONLINE E2E PASSED')
        b.close()


if __name__ == '__main__':
    main()
