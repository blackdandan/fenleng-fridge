#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const errors = [];
const baseline = JSON.parse(fs.readFileSync(new URL('../assets/flutter-oh-baseline.json', import.meta.url))).harmonyos;
const homes = ['HOS_SDK_HOME', 'DEVECO_SDK_HOME', 'OHOS_SDK_HOME'].map(k => ({ key: k, path: process.env[k] })).filter(x => x.path && fs.existsSync(x.path));
if (!homes.length && process.platform === 'darwin' && !('HOS_SDK_HOME' in process.env) && !('DEVECO_SDK_HOME' in process.env) && fs.existsSync('/Applications/DevEco-Studio.app/Contents/sdk')) {
  homes.push({ key: 'DEVECO_SDK_HOME', path: '/Applications/DevEco-Studio.app/Contents/sdk' });
}
if (!homes.length) errors.push('No HarmonyOS SDK directory configured; install the matching DevEco SDK and set HOS_SDK_HOME/DEVECO_SDK_HOME');
const sdkVersions = homes.map(home => {
  for (const relative of ['default/sdk-pkg.json', 'sdk-pkg.json']) {
    try {
      const data = JSON.parse(fs.readFileSync(path.join(home.path, relative), 'utf8')).data;
      return { key: home.key, version: data.version, api: Number(data.apiVersion) };
    } catch {}
  }
  for (const relative of ['default/openharmony/ets/oh-uni-package.json', 'default/hms/toolchains/uni-package.json']) {
    try {
      const pkg = JSON.parse(fs.readFileSync(path.join(home.path, relative), 'utf8'));
      if (pkg.version && pkg.apiVersion) return { key: home.key, version: pkg.version, api: Number(pkg.apiVersion) };
    } catch {}
  }
  return { key: home.key, version: null, api: null };
});
if (!sdkVersions.some(sdk => sdk.version === baseline.sdk && sdk.api === baseline.api)) errors.push(`HarmonyOS SDK must match ${baseline.sdk} (API ${baseline.api})`);
const commands = process.platform === 'win32' ? ['java', 'node', 'ohpm.cmd', 'hvigorw.bat', 'hdc.exe'] : ['java', 'node', 'ohpm', 'hvigorw', 'hdc'];
const tools = commands.map(command => {
  const result = spawnSync(command, command.startsWith('java') ? ['-version'] : command.startsWith('hdc') ? ['-v'] : ['--version'], { encoding: 'utf8', timeout: 15000, shell: process.platform === 'win32' });
  const available = !result.error && result.status === 0;
  if (!available) errors.push(`${command} not available on PATH`);
  const version = available ? (result.stdout || result.stderr).trim().split('\n')[0] : null;
  const name = command.replace(/\.(cmd|bat|exe)$/, '');
  if (available && ['ohpm', 'hvigorw', 'hdc'].includes(name) && version.replace(/^Ver:\s*/, '') !== baseline[name]) errors.push(`${name} version must match ${baseline[name]}`);
  if (available && ['java', 'node'].includes(name)) {
    const major = Number(version.match(/(?:version\s+"|v)(\d+)/)?.[1]);
    if (!major || major < baseline[name === 'java' ? 'minimumJava' : 'minimumNode']) errors.push(`${name} version is below the supported baseline`);
  }
  return { command, available, version };
});
const result = { sdkDirectories: homes, sdkVersions, tools, errors, status: errors.length ? 'not-ready' : 'environment-detected', note: 'Environment detection does not prove HAP build, signing or runtime compatibility' };
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.exitCode = errors.length ? 1 : 0;
