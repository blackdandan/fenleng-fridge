import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const app = path.join(root, '06-project/app/apps/fridge');
const standard = path.join(root, '.agents/skills/fl-ai-coding-delivery/scripts/package-flutter-android.mjs');
const args = process.argv.slice(2);
if (!args.includes('--mode') || !args.includes('--channel')) throw new Error('Pass explicit --mode debug|release and --channel china|global');
const environment = {...process.env};
// Upstream OH repositories include missing LFS objects in unused example apps.
// Consumed plugin sources are regular files; do not fetch unrelated example engines.
environment.GIT_LFS_SKIP_SMUDGE ??= '1';
const gradleHome = path.join(root, '.fenleng/gradle-android');
const sharedGradleHome = environment.GRADLE_USER_HOME || path.join(os.homedir(), '.gradle');
fs.mkdirSync(path.join(gradleHome, 'init.d'), {recursive:true});
for (const directory of ['caches', 'wrapper']) {
  const shared = path.join(sharedGradleHome, directory);
  const local = path.join(gradleHome, directory);
  if (fs.existsSync(shared) && !fs.existsSync(local)) fs.symlinkSync(shared, local, process.platform === 'win32' ? 'junction' : 'dir');
}
fs.writeFileSync(path.join(gradleHome, 'init.d/fridge-repositories.gradle'), `
gradle.beforeSettings { settings ->
    settings.pluginManagement.repositories {
        maven { name = 'fridgePluginMirror'; url = uri('https://maven.aliyun.com/repository/gradle-plugin') }
        maven { name = 'fridgeGoogleMirror'; url = uri('https://maven.aliyun.com/repository/google') }
        maven { name = 'fridgePublicMirror'; url = uri('https://maven.aliyun.com/repository/public') }
    }
}
def addMirrorsFirst = { repositories ->
    def original = repositories.toList()
    repositories.clear()
    repositories.maven { name = 'fridgeFlutterEngine'; url = uri('https://storage.flutter-io.cn/download.flutter.io'); content { includeGroup 'io.flutter' } }
    repositories.maven { name = 'fridgeGoogleMirror'; url = uri('https://maven.aliyun.com/repository/google'); content { excludeGroup 'io.flutter' } }
    repositories.maven { name = 'fridgePublicMirror'; url = uri('https://maven.aliyun.com/repository/public'); content { excludeGroup 'io.flutter' } }
    original.each { repositories.add(it) }
}
gradle.settingsEvaluated { settings ->
    addMirrorsFirst(settings.dependencyResolutionManagement.repositories)
    def mode = settings.dependencyResolutionManagement.repositoriesMode.get().name()
    gradle.beforeProject { project ->
        addMirrorsFirst(project.buildscript.repositories)
        if (mode == 'PREFER_PROJECT') addMirrorsFirst(project.repositories)
    }
}
`);
environment.GRADLE_USER_HOME = gradleHome;
let isolated;
if (process.platform === 'win32') {
  if (!environment.JAVA_HOME || !fs.existsSync(path.join(environment.JAVA_HOME, 'bin/java.exe'))) {
    throw new Error('Set JAVA_HOME to the compatible JDK before packaging');
  }
  isolated = fs.mkdtempSync(path.join(os.tmpdir(), 'fenleng-fridge-android-config-'));
  // This Android-only child process does not regenerate HarmonyOS host tooling.
  // It changes neither the shared SDK, global Flutter settings nor ohos sources.
  // HarmonyOS compilation remains a separate, explicitly tracked verification.
  fs.writeFileSync(path.join(isolated, '.flutter_settings'), JSON.stringify({
    'jdk-dir': environment.JAVA_HOME,
    'enable-ohos': false,
  }));
  environment.APPDATA = isolated;
  let versions = fs.realpathSync(path.join(root, '06-project/app/.fvm/flutter_sdk'));
  while (path.basename(versions) !== 'versions' && path.dirname(versions) !== versions) versions = path.dirname(versions);
  if (path.basename(versions) !== 'versions') throw new Error('Cannot resolve fixed FVM cache');
  environment.FVM_CACHE_PATH = path.dirname(versions);
}
try {
  const result = spawnSync(process.execPath, [standard, '--project', app, ...args], {
    cwd: root, env: environment, stdio: 'inherit',
  });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (isolated) {
    const actual = fs.realpathSync(isolated);
    const temp = fs.realpathSync(os.tmpdir());
    if (path.dirname(actual) !== temp || !path.basename(actual).startsWith('fenleng-fridge-android-config-')) {
      throw new Error('Unexpected temporary directory; retained for review');
    }
    fs.rmSync(actual, {recursive:true});
  }
}
