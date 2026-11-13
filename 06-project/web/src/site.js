(() => {
  'use strict';
  const data = window.FRIDGE_SITE;
  if (!data) return;
  const languages = Object.keys(data.locales);
  const selector = document.querySelector('#language');
  const stored = () => {try {return localStorage.getItem('fridge.website.locale');} catch {return null;}};
  function resolve(value) {
    if (!value) return null;
    const normalized = value.replaceAll('_','-').toLowerCase();
    const exact = languages.find(x => x.toLowerCase() === normalized);
    if (exact) return exact;
    if (normalized.startsWith('zh')) return /tw|hk|hant/.test(normalized) ? 'zh-TW' : 'zh-CN';
    return languages.find(x => x.split('-')[0] === normalized.split('-')[0]) || null;
  }
  function deviceLocale() {
    return (navigator.languages || [navigator.language]).map(resolve).find(Boolean) || 'zh-CN';
  }
  function apply(preference) {
    const locale = resolve(preference) || deviceLocale();
    const messages = data.locales[locale];
    document.documentElement.lang = locale;
    document.documentElement.dir = locale === 'ar' ? 'rtl' : 'ltr';
    document.querySelectorAll('[data-i18n]').forEach(el => {el.textContent = messages[el.dataset.i18n];});
    const headline = document.querySelector('[data-i18n="headline"]');
    if (headline && locale.startsWith('zh')) {
      const [first,...rest] = messages.headline.split('，');
      headline.replaceChildren(document.createTextNode(first+'，'),document.createElement('br'),document.createTextNode(rest.join('，')));
    }
    document.querySelectorAll('[data-core]').forEach(el => {el.textContent = messages[el.dataset.core];});
    document.querySelectorAll('[data-format]').forEach(el => {
      el.textContent = messages[el.dataset.format].replace('{count}',new Intl.NumberFormat(locale).format(Number(el.dataset.count)));
    });
    document.querySelectorAll('[data-label]').forEach(el => {el.setAttribute('aria-label',messages[el.dataset.label]);});
    document.querySelectorAll('nav').forEach(el => {el.setAttribute('aria-label',messages.how);});
    document.querySelectorAll('.legal-document .table').forEach(el => {el.tabIndex = 0;el.setAttribute('aria-label',messages[document.body.dataset.legal]);});
    document.title = (document.body.dataset.legal ? messages[document.body.dataset.legal] + ' · ' : '') + messages.name;
    const description = document.querySelector('meta[name=description]');
    if (description) description.content = messages.lead;
    if (selector) {
      selector.setAttribute('aria-label',messages.language);
      selector.options[0].textContent = messages.system;
      selector.value = resolve(preference) || 'system';
    }
    document.dispatchEvent(new CustomEvent('fridge:locale',{detail:locale}));
  }
  if (selector) {
    selector.append(new Option('', 'system'));
    for (const locale of languages) selector.append(new Option(data.locales[locale]._localeName,locale));
    selector.addEventListener('change',() => {
      const preference = selector.value === 'system' ? null : selector.value;
      try {if (preference) localStorage.setItem('fridge.website.locale',preference); else localStorage.removeItem('fridge.website.locale');} catch { /* Browsing remains available if local preferences cannot persist. */ }
      apply(preference);
    });
  }
  window.addEventListener('languagechange',() => {if (!stored()) apply(null);});
  apply(stored());
})();
