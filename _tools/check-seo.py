"""Check the PL publication's sitemap and canonical destinations (no network needed)."""
import re
import json
import sys
from pathlib import Path
from xml.etree import ElementTree

site = Path(sys.argv[1] if len(sys.argv) > 1 else 'publish')
origin = 'https://zyciezbolem.pl'
urls = [node.text for node in ElementTree.parse(site / 'sitemap.xml').findall('.//{*}loc')]
assert urls, 'Empty sitemap'
assert len(urls) == len(set(urls)), 'Duplicate sitemap URLs'
redirects = {}
for line in (site / '_redirects').read_text().splitlines():
    if line.startswith('/'):
        source, target, status = line.split()
        if status == '301':
            redirects[source] = target
for url in urls:
    assert url.startswith(origin + '/'), f'Unexpected sitemap origin: {url}'
    path = url[len(origin):]
    assert not path.endswith('.html'), f'Noncanonical HTML URL: {url}'
    assert path not in redirects, f'Redirect in sitemap: {url}'
    file = site / ('index.html' if path == '/' else path.lstrip('/') + '.html')
    assert file.is_file(), f'Missing sitemap target: {url}'
    canonical = re.findall(r'<link\s+rel="canonical"\s+href="([^"]+)"', file.read_text())
    assert canonical == [url], f'Canonical mismatch: {url}: {canonical}'
for source, target in redirects.items():
    assert target not in redirects, f'Redirect chain: {source} -> {target}'
    file = site / ('index.html' if target == '/' else target.lstrip('/') + '.html')
    assert file.is_file(), f'Missing redirect target: {source} -> {target}'
for source, expected in json.loads(Path(__file__).with_name('seo-legacy-urls.json').read_text()).items():
    assert redirects.get(source) == expected, f'Missing historical redirect: {source}'
print(f'SEO checks passed: {len(urls)} canonical sitemap URLs, {len(redirects)} redirects')
