import fs from 'node:fs';
const root = new URL('../', import.meta.url);
const tokens = JSON.parse(fs.readFileSync(new URL('contracts/design-tokens.json', root), 'utf8'));
const kebab = value => value.replace(/[A-Z]/g, char => '-' + char.toLowerCase());
const properties = values => Object.entries(values).map(([key, value]) => `  --fridge-${kebab(key)}: ${value};`).join('\n');
const dims = Object.fromEntries(Object.entries(tokens.dimensions).map(([key, value]) => [key, value + 'px']));
fs.writeFileSync(new URL('mini-program/packages/ui-kit/src/tokens.scss', root),
  `/* Generated from contracts/design-tokens.json; Figma-approved product mapping. */\n.fridge-theme {\n${properties(tokens.colors)}\n${properties(dims)}\n${properties(tokens.effects || {})}\n}\n.fridge-theme--dark {\n${properties(tokens.darkColors)}\n}\n`);
fs.writeFileSync(new URL('mini-program/packages/ui-kit/src/tokens.ts', root),
  `// Generated; base Fenleng tokens and approved product overrides remain traceable.\nexport const fridgeTokens = ${JSON.stringify(tokens)} as const;\n`);
const color = value => {
  if (value.startsWith('#')) return `Color(0xff${value.slice(1)})`;
  const [r,g,b,a] = value.match(/[\d.]+/g).map(Number);
  return `Color(0x${[Math.round(a * 255),r,g,b].map(n => n.toString(16).padStart(2,'0')).join('')})`;
};
const dartColors = values => Object.entries(values).map(([key,value]) => `    '${key}': ${color(value)},`).join('\n');
fs.writeFileSync(new URL('app/packages/ui_kit/lib/src/product_tokens.dart', root),
  `// Generated from contracts/design-tokens.json; do not hand-edit.\nimport 'package:flutter/painting.dart';\n\nabstract final class FridgeProductTokens {\n  static const light = <String, Color>{\n${dartColors(tokens.colors)}\n  };\n  static const dark = <String, Color>{\n${dartColors({...tokens.colors,...tokens.darkColors})}\n  };\n${Object.entries(tokens.dimensions).map(([key,value]) => `  static const double ${key} = ${value};`).join('\n')}\n}\n`);
console.log('Synchronized Fenleng base/product tokens into Flutter and mini UI kits.');
