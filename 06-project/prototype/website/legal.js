(() => {
  'use strict';
  const type = document.body.dataset.legal;
  const root = document.querySelector('#legal-content');
  const entry = window.FRIDGE_LEGAL?.[type];
  if (!entry) { root.textContent = '正文暂未加载，请刷新页面重试，或返回官网。'; return; }
  document.title = entry.title + ' · 冰箱库存管理';
  const heading = document.createElement('h1'); heading.textContent = entry.title; root.append(heading);
  const meta = document.createElement('p'); meta.className = 'legal-meta'; meta.textContent = '版本 ' + entry.version + ' · 产品审阅草案'; root.append(meta);
  let table = null;
  for (const line of entry.paragraphs) {
    if (!line.trim() || line.startsWith('# ')) continue;
    if (line.startsWith('|')) {
      const cells = line.split('|').slice(1, -1).map(cell => cell.trim());
      if (cells.every(cell => /^:?-+:?$/.test(cell))) continue;
      const isHeader = !table;
      if (!table) {
        const wrap = document.createElement('div'); wrap.className = 'legal-table-wrap';
        table = document.createElement('table'); table.className = 'legal-table';
        wrap.append(table); root.append(wrap);
      }
      const row = document.createElement('tr');
      for (const text of cells) {
        const cell = document.createElement(isHeader ? 'th' : 'td');
        if (isHeader) cell.scope = 'col';
        cell.textContent = text; row.append(cell);
      }
      table.append(row); continue;
    }
    table = null;
    const element = document.createElement(line.startsWith('## ') ? 'h2' : 'p');
    element.textContent = line.replace(/^## /, '');
    root.append(element);
  }
})();
