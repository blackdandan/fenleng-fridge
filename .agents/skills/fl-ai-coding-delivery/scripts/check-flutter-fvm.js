#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { inspectProject } from './check-flutter-oh.mjs';

const cwd = process.cwd();
const baseline = JSON.parse(fs.readFileSync(new URL('../assets/flutter-oh-baseline.json', import.meta.url)));

// 判断是否是 Flutter 移动端项目
const isFlutterProject =
  fs.existsSync(path.join(cwd, 'pubspec.yaml')) ||
  fs.existsSync(path.join(cwd, 'melos.yaml')) ||
  fs.existsSync(path.join(cwd, '.fvmrc')) ||
  fs.existsSync(path.join(cwd, '.fvm', 'fvm_config.json'));

if (!isFlutterProject) {
  // 非 Flutter 项目跳过此 Hook
  process.exit(0);
}

// 检查 fvm 工具是否安装
const fvmCheck = spawnSync('fvm', ['--version'], { encoding: 'utf8', shell: true });
if (fvmCheck.status !== 0) {
  console.warn(
    '[check-flutter-fvm] Warning: FVM command is not installed on this machine.\n' +
      `Please run "dart pub global activate fvm ${baseline.fvmVersion}" to install FVM for version isolation.`
  );
  process.exit(1);
}
if (fvmCheck.stdout.trim() !== baseline.fvmVersion) {
  console.error(`[check-flutter-fvm] FVM version must match ${baseline.fvmVersion}`);
  process.exit(1);
}

// 检查 Melos Monorepo 拓扑
let workspaceRoot = cwd;
while (!fs.existsSync(path.join(workspaceRoot, '.fvmrc')) && path.dirname(workspaceRoot) !== workspaceRoot) {
  workspaceRoot = path.dirname(workspaceRoot);
}
const hasMelosConfig = fs.existsSync(path.join(workspaceRoot, 'melos.yaml'));
const hasPackagesDir = fs.existsSync(path.join(workspaceRoot, 'packages'));

if (!hasMelosConfig || !hasPackagesDir) {
  console.warn(
    '[check-flutter-fvm] Warning: Flutter project lacks melos.yaml or packages/ directory.\n' +
      'Fenlengtechbase requires Day-1 Melos Monorepo topology (packages/core, ui_kit, navigation, features/*).\n' +
      'Do NOT downgrade to single-package for MVP.'
  );
}

// Melos members inherit the nearest ancestor SDK lock; inspectProject validates it.
const baselineErrors = inspectProject(cwd);
if (baselineErrors.length) {
  for (const error of baselineErrors) console.error(`[check-flutter-fvm] ${error}`);
  process.exit(1);
}
console.log('[check-flutter-fvm] OK: Flutter-OH source, commit and Dart baseline verified.');
process.exit(0);
