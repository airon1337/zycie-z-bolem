"""Validate published PL/EN alternates, including canonical targets and return links."""
import sys
from pathlib import Path
from html.parser import HTMLParser

class Head(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links = {}
        self.canonical = None
        self.language = None
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'html':
            self.language = a.get('lang')
        if tag == 'link' and a.get('rel') == 'canonical':
            self.canonical = a.get('href')
        if tag == 'link' and 'hreflang' in a:
            lang = a['hreflang']
            assert lang not in self.links, f'Duplicate hreflang: {lang}'
            self.links[lang] = a.get('href')

roots = [Path(x) for x in sys.argv[1:]] or [Path('publish'), Path('myneuralgia/site-en')]
pages = {}
for root in roots:
    assert root.is_dir(), f'Missing output: {root}'
    for file in root.glob('*.html'):
        page = Head(file.read_text(encoding='utf-8-sig'))
        if page.canonical:
            pages[page.canonical] = page
count = 0
for url, page in pages.items():
    if not page.links:
        continue
    count += 1
    languages = {lang: target for lang, target in page.links.items() if lang != 'x-default'}
    assert len(set(languages.values())) == len(languages), f'Same URL for multiple languages: {url}'
    assert page.links.get(page.language) == url, f'Missing self-reference: {url}'
    for lang, target in page.links.items():
        assert target and target in pages, f'Missing canonical target: {url} -> {target}'
        other = pages[target]
        if lang != 'x-default':
            assert other.language == lang, f'Wrong language: {url} -> {target}'
        assert other.links == page.links, f'Nonreciprocal alternates: {url} -> {target}'
assert count, 'No translated article pairs checked'
print(f'Hreflang checks passed: {count} pages with reciprocal language alternates')
