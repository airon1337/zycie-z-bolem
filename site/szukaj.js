(function () {
  'use strict';
  var idx = null, loading = false, failed = false, previousFocus;
  function norm(s) {
    return String(s || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ł/g, 'l');
  }
  function words(s) { return norm(s).match(/[a-z0-9]+/g) || []; }
  // Language variants only: these groups do not infer a diagnosis from symptoms.
  var groups = [
    /^(dentyst|dentysc|stomatolog|stomatologic|zeb|zab$)/,
    /^(lek$|leki$|lekow|farmakoterap)/,
    /^(operac|operow|chirurg)/,
    /^(neuralgi|nerwobol)/,
    /^(trojdziel|trojdzieln)/
  ];
  function group(w) {
    for (var i = 0; i < groups.length; i++) if (groups[i].test(w)) return i;
    return -1;
  }
  function distance(a, b) {
    if (Math.abs(a.length - b.length) > 1) return 2;
    if (a.length === b.length) {
      var different = [];
      for (var k = 0; k < a.length; k++) if (a[k] !== b[k]) different.push(k);
      if (different.length === 2 && different[1] === different[0] + 1 && a[different[0]] === b[different[1]] && a[different[1]] === b[different[0]]) return 1;
    }
    var row = Array.from({ length: b.length + 1 }, function (_, i) { return i; });
    for (var i = 1; i <= a.length; i++) {
      var next = [i];
      for (var j = 1; j <= b.length; j++) next[j] = Math.min(next[j - 1] + 1, row[j] + 1, row[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
      row = next;
    }
    return row[b.length];
  }
  function strength(q, tokens) {
    var best = 0;
    tokens.forEach(function (w) {
      if (w === q) best = Math.max(best, 8);
      else if (w.indexOf(q) === 0 && q.length >= 3) best = Math.max(best, 6);
      else if (group(q) >= 0 && group(q) === group(w)) best = Math.max(best, 4);
      else if (q.length >= 5 && distance(q, w) <= 1) best = Math.max(best, 2);
    });
    return best;
  }
  function rank(query) {
    var terms = words(query).filter(function (w) { return !/^(w|we|z|ze|i|a|o|od|do|na|po|sie|jak|czy|jest)$/.test(w); });
    if (!terms.length) return [];
    var phrase = norm(query.trim());
    return idx.map(function (a) {
      var score = 0;
      var matches = terms.every(function (q) {
        var title = strength(q, a.titleWords), excerpt = strength(q, a.excerptWords);
        score += title * 3 + excerpt;
        return title > 0 || excerpt > 0;
      });
      if (a.title.indexOf(phrase) >= 0) score += 40;
      return { article: a, score: matches ? score : 0 };
    }).filter(function (r) { return r.score > 0; }).sort(function (a, b) { return b.score - a.score || a.article.t.localeCompare(b.article.t, 'pl'); });
  }
  var menu = document.querySelector('.nav .menu') || document.querySelector('.nav');
  if (!menu) return;
  var btn = document.createElement('button');
  btn.type = 'button'; btn.className = 'szukaj-btn';
  btn.setAttribute('aria-label', 'Szukaj artykułów');
  btn.setAttribute('aria-haspopup', 'dialog');
  btn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="11" r="7"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>';
  menu.appendChild(btn);
  var ov = document.createElement('div');
  ov.className = 'szukaj-overlay'; ov.hidden = true;
  ov.innerHTML = '<section class="szukaj-box" role="dialog" aria-modal="true" aria-labelledby="szukaj-title"><div class="szukaj-header"><h2 id="szukaj-title">Znajdź artykuł</h2><button type="button" class="szukaj-close" aria-label="Zamknij wyszukiwarkę">×</button></div><label class="szukaj-label" for="szukaj-query">Co Cię interesuje?</label><input id="szukaj-query" type="search" class="szukaj-input" placeholder="Np. ból po dentyście, dziennik bólu…" autocomplete="off"><p class="szukaj-status" role="status" aria-live="polite"></p><div class="szukaj-wyniki"></div><button type="button" class="szukaj-retry" hidden>Spróbuj ponownie</button></section>';
  document.body.appendChild(ov);
  var input = ov.querySelector('input'), results = ov.querySelector('.szukaj-wyniki');
  var status = ov.querySelector('.szukaj-status'), retry = ov.querySelector('.szukaj-retry');
  function render() {
    results.replaceChildren(); retry.hidden = !failed;
    if (loading) { status.textContent = 'Ładowanie artykułów…'; return; }
    if (failed) { status.textContent = 'Nie udało się wczytać artykułów. Spróbuj ponownie.'; return; }
    if (input.value.trim().length < 2) { status.textContent = 'Wpisz co najmniej 2 znaki. Możesz pominąć polskie znaki.'; return; }
    if (!idx) return;
    var matches = rank(input.value);
    status.textContent = matches.length ? 'Znalezione artykuły: ' + matches.length + (matches.length > 20 ? '. Pokazujemy pierwsze 20.' : '.') : 'Brak wyników. Spróbuj krótszego hasła, np. „ból twarzy” lub „leczenie”.';
    matches.slice(0, 20).forEach(function (r) {
      var a = r.article, link = document.createElement('a'), title = document.createElement('strong'), excerpt = document.createElement('span');
      link.className = 'szukaj-wynik'; link.href = '/' + encodeURIComponent(a.s);
      title.textContent = a.t;
      excerpt.textContent = a.e.replace(/[*_`#]/g, '').slice(0, 200);
      link.append(title, excerpt); results.appendChild(link);
    });
  }
  function load() {
    if (loading || idx) return;
    loading = true; failed = false; render();
    var controller = new AbortController();
    var timeout = setTimeout(function () { controller.abort(); }, 10000);
    fetch('/search-index.json', { signal: controller.signal }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    }).then(function (data) {
      if (!Array.isArray(data) || !data.length || data.some(function (a) { return !a || typeof a.t !== 'string' || typeof a.e !== 'string' || typeof a.s !== 'string'; })) throw new Error('Invalid index');
      idx = data.map(function (a) { return { t: a.t, s: a.s, e: a.e, title: norm(a.t), titleWords: words(a.t), excerptWords: words(a.e) }; });
    }).catch(function () { failed = true; }).finally(function () { clearTimeout(timeout); loading = false; render(); });
  }
  function open() { previousFocus = document.activeElement; ov.hidden = false; input.focus(); render(); load(); }
  function close() { ov.hidden = true; if (previousFocus) previousFocus.focus(); }
  btn.addEventListener('click', open);
  retry.addEventListener('click', load);
  ov.querySelector('.szukaj-close').addEventListener('click', close);
  ov.addEventListener('click', function (e) { if (e.target === ov) close(); });
  input.addEventListener('input', render);
  input.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && results.firstElementChild) { e.preventDefault(); results.firstElementChild.click(); }
  });
  document.addEventListener('keydown', function (e) {
    if (ov.hidden) return;
    if (e.key === 'Escape') { e.preventDefault(); close(); }
    if (e.key === 'Tab') {
      var focusable = Array.from(ov.querySelectorAll('button:not([hidden]), input, a[href]'));
      var first = focusable[0], last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });
})();
