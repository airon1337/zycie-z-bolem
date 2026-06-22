(function () {
  var idx = null, loaded = false;
  function norm(s) {
    return (s || '').toLowerCase()
      .replace(/ą/g, 'a').replace(/ć/g, 'c').replace(/ę/g, 'e').replace(/ł/g, 'l')
      .replace(/ń/g, 'n').replace(/ó/g, 'o').replace(/ś/g, 's').replace(/ź/g, 'z').replace(/ż/g, 'z');
  }
  function esc(s) { return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  var menu = document.querySelector('.nav .menu') || document.querySelector('.nav');
  var btn = document.createElement('button');
  btn.className = 'szukaj-btn';
  btn.setAttribute('aria-label', 'Szukaj');
  btn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>';
  if (menu) { menu.appendChild(btn); }

  var ov = document.createElement('div');
  ov.className = 'szukaj-overlay';
  ov.style.display = 'none';
  ov.innerHTML = '<div class="szukaj-box"><input type="search" class="szukaj-input" placeholder="Szukaj artykułów..." autocomplete="off"><div class="szukaj-wyniki"></div></div>';
  document.body.appendChild(ov);

  var input = ov.querySelector('.szukaj-input');
  var wyniki = ov.querySelector('.szukaj-wyniki');

  function open() {
    ov.style.display = 'flex';
    setTimeout(function () { input.focus(); }, 30);
    if (!loaded) {
      loaded = true;
      fetch('/search-index.json').then(function (r) { return r.json(); }).then(function (d) { idx = d; }).catch(function () {});
    }
  }
  function close() { ov.style.display = 'none'; input.value = ''; wyniki.innerHTML = ''; }

  btn.addEventListener('click', open);
  ov.addEventListener('click', function (e) { if (e.target === ov) close(); });
  document.addEventListener('keydown', function (e) { if (e.key === 'Escape') close(); });

  input.addEventListener('input', function () {
    var q = norm(input.value.trim());
    if (!idx || q.length < 2) { wyniki.innerHTML = ''; return; }
    var res = idx.filter(function (a) { return norm(a.t).indexOf(q) >= 0 || norm(a.e).indexOf(q) >= 0; }).slice(0, 20);
    if (res.length === 0) { wyniki.innerHTML = '<div class="szukaj-brak">Brak wyników</div>'; return; }
    wyniki.innerHTML = res.map(function (a) {
      return '<a class="szukaj-wynik" href="/' + a.s + '.html"><strong>' + esc(a.t) + '</strong></a>';
    }).join('');
  });
})();
