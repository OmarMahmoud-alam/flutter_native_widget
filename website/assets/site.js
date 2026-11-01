// Language and theme are set before first paint by the inline script in
// each page's <head>; this file wires up the controls and the copy buttons.
(function () {
  const root = document.documentElement;
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch {} },
  };

  function setLang(lang) {
    root.dataset.lang = lang;
    root.lang = lang;
    root.dir = lang === 'ar' ? 'rtl' : 'ltr';
    store.set('fnw-lang', lang);
    const t = document.querySelector('meta[name="title-' + lang + '"]');
    if (t) document.title = t.content;
    document.dispatchEvent(new CustomEvent('langchange', { detail: lang }));
  }
  window.fnwSetLang = setLang;
  setLang(root.dataset.lang || 'ar');

  document.getElementById('lang')?.addEventListener('click', () =>
    setLang(root.dataset.lang === 'ar' ? 'en' : 'ar'));

  document.getElementById('theme')?.addEventListener('click', () => {
    const dark = root.dataset.theme
      ? root.dataset.theme === 'dark'
      : matchMedia('(prefers-color-scheme: dark)').matches;
    root.dataset.theme = dark ? 'light' : 'dark';
    store.set('fnw-theme', root.dataset.theme);
  });

  // Wrap every <pre> in a .code box with a copy button.
  window.fnwDecorateCode = function (scope) {
    scope.querySelectorAll('pre:not([data-done])').forEach(pre => {
      pre.dataset.done = '1';
      let box = pre.parentElement;
      if (!box.classList.contains('code')) {
        box = document.createElement('div');
        box.className = 'code';
        pre.replaceWith(box);
        box.appendChild(pre);
      }
      if (pre.dataset.label) {
        const l = document.createElement('span');
        l.className = 'label';
        l.textContent = pre.dataset.label;
        box.appendChild(l);
      }
      const b = document.createElement('button');
      b.className = 'copy';
      b.type = 'button';
      b.textContent = 'Copy';
      b.onclick = async () => {
        try { await navigator.clipboard.writeText(pre.innerText); b.textContent = 'Copied ✓'; }
        catch { b.textContent = 'Select & copy'; }
        setTimeout(() => (b.textContent = 'Copy'), 1500);
      };
      box.appendChild(b);
      if (window.Prism) Prism.highlightElement(pre.querySelector('code') || pre);
    });
  };
  fnwDecorateCode(document);
})();
