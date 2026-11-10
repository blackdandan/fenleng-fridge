#!/usr/bin/env node
// check-copyright-source.js — 软著源码文本完整性与最低行数 (3000行) 自动化后置检查
import fs from 'node:fs';
import path from 'node:path';

function findFiles(dir, predicate) {
  if (!fs.existsSync(dir)) return [];
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) results.push(...findFiles(fullPath, predicate));
    else if (entry.isFile() && predicate(entry.name)) {
      results.push(fullPath);
    }
  }
  return results;
}

function countLines(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return content.split('\n').length;
  } catch {
    return 0;
  }
}

function resolveCurrentDeliverablesDir(rootDir) {
  if (!fs.existsSync(rootDir)) return rootDir;
  const versions = fs.readdirSync(rootDir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^v\d+$/i.test(entry.name))
    .map((entry) => entry.name)
    .sort((a, b) => Number(a.slice(1)) - Number(b.slice(1)));
  return versions.length > 0 ? path.join(rootDir, versions[versions.length - 1]) : rootDir;
}

function main() {
  const deliverablesRoot = path.resolve(process.cwd(), 'deliverables');
  const deliverablesDir = resolveCurrentDeliverablesDir(deliverablesRoot);
  if (!fs.existsSync(deliverablesDir)) {
    // 若尚未生成 deliverables 目录则直接跳过
    return;
  }

  const workDir = path.resolve(process.cwd(), 'work');
  // Word/TXT sources are intentionally kept in work; vN only contains PDF/Markdown.
  const files = findFiles(workDir, (name) =>
    (name.includes('源程序鉴别材料') || name.includes('source-material')) &&
    name.endsWith('.txt')
  ).filter((file) => path.dirname(file) === workDir);
  let totalLines = 0;
  let hasEmptyFile = false;

  for (const file of files) {
    const lines = countLines(file);
    if (lines === 0) hasEmptyFile = true;
    totalLines += lines;
  }

  console.log(`✓ [check-copyright-source] 当前交付版本 ${path.basename(deliverablesDir)}: work/ 源码材料 ${files.length} 个，源码累计 ${totalLines} 行。`);

  if (totalLines > 0 && totalLines < 3000) {
    console.warn(`⚠ 警告: 当前软著源码提取行数 (${totalLines} 行) 低于标准软著登记建议的 3000 行基线，请确认是否需要补充更多模块代码。`);
  }

  if (hasEmptyFile) {
    console.warn(`⚠ 警告: 在当前交付版本目录中检测到 0 字节文件，请在提交办理前进行人工确认。`);
  }
}

main();
