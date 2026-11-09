"""Browser regression checks. Run from the repository with python3 _tools/test-search.py."""
import functools
import json
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent.parent
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass
server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(QuietHandler, directory=str(root / 'site')))
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
base = f'http://127.0.0.1:{server.server_port}'
articles = [
    {'t': 'Ból po zabiegach stomatologicznych', 's': 'bol-po-zabiegach', 'e': 'Ból i powrót do zdrowia.'},
    {'t': 'Neuralgia trójdzielna', 's': 'neuralgia', 'e': 'Możliwości leczenia bólu.'},
    {'t': 'Dziennik bólu', 's': 'dziennik', 'e': 'Zapisuj swoje obserwacje.'},
    {'t': 'Codzienność', 's': 'codziennosc', 'e': 'Tutaj opisujemy dziennik bólu.'},
    {'t': '<img src=x onerror="window.injected=true">', 's': 'bezpieczny', 'e': '<script>window.injected=true</script>'},
]
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 390, 'height': 844})
        pending = []
        page.route('**/search-index.json', lambda route: pending.append(route))
        page.goto(base, wait_until='domcontentloaded')
        page.get_by_role('button', name='Szukaj artykułów').click()
        field = page.get_by_role('searchbox')
        field.fill('bol po dentyscie')
        page.wait_for_function("document.querySelector('.szukaj-status').textContent.includes('Ładowanie')")
        assert pending
        pending.pop().fulfill(json=articles)
        page.get_by_role('link', name='Ból po zabiegach stomatologicznych').wait_for()
        for query in ['neuraliga', 'nerwobol', 'NEURALGIA TRÓJDZIELNA']:
            field.fill(query)
            assert page.locator('.szukaj-wynik strong').first.inner_text() == 'Neuralgia trójdzielna', query
        field.fill('dziennik bolu')
        assert page.locator('.szukaj-wynik strong').first.inner_text() == 'Dziennik bólu'
        assert page.locator('.szukaj-wynik').first.get_attribute('href') == '/dziennik'
        assert page.locator('.szukaj-wynik span').first.inner_text() == 'Zapisuj swoje obserwacje.'
        field.fill('qzxvplmn')
        assert 'Brak wyników' in page.get_by_role('status').inner_text()
        field.fill('img')
        assert page.locator('.szukaj-wynik img').count() == 0
        assert page.evaluate('window.injected') is None
        field.fill('dziennik bolu')
        page.keyboard.press('Escape')
        assert page.get_by_role('dialog').count() == 0
        assert page.get_by_role('button', name='Szukaj artykułów').evaluate('(el) => el === document.activeElement')
        page.get_by_role('button', name='Szukaj artykułów').click()
        assert field.input_value() == 'dziennik bolu'
        page.locator('.szukaj-wynik').last.focus()
        page.keyboard.press('Tab')
        assert page.get_by_role('button', name='Zamknij wyszukiwarkę').evaluate('(el) => el === document.activeElement')
        assert page.locator('.szukaj-box').bounding_box()['width'] <= 390
        print('PASS: delayed load, synonyms, accents, typo, ranking, snippets, canonical links, empty results, text escaping, focus, mobile')
        page.close()
        page = browser.new_page()
        attempts = []
        def respond(route):
            attempts.append(1)
            if len(attempts) == 1:
                route.fulfill(status=503, body='Unavailable')
            else:
                route.fulfill(json=articles)
        page.route('**/search-index.json', respond)
        page.goto(base, wait_until='domcontentloaded')
        page.get_by_role('button', name='Szukaj artykułów').click()
        page.get_by_role('button', name='Spróbuj ponownie').wait_for()
        page.get_by_role('searchbox').fill('dziennik')
        page.get_by_role('button', name='Spróbuj ponownie').click()
        page.locator('.szukaj-wynik strong').filter(has_text='Dziennik bólu').wait_for()
        assert len(attempts) == 2
        print('PASS: failed request, retry, retained query')
        page.close()
        page = browser.new_page(viewport={'width': 390, 'height': 844})
        page.goto(base, wait_until='domcontentloaded')
        page.get_by_role('button', name='Szukaj artykułów').click()
        page.get_by_role('searchbox').fill('bol po dentyscie')
        page.locator('.szukaj-wynik').first.wait_for()
        assert page.locator('.szukaj-wynik').count() > 0
        print('PASS: actual repository index; dental query:', page.locator('.szukaj-wynik strong').first.inner_text())
        browser.close()
finally:
    server.shutdown()
    server.server_close()
