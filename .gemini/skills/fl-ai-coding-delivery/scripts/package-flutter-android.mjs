#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { inspectProject } from './check-flutter-oh.mjs';

const MOCIKA_VERSION = 'v1.4.0-beta.1';
const MOCIKA_COMMIT = 'af940a77010375ffd4ae63f959ae4e9d0865b877';
const MOCIKA_SOURCE_SHA256 = 'bfb4149ecf437f02816fb488fb22787d21efd35515b859f4b44b6073562bfe42';
const MOCIKA_MACOS_DMG_SHA256 = '0566953530039a342bfa25cb105fda458882bfb90b11884975055988fe57f7f9';
const MOCIKA_WINDOWS_SETUP_SHA256 = 'e30840feaa39246a37e179cbb3736875d50d49b3866771ef703c06153bd35abc';
const MOCIKA_RESOURCES_SHA256 = '2ede44d6e298888faed846354747e7426c80c7a8791a040bd749ed4aba702251';
const MOCIKA_WINDOWS_RESOURCES_SHA256 = 'b2ba9da963350b87a4f091a5fc48920b66672e9a3da800152422ed971cd39977';
const MOCIKA_APKTOOL_SHA256 = 'b947b945b4bc455609ba768d071b64d9e63834079898dbaae15b67bf03bcd362';
const MOCIKA_APKSIGNER_SHA256 = '2defad215d7ff52968a409cde528cdaef7918b115e276b8e3378ca7a178e4180';
const MOCIKA_SOURCE_URL = `https://github.com/mocikadev/mocika-shield/archive/refs/tags/${MOCIKA_VERSION}.tar.gz`;
const MOCIKA_MACOS_DMG_URL = `https://github.com/mocikadev/mocika-shield/releases/download/${MOCIKA_VERSION}/MocikaShield_1.4.0-beta.1_macos_universal.dmg`;
const MOCIKA_WINDOWS_SETUP_URL = `https://github.com/mocikadev/mocika-shield/releases/download/${MOCIKA_VERSION}/MocikaShield_1.4.0-beta.1_windows_x64_setup.exe`;

