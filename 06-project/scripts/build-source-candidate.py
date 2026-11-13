"""Build a content-addressed, self-contained source candidate using the published, hash-frozen official SDK."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.fenleng/deliveries'
SDK = ROOT / '06-project/app/vendor/flsdk'
PACKAGES = ['sdk-flutter', 'sdk-flutter-native-identity', 'sdk-flutter-firebase-identity']
SKIP_DIRS = {'.git', '.fenleng', 'node_modules', '.dart_tool', '.fvm', 'build', 'dist', '.gradle', '__pycache__', '.idea', '.swc', '.cache'}
SKIP_NAMES = {'pubspec_overrides.yaml', 'local.properties', 'key.properties', 'credentials.properties',
              'credentials.json', '.flutter-plugins-dependencies', 'Generated.xcconfig', 'flutter_export_environment.sh',
              'project.private.config.json', '.DS_Store'}
PRIVATE_SUFFIXES = {'.jks', '.keystore', '.p12', '.mobileprovision'}


def allowed(path):
    return (path.name not in SKIP_NAMES and path.suffix.lower() not in PRIVATE_SUFFIXES
            and not path.name.startswith('.env') and not path.name.endswith('.env')
            and not path.is_symlink())


def copy_tree(source, target):
    for directory, children, names in os.walk(source, followlinks=False):
        children[:] = sorted(name for name in children if name not in SKIP_DIRS
                             and not (Path(directory) / name).is_symlink())
        for name in sorted(names):
            original = Path(directory) / name
            if not allowed(original):
                continue
            destination = target / original.relative_to(source)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, destination)


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix='s-', dir=OUTPUT))
    for name in ['00-context', '01-product', '02-engineering', '03-deployment', '04-operations', '05-knowledge', '06-project', '.agents', 'docs/ai-coding-audits', 'docs/ip']:
        if (ROOT / name).is_dir():
            copy_tree(ROOT / name, staging / name)
    for name in ['AGENTS.md', 'README.md', '.gitignore', 'fenleng.project.yaml']:
        if (ROOT / name).is_file():
            shutil.copyfile(ROOT / name, staging / name)
    # Keep paths below the Windows MAX_PATH limit, including native Java names.
    vendor = staging / '06-project/app/vendor/flsdk'
    provenance = json.loads((vendor / 'candidate-provenance.json').read_text(encoding='utf-8'))
    assert provenance['published'] is True
    sdk_files = provenance['sourceFiles']
    for name, expected in sdk_files.items():
        assert digest(vendor / name) == expected, name
    overrides = ['# Published official SDK snapshot, recorded by immutable commit.', 'dependency_overrides:']
    for package in PACKAGES:
        key = 'fenleng_' + package.replace('-', '_')
        overrides += ['  ' + key + ':', '    path: vendor/flsdk/' + package]
    (staging / '06-project/app/pubspec_overrides.yaml').write_text('\n'.join(overrides) + '\n', encoding='utf-8')
    readme = '''# Source candidate\n\nThis archive contains the current product source and three official SDK packages frozen from published commit b5e529f, each identified by file hashes. It is not an official SDK release or a production deployment.\n\nFrom `06-project/app`, run `fvm use --skip-pub-get --skip-setup --force`, then `fvm dart pub get`. The archive-only pubspec_overrides.yaml resolves the bundled SDK packages without a sibling checkout. Use the project Android packaging entry; restore the existing fixed signing identity through the documented Vault workflow before building a signed package. Do not generate another key.\n\nThe fixed Flutter-OH SDK may require Harmony tooling for automatic Flutter pub/platform generation. The maintained `06-project/scripts/refresh-mobile-plugins.dart` supports the documented Android/iOS-only refresh; it does not validate Harmony compilation.\n\nSee 02-engineering/plans/full-implementation.md, 03-deployment/identity-configuration.md, 04-operations/owner-follow-ups.md and 05-knowledge/signinfo/application-signing-info.json. Production platform and preview deployment are verified; provider registration and device validation remain Owner follow-ups.\n\nNo signing keystore/password, provisioning profile, local device data, dependency cache or build output is included.\n'''
    (staging / 'SOURCE-CANDIDATE.md').write_text(readme, encoding='utf-8')
    files = {str(p.relative_to(staging)).replace('\\', '/'): digest(p)
             for p in sorted(staging.rglob('*')) if p.is_file()}
    content_id = hashlib.sha256(''.join(f'{value}  {name}\n' for name, value in sorted(files.items())).encode()).hexdigest()
    manifest = {'kind': 'self-contained-source-candidate', 'contentId': content_id, 'goalComplete': json.loads((ROOT / '02-engineering/implementation-status.json').read_text(encoding='utf-8'))['goalComplete'],
                'sdkPublished': True, 'files': files}
    (staging / 'CANDIDATE-MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    archive = OUTPUT / ('fenleng-fridge-source-candidate-' + content_id[:12] + '.zip')
    if archive.exists():
        raise RuntimeError('Candidate archive already exists; retained staging for review')
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for path in sorted(staging.rglob('*')):
            if path.is_file():
                name = str(path.relative_to(staging)).replace('\\', '/')
                assert not name.startswith('/') and '..' not in Path(name).parts
                info = zipfile.ZipInfo(name, date_time=(2026, 11, 13, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                target.writestr(info, path.read_bytes())
    result = {'status': 'prepared-not-clean-consumer-validated', 'contentId': content_id,
              'staging': str(staging), 'archive': str(archive), 'sha256': digest(archive),
              'bytes': archive.stat().st_size, 'sourceFiles': len(files), 'sdkCandidateFiles': len(sdk_files)}
    (OUTPUT / 'latest-source-candidate.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
