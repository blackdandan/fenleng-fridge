#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const baseline = JSON.parse(fs.readFileSync(new URL('../assets/flutter-oh-baseline.json', import.meta.url)));
export function inspectProject(root, run = spawnSync) {
  const errors = [];
  let sdkRoot = root;
  while (!fs.existsSync(path.join(sdkRoot, '.fvmrc')) && path.dirname(sdkRoot) !== sdkRoot) sdkRoot = path.dirname(sdkRoot);
  const config = path.join(sdkRoot, '.fvmrc');
  let value;
  try { value = JSON.parse(fs.readFileSync(config, 'utf8')).flutter; }
  catch { errors.push('Missing or invalid .fvmrc'); }
  const expected = `${baseline.sdk.forkAlias}/${baseline.sdk.commit}`;
  if (value !== expected) errors.push(`SDK lock must be ${expected}`);
  const sdk = path.join(sdkRoot, '.fvm', 'flutter_sdk');
  if (!fs.existsSync(sdk)) errors.push('FVM SDK link missing; install and use the fixed fork');
  else {
    const git = (...args) => run('git', ['-C', sdk, ...args], { encoding: 'utf8' });
    const head = git('rev-parse', 'HEAD');
    if (head.status !== 0 || head.stdout.trim() !== baseline.sdk.commit) errors.push('Installed SDK commit differs from baseline');
    const origin = git('remote', 'get-url', 'origin');
    if (origin.status !== 0 || origin.stdout.trim().replace(/\.git$/, '') !== baseline.sdk.repository.replace(/\.git$/, '')) errors.push('Installed SDK origin differs from baseline');
    const dart = path.join(sdk, 'bin', 'cache', 'dart-sdk', 'version');
    if (!fs.existsSync(dart) || fs.readFileSync(dart, 'utf8').trim() !== baseline.sdk.dart) errors.push('Installed Dart version differs from baseline');
  }
  // Public libraries have no application platform directories. App roots do.
  const isDirectory = platform => {
    try { return fs.statSync(path.join(root, platform)).isDirectory(); }
    catch { return false; }
  };
  if (baseline.platforms.some(platform => fs.existsSync(path.join(root, platform)))) {
    for (const platform of baseline.platforms) if (!isDirectory(platform)) errors.push(`Missing Day 1 ${platform} platform directory`);
  }
  return errors;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = path.resolve(process.argv[2] || process.cwd());
  const errors = inspectProject(root);
  for (const error of errors) process.stderr.write(`[flutter-oh] ${error}\n`);
  if (!errors.length) process.stdout.write('[flutter-oh] Fixed SDK baseline verified\n');
  process.exitCode = errors.length ? 1 : 0;
}
