"""Archive existing validated build trees; do not deploy or rebuild them."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.fenleng/deliveries'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def archive_tree(kind, tree):
    files = {p.relative_to(tree).as_posix(): p.read_bytes()
             for p in sorted(tree.rglob('*')) if p.is_file()}
    if not files:
        raise RuntimeError(f'Empty {kind} build')
    if kind == 'weapp' and 'project.config.json' not in files:
        raise RuntimeError('Missing WeChat project configuration')
    if kind == 'website':
        release = json.loads(files['release.json'])
        android = release['android']
        apk = files[android['url']]
        if digest(apk) != android['sha256'] or len(apk) != android['bytes']:
            raise RuntimeError('Website APK does not match release metadata')
    hashes = {name: digest(data) for name, data in files.items()}
    content_id = digest(''.join(f'{value}  {name}\n'
                               for name, value in sorted(hashes.items())).encode())
    target = OUTPUT / f'fenleng-fridge-{kind}-candidate-{content_id[:12]}.zip'
    manifest = {'kind': kind, 'contentId': content_id,
                'productionDeployed': False, 'files': hashes}
    if not target.exists():
        with zipfile.ZipFile(target, 'x') as bundle:
            for name, data in {**files, 'ARTIFACT-MANIFEST.json':
                               (json.dumps(manifest, indent=2) + '\n').encode()}.items():
                info = zipfile.ZipInfo(name, date_time=(2026, 11, 13, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                bundle.writestr(info, data)
    with zipfile.ZipFile(target) as bundle:
        assert bundle.testzip() is None
        assert len(bundle.namelist()) == len(files) + 1
        assert json.loads(bundle.read('ARTIFACT-MANIFEST.json')) == manifest
        for name, value in hashes.items():
            assert digest(bundle.read(name)) == value, name
    return {'kind': kind, 'archive': str(target),
            'sha256': digest(target.read_bytes()), 'bytes': target.stat().st_size,
            'files': len(files), 'contentId': content_id,
            'status': 'archive-content-verified-not-production-deployed'}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    results = [archive_tree('weapp', ROOT / '06-project/mini-program/apps/miniapp/dist'),
               archive_tree('website', ROOT / '06-project/web/dist')]
    (OUTPUT / 'latest-built-artifacts.json').write_text(
        json.dumps(results, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
