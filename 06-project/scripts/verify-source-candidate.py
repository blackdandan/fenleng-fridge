"""Verify source candidate contents and optional independent consumer resolution."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--consumer', type=Path)
    options = parser.parse_args()
    metadata = json.loads((ROOT / '.fenleng/deliveries/latest-source-candidate.json').read_text()) if not options.archive else None
    archive = options.archive or Path(metadata['archive'])
    with zipfile.ZipFile(archive) as source:
        names = source.namelist()
        assert len(names) == len(set(names)), 'Duplicate archive member'
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts
            assert path.suffix.lower() not in {'.jks', '.keystore', '.p12', '.mobileprovision'}
            assert path.name not in {'credentials.properties', 'credentials.json', 'key.properties', 'local.properties'}
        manifest = json.loads(source.read('CANDIDATE-MANIFEST.json'))
        files = manifest['files']
        assert set(names) == set(files) | {'CANDIDATE-MANIFEST.json'}
        for name, expected in files.items():
            assert hashlib.sha256(source.read(name)).hexdigest() == expected, 'Source hash mismatch: ' + name
        actual = hashlib.sha256(''.join(f'{value}  {name}\n' for name, value in sorted(files.items())).encode()).hexdigest()
        assert actual == manifest['contentId']
        assert source.testzip() is None
    result = {'status': 'archive-integrity-verified', 'contentId': actual, 'files': len(files), 'consumer': 'not-requested'}
    if options.consumer:
        consumer = options.consumer.resolve()
        config = consumer / '06-project/app/.dart_tool/package_config.json'
        packages = json.loads(config.read_text())['packages']
        targets = {'fenleng_sdk_flutter', 'fenleng_sdk_flutter_native_identity', 'fenleng_sdk_flutter_firebase_identity'}
        resolved = {}
        vendor = consumer / '06-project/app/vendor/flsdk'
        for package in packages:
            if package['name'] in targets:
                uri = urlparse(urljoin(config.as_uri(), package['rootUri']))
                assert uri.scheme == 'file'
                path = Path(url2pathname(uri.path)).resolve()
                path.relative_to(vendor)
                assert (path / 'pubspec.yaml').is_file()
                resolved[package['name']] = str(path.relative_to(consumer))
        assert set(resolved) == targets
        result.update(consumer='three-official-SDK-candidates-resolve-inside-bundle', sdkPackages=resolved)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