function usage(message) {
  if (message) console.error(message);
  console.error('usage: node package-flutter-android.mjs --project <flutter-root> --mode <debug|release> --channel <china|global> [--device <adb-serial>]');
  process.exit(2);
}

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function run(command, args, options = {}) {
  const isWindowsBatch = process.platform === 'win32' && /\.(bat|cmd)$/i.test(command);
  const executable = isWindowsBatch ? 'cmd.exe' : command;
  const executableArgs = isWindowsBatch ? ['/d', '/s', '/c', command, ...args] : args;
  const result = spawnSync(executable, executableArgs, {
    cwd: options.cwd,
    env: options.env ?? process.env,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    stdio: options.capture ? 'pipe' : 'inherit',
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    if (options.capture) {
      if (result.stdout) process.stdout.write(options.redact?.(result.stdout) ?? result.stdout);
      if (result.stderr) process.stderr.write(options.redact?.(result.stderr) ?? result.stderr);
    }
    throw new Error(`${command} failed with exit code ${result.status}`);
  }
  return result;
}

function mocikaShieldName() {
  return process.platform === 'win32' ? 'shield.exe' : 'shield';
}

function mocikaResourcesSha256() {
  return process.platform === 'win32' ? MOCIKA_WINDOWS_RESOURCES_SHA256 : MOCIKA_RESOURCES_SHA256;
}

function resolveFvm() {
  if (process.platform !== 'win32') return 'fvm';
  const result = spawnSync('where.exe', ['fvm.exe'], { encoding: 'utf8' });
  if (result.status === 0 && result.stdout?.trim()) return result.stdout.trim().split(/\r?\n/)[0];
  return 'fvm.bat';
}

function resolveFlutterBuildEnvironment() {
  const env = { ...process.env };
  const macDefaultSdk = '/Applications/DevEco-Studio.app/Contents/sdk';
  let sdkHome = env.DEVECO_SDK_HOME || env.HOS_SDK_HOME || (process.platform === 'darwin' && fs.existsSync(macDefaultSdk) ? macDefaultSdk : undefined);
  if (sdkHome && fs.existsSync(sdkHome)) {
    const sdkPkgPath = path.join(sdkHome, 'default', 'sdk-pkg.json');
    if (!fs.existsSync(sdkPkgPath)) {
      for (const candidate of ['default/openharmony/ets/oh-uni-package.json', 'default/hms/toolchains/uni-package.json']) {
        const candidatePath = path.join(sdkHome, candidate);
        if (fs.existsSync(candidatePath)) {
          try {
            const pkg = JSON.parse(fs.readFileSync(candidatePath, 'utf8'));
            if (pkg.apiVersion && pkg.version) {
              const bridge = path.join(os.homedir(), '.cache', 'fenleng', 'harmonyos-sdk-bridge');
              fs.mkdirSync(path.join(bridge, 'default'), { recursive: true });
              fs.writeFileSync(path.join(bridge, 'default', 'sdk-pkg.json'), JSON.stringify({ data: { apiVersion: String(pkg.apiVersion), version: String(pkg.version) } }, null, 2) + '\n');
              for (const sub of ['hms', 'openharmony']) {
                const src = path.join(sdkHome, 'default', sub);
                const dst = path.join(bridge, 'default', sub);
                if (fs.existsSync(src) && !fs.existsSync(dst)) fs.symlinkSync(src, dst);
              }
              sdkHome = bridge;
              break;
            }
          } catch {}
        }
      }
    }
    env.DEVECO_SDK_HOME = sdkHome;
    env.HOS_SDK_HOME = sdkHome;
  }
  return env;
}

function resolveWindowsMsvcEnvironment() {
  if (process.platform !== 'win32') return process.env;
  const programFiles = process.env.ProgramFiles || 'C:\\Program Files';
  const programFilesX86 = process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)';
  const candidates = [
    path.join(programFilesX86, 'Microsoft Visual Studio', '2022', 'BuildTools', 'VC', 'Auxiliary', 'Build', 'vcvars64.bat'),
    path.join(programFiles, 'Microsoft Visual Studio', '2022', 'BuildTools', 'VC', 'Auxiliary', 'Build', 'vcvars64.bat'),
    path.join(programFilesX86, 'Microsoft Visual Studio', '2022', 'Community', 'VC', 'Auxiliary', 'Build', 'vcvars64.bat'),
    path.join(programFilesX86, 'Microsoft Visual Studio', '2019', 'BuildTools', 'VC', 'Auxiliary', 'Build', 'vcvars64.bat'),
  ];
  const vcvars = candidates.find((candidate) => fs.existsSync(candidate));
  if (!vcvars) throw new Error('Windows Rust/Cargo builds require Visual C++ Build Tools with vcvars64.bat');
  const probe = spawnSync('cmd.exe', [
    '/d', '/c', 'call', vcvars, '&&', 'set',
  ], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  if (probe.error) throw probe.error;
  if (probe.status !== 0) throw new Error(`Unable to load the Windows MSVC build environment from ${vcvars}`);
  const environment = { ...process.env };
  for (const line of probe.stdout.split(/\r?\n/)) {
    const separator = line.indexOf('=');
    if (separator > 0) environment[line.slice(0, separator)] = line.slice(separator + 1);
  }
  return environment;
}

function sha256File(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function assertChecksum(file, expected, label) {
  const actual = sha256File(file);
  if (actual !== expected) throw new Error(`${label} checksum mismatch: expected ${expected}, got ${actual}`);
}

function parseProperties(file) {
  const values = {};
  for (const rawLine of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const index = line.search(/[:=]/);
    if (index < 1) continue;
    values[line.slice(0, index).trim()] = line.slice(index + 1).trim();
  }
  return values;
}

function findUp(start, candidates) {
  let current = path.resolve(start);
  while (true) {
    for (const candidate of candidates) {
      if (fs.existsSync(path.join(current, candidate))) return path.join(current, candidate);
    }
    const parent = path.dirname(current);
    if (parent === current) return undefined;
    current = parent;
  }
}

async function download(url, target) {
  const response = await fetch(url, { redirect: 'follow' });
  if (!response.ok) throw new Error(`Download failed (${response.status}): ${url}`);
  fs.writeFileSync(target, Buffer.from(await response.arrayBuffer()));
}

function assertPreparedMocika(cacheRoot) {
  const shield = path.join(cacheRoot, 'bin', mocikaShieldName());
  const resources = path.join(cacheRoot, 'resources', 'resources.zip');
  const apktool = path.join(cacheRoot, 'lib', 'apktool.jar');
  const bundledApksigner = path.join(cacheRoot, 'lib', 'apksigner.jar');
  const marker = path.join(cacheRoot, '.ready.json');
  if (![shield, resources, apktool, bundledApksigner, marker].every((file) => fs.existsSync(file))) return undefined;
  const ready = JSON.parse(fs.readFileSync(marker, 'utf8'));
  if (ready.version !== MOCIKA_VERSION || ready.commit !== MOCIKA_COMMIT ||
      (ready.platform && ready.platform !== process.platform) ||
      ready.shieldSha256 !== sha256File(shield)) return undefined;
  assertChecksum(resources, mocikaResourcesSha256(), 'Mocika runtime resources');
  assertChecksum(apktool, MOCIKA_APKTOOL_SHA256, 'Mocika apktool');
  assertChecksum(bundledApksigner, MOCIKA_APKSIGNER_SHA256, 'Mocika bundled apksigner');
  return { root: cacheRoot, shield };
}

function stageMocikaPackage(cacheRoot, sourceDir, toolsRoot, releaseSha256) {
  const stagedPackage = fs.mkdtempSync(path.join(os.tmpdir(), 'fenleng-mocika-package-'));
  try {
    const shield = path.join(sourceDir, 'target', 'release', mocikaShieldName());
    const resources = path.join(toolsRoot, 'resources', 'resources.zip');
    const apktool = path.join(toolsRoot, 'tools', 'apktool.jar');
    const bundledApksigner = path.join(toolsRoot, 'tools', 'apksigner.jar');
    if (![shield, resources, apktool, bundledApksigner].every((file) => fs.existsSync(file))) {
      throw new Error('Mocika package is missing the pinned CLI, runtime resources, apktool, or apksigner');
    }
    fs.mkdirSync(path.join(stagedPackage, 'bin'), { recursive: true });
    fs.mkdirSync(path.join(stagedPackage, 'lib'), { recursive: true });
    fs.mkdirSync(path.join(stagedPackage, 'resources'), { recursive: true });
    const stagedShield = path.join(stagedPackage, 'bin', mocikaShieldName());
    const stagedResources = path.join(stagedPackage, 'resources', 'resources.zip');
    const stagedApktool = path.join(stagedPackage, 'lib', 'apktool.jar');
    const stagedApksigner = path.join(stagedPackage, 'lib', 'apksigner.jar');
    fs.copyFileSync(shield, stagedShield);
    fs.copyFileSync(resources, stagedResources);
    fs.copyFileSync(apktool, stagedApktool);
    fs.copyFileSync(bundledApksigner, stagedApksigner);
    assertChecksum(stagedResources, mocikaResourcesSha256(), 'Mocika runtime resources');
    assertChecksum(stagedApktool, MOCIKA_APKTOOL_SHA256, 'Mocika apktool');
    assertChecksum(stagedApksigner, MOCIKA_APKSIGNER_SHA256, 'Mocika bundled apksigner');
    fs.writeFileSync(path.join(stagedPackage, '.ready.json'), JSON.stringify({
      version: MOCIKA_VERSION,
      commit: MOCIKA_COMMIT,
      platform: process.platform,
      sourceSha256: MOCIKA_SOURCE_SHA256,
      releaseSha256,
      resourcesSha256: mocikaResourcesSha256(),
      shieldSha256: sha256File(stagedShield),
    }, null, 2));
    fs.mkdirSync(path.dirname(cacheRoot), { recursive: true });
    fs.cpSync(stagedPackage, cacheRoot, { recursive: true, force: true });
    return assertPreparedMocika(cacheRoot);
  } finally {
    fs.rmSync(stagedPackage, { recursive: true, force: true });
  }
}

function findWindowsMocikaInstall() {
  const localAppData = process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local');
  const candidates = [
    path.join(localAppData, 'MocikaShield'),
    path.join(localAppData, 'Programs', 'MocikaShield'),
    path.join(localAppData, 'Mocika Shield'),
    path.join(localAppData, 'Programs', 'Mocika Shield'),
  ];
  return candidates.find((root) => [
    path.join(root, 'resources', 'resources.zip'),
    path.join(root, 'tools', 'apktool.jar'),
    path.join(root, 'tools', 'apksigner.jar'),
  ].every((file) => fs.existsSync(file)));
}

async function prepareWindowsMocika(cacheRoot) {
  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'fenleng-mocika-windows-'));
  try {
    let installRoot = findWindowsMocikaInstall();
    if (!installRoot) {
      const installer = path.join(staging, 'MocikaShield_windows_x64_setup.exe');
      await download(MOCIKA_WINDOWS_SETUP_URL, installer);
      assertChecksum(installer, MOCIKA_WINDOWS_SETUP_SHA256, 'Mocika Windows release');
      run(installer, ['/S'], { cwd: staging, capture: true });
      installRoot = findWindowsMocikaInstall();
    }
    if (!installRoot) throw new Error('Pinned Windows Mocika is not installed at the expected application location');

    const sourceArchive = path.join(staging, 'source.tar.gz');
    await download(MOCIKA_SOURCE_URL, sourceArchive);
    assertChecksum(sourceArchive, MOCIKA_SOURCE_SHA256, 'Mocika source archive');
    run('tar', ['-xzf', sourceArchive, '-C', staging], { capture: true });
    const sourceRoot = fs.readdirSync(staging, { withFileTypes: true })
      .find((entry) => entry.isDirectory() && entry.name.startsWith('mocika-shield-'));
    if (!sourceRoot) throw new Error('Mocika source archive has an unexpected layout');
    const sourceDir = path.join(staging, sourceRoot.name);
    const cargo = process.env.CARGO || 'cargo';
    run(cargo, ['build', '--release', '--locked', '-p', 'shield-cli'], {
      cwd: sourceDir,
      capture: true,
      env: resolveWindowsMsvcEnvironment(),
    });
    return stageMocikaPackage(cacheRoot, sourceDir, installRoot, MOCIKA_WINDOWS_SETUP_SHA256);
  } finally {
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

async function prepareMocika() {
  const cacheRoot = path.join(os.homedir(), '.cache', 'fenleng', 'android-hardening', `mocika-${MOCIKA_VERSION}-${MOCIKA_COMMIT.slice(0, 12)}`);
  const prepared = assertPreparedMocika(cacheRoot);
  if (prepared) return prepared;
  if (process.platform === 'win32') return prepareWindowsMocika(cacheRoot);
  if (process.platform !== 'darwin') {
    throw new Error('Automatic Mocika preparation currently supports Windows and macOS; prepare the pinned Mocika CLI package on another host');
  }

  const staging = fs.mkdtempSync(path.join(os.tmpdir(), 'fenleng-mocika-prepare-'));
  let mountPoint;
  try {
    const sourceArchive = path.join(staging, 'source.tar.gz');
    const dmg = path.join(staging, 'MocikaShield.dmg');
    await download(MOCIKA_SOURCE_URL, sourceArchive);
    await download(MOCIKA_MACOS_DMG_URL, dmg);
    assertChecksum(sourceArchive, MOCIKA_SOURCE_SHA256, 'Mocika source archive');
    assertChecksum(dmg, MOCIKA_MACOS_DMG_SHA256, 'Mocika macOS release');
    run('tar', ['-xzf', sourceArchive, '-C', staging], { capture: true });
    const sourceRoot = fs.readdirSync(staging, { withFileTypes: true })
      .find((entry) => entry.isDirectory() && entry.name.startsWith('mocika-shield-'));
    if (!sourceRoot) throw new Error('Mocika source archive has an unexpected layout');
    const sourceDir = path.join(staging, sourceRoot.name);
    const cargo = process.env.CARGO || 'cargo';
    run(cargo, ['build', '--release', '--locked', '-p', 'shield-cli'], { cwd: sourceDir, capture: true });
    const attach = run('hdiutil', ['attach', '-nobrowse', '-readonly', dmg], { capture: true }).stdout;
    mountPoint = attach.split(/\r?\n/).map((line) => line.match(/(\/Volumes\/.*)$/)?.[1]).find(Boolean);
    if (!mountPoint) throw new Error('Unable to mount the pinned Mocika release');
    const appResources = path.join(mountPoint, 'MocikaShield.app', 'Contents', 'Resources');
    return stageMocikaPackage(cacheRoot, sourceDir, appResources, MOCIKA_MACOS_DMG_SHA256);
  } finally {
    if (mountPoint) spawnSync('hdiutil', ['detach', mountPoint], { encoding: 'utf8' });
    fs.rmSync(staging, { recursive: true, force: true });
  }
}

function findApkSigner() {
  const sdk = process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME ||
    (process.platform === 'darwin' ? path.join(os.homedir(), 'Library', 'Android', 'sdk') : undefined);
  if (!sdk) throw new Error('ANDROID_SDK_ROOT or ANDROID_HOME is required');
  const buildTools = path.join(sdk, 'build-tools');
  const versions = fs.readdirSync(buildTools, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  for (const version of versions) {
    const candidate = path.join(buildTools, version, process.platform === 'win32' ? 'apksigner.bat' : 'apksigner');
    if (fs.existsSync(candidate)) return candidate;
  }
  throw new Error(`Android apksigner was not found under ${buildTools}`);
}

function certificateDigest(apksigner, apk) {
  const verify = run(apksigner, ['verify', '--verbose', '--print-certs', apk], { capture: true });
  const output = `${verify.stdout}\n${verify.stderr}`;
  const match = output.match(/Signer #1 certificate SHA-256 digest:\s*([0-9a-f]+)/i);
  if (!match) throw new Error(`Unable to read signing certificate digest from ${apk}`);
  return match[1].toLowerCase();
}

function resolveAdb() {
  const sdk = process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME ||
    (process.platform === 'darwin' ? path.join(os.homedir(), 'Library', 'Android', 'sdk') : undefined);
  if (!sdk) throw new Error('ANDROID_SDK_ROOT or ANDROID_HOME is required for the release runtime gate');
  const adb = path.join(sdk, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
  if (!fs.existsSync(adb)) throw new Error(`Android adb was not found at ${adb}`);
  return adb;
}

function verifyColdStart(adb, serial, apk) {
  if (!serial) {
    throw new Error('Release hardening requires --device <adb-serial>; an installable APK is not a publishable APK until a physical-device cold start passes');
  }
  const aapt = path.join(path.dirname(path.dirname(adb)), 'build-tools');
  const versions = fs.readdirSync(aapt, { withFileTypes: true })
    .filter((entry) => entry.isDirectory()).map((entry) => entry.name)
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  const aaptBin = versions.map((version) => path.join(aapt, version, process.platform === 'win32' ? 'aapt.exe' : 'aapt'))
    .find((candidate) => fs.existsSync(candidate));
  if (!aaptBin) throw new Error('Android aapt is required for the release runtime gate');
  const badging = run(aaptBin, ['dump', 'badging', apk], { capture: true }).stdout;
  const packageName = badging.match(/^package: name='([^']+)'/m)?.[1];
  const launchableActivity = badging.match(/^launchable-activity: name='([^']+)'/m)?.[1];
  if (!packageName || !launchableActivity) throw new Error('Unable to resolve package or launcher activity from hardened APK');
  run(adb, ['-s', serial, 'get-state'], { capture: true });
  const qemu = run(adb, ['-s', serial, 'shell', 'getprop', 'ro.kernel.qemu'], { capture: true }).stdout.trim();
  if (qemu === '1') throw new Error('Release hardening runtime gate requires a physical Android device, not an emulator');
  run(adb, ['-s', serial, 'install', '-r', apk], { capture: true });
  run(adb, ['-s', serial, 'logcat', '-c'], { capture: true });
  run(adb, ['-s', serial, 'shell', 'am', 'force-stop', packageName], { capture: true });
  run(adb, ['-s', serial, 'shell', 'am', 'start', '-n', `${packageName}/${launchableActivity}`], { capture: true });
  const deadline = Date.now() + 10_000;
  let pid = '';
  let sawAlive = false;
  while (Date.now() < deadline) {
    const result = spawnSync(adb, ['-s', serial, 'shell', 'pidof', packageName], { encoding: 'utf8' });
    pid = result.stdout?.trim() ?? '';
    if (pid) sawAlive = true;
    if (!pid && sawAlive) break;
    const waitUntil = Date.now() + 500;
    while (Date.now() < waitUntil) Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 100);
  }
  if (!pid) throw new Error(`Hardened APK failed the physical-device cold-start gate: ${packageName} did not remain alive for 10 seconds on ${serial}`);
  const logcat = run(adb, ['-s', serial, 'logcat', '-d', '-v', 'brief'], { capture: true }).stdout;
  const crashMarkers = logcat.split(/\r?\n/).filter((line) =>
    line.includes(packageName) && /FATAL EXCEPTION|Fatal signal|SIGSEGV|Process:/i.test(line));
  if (crashMarkers.length > 0) {
    throw new Error(`Hardened APK emitted fatal crash markers during the physical-device cold-start gate: ${packageName}`);
  }
  return { serial, packageName, launchableActivity, pid, stableForSeconds: 10 };
}

async function main() {
  const projectRoot = path.resolve(option('--project') ?? '');
  const mode = option('--mode');
  const channel = option('--channel');
  const device = option('--device') ?? process.env.ANDROID_SERIAL;
  if (!option('--project') || !['debug', 'release'].includes(mode) || !['china', 'global'].includes(channel)) {
    usage('--project, --mode and an explicit --channel china|global are required');
  }
  if (!fs.existsSync(path.join(projectRoot, 'pubspec.yaml'))) usage(`Not a Flutter root: ${projectRoot}`);
  if (!findUp(projectRoot, ['.fvmrc', path.join('.fvm', 'fvm_config.json')])) {
    throw new Error('Flutter SDK is not pinned by .fvmrc or .fvm/fvm_config.json');
  }

  const baselineErrors = inspectProject(projectRoot);
  if (baselineErrors.length) throw new Error(`Flutter-OH baseline preflight failed: ${baselineErrors.join('; ')}`);

  const standardProperties = path.join(projectRoot, 'android', 'signing', 'credentials.properties');
  const legacyProperties = path.join(projectRoot, 'android', 'key.properties');
  const propertiesFile = fs.existsSync(standardProperties) ? standardProperties : legacyProperties;
  if (!fs.existsSync(propertiesFile)) {
    throw new Error('Android signing credentials are missing; expected android/signing/credentials.properties or legacy android/key.properties');
  }
  const signing = parseProperties(propertiesFile);
  for (const key of ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']) {
    if (!signing[key]) throw new Error(`Missing ${key} in android/signing/credentials.properties`);
  }
  const keystore = path.resolve(path.join(projectRoot, 'android'), signing.storeFile.replaceAll('\\', path.sep));
  if (!fs.existsSync(keystore)) throw new Error(`Signing keystore is missing: ${keystore}`);

  run(
    resolveFvm(),
    ['flutter', 'build', 'apk', `--${mode}`, `--dart-define=APP_RELEASE_CHANNEL=${channel}`],
    { cwd: projectRoot, env: resolveFlutterBuildEnvironment() },
  );
  const rawApk = path.join(projectRoot, 'build', 'app', 'outputs', 'flutter-apk', `app-${mode}.apk`);
  if (!fs.existsSync(rawApk)) throw new Error(`Flutter did not produce ${rawApk}`);
  const apksigner = findApkSigner();
  const sourceCertificateSha256 = certificateDigest(apksigner, rawApk);

  if (mode === 'debug') {
    console.log(JSON.stringify({ mode, channel, hardened: false, apk: rawApk, sha256: sha256File(rawApk), certificateSha256: sourceCertificateSha256 }, null, 2));
    return;
  }

  if (channel === 'global') {
    console.log(JSON.stringify({
      mode,
      channel,
      hardened: false,
      hardener: 'none',
      apk: rawApk,
      sha256: sha256File(rawApk),
      certificateSha256: sourceCertificateSha256,
    }, null, 2));
    return;
  }

  const hardenedApk = path.join(path.dirname(rawApk), 'app-release-hardened.apk');
  fs.rmSync(hardenedApk, { force: true });

  const mocika = await prepareMocika();
  const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'fenleng-mocika-package-'));
  try {
    const protectedUnsigned = path.join(workspace, 'app-release-protected.apk');
    const generated = path.join(workspace, 'app-release-signed.apk');
    const redact = (text) => text
      .replaceAll(signing.storePassword, '<redacted>')
      .replaceAll(signing.keyPassword, '<redacted>');
    const protectedRun = run(mocika.shield, [
      'protect', '--json', '--input', rawApk, '--output', protectedUnsigned,
    ], { cwd: mocika.root, capture: true, redact });
    const protectedLog = `${protectedRun.stdout}\n${protectedRun.stderr}`;
    if (!protectedLog.includes('"type":"done"')) throw new Error('Mocika did not report successful completion');
    if (!fs.existsSync(protectedUnsigned) || fs.statSync(protectedUnsigned).size < 1024 * 1024) {
      throw new Error('Mocika did not produce a plausible protected APK');
    }
    const signingEnv = {
      ...process.env,
      FENLENG_ANDROID_STORE_PASSWORD: signing.storePassword,
      FENLENG_ANDROID_KEY_PASSWORD: signing.keyPassword,
    };
    run(apksigner, [
      'sign', '--ks', keystore, '--ks-key-alias', signing.keyAlias,
      '--ks-pass', 'env:FENLENG_ANDROID_STORE_PASSWORD',
      '--key-pass', 'env:FENLENG_ANDROID_KEY_PASSWORD',
      '--v1-signing-enabled', 'true', '--v2-signing-enabled', 'true',
      '--v3-signing-enabled', 'true', '--v4-signing-enabled', 'false',
      '--out', generated, protectedUnsigned,
    ], { capture: true, env: signingEnv, redact });
    const hardenedCertificateSha256 = certificateDigest(apksigner, generated);
    if (hardenedCertificateSha256 !== sourceCertificateSha256) {
      throw new Error('Hardened APK signing certificate differs from the Flutter release APK');
    }
    if (sha256File(generated) === sha256File(rawApk)) throw new Error('Hardened APK is byte-identical to source APK');
    const runtime = verifyColdStart(resolveAdb(), device, generated);
    fs.copyFileSync(generated, hardenedApk);
    console.log(JSON.stringify({
      mode,
      channel,
      hardened: true,
      hardener: `mocika-shield ${MOCIKA_VERSION} (${MOCIKA_COMMIT.slice(0, 12)})`,
      apk: hardenedApk,
      sha256: sha256File(hardenedApk),
      certificateSha256: hardenedCertificateSha256,
      runtime,
    }, null, 2));
  } finally {
    fs.rmSync(workspace, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(`[flutter-android-package] ${error.message}`);
  process.exit(1);
});
