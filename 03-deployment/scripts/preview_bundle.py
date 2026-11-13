"""Verified static-preview artifact and reversible filesystem operations."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import time
import zipfile


def sha256(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def verify_bundle(path, expected):
    if sha256(path) != expected:
        raise ValueError('ARCHIVE_HASH_MISMATCH')
    with zipfile.ZipFile(path) as bundle:
        names = bundle.namelist()
        if len(names) != len(set(names)) or len(names) > 64:
            raise ValueError('ARCHIVE_MEMBER_SET_INVALID')
        for info in bundle.infolist():
            item = PurePosixPath(info.filename)
            mode = info.external_attr >> 16
            if (item.is_absolute() or '..' in item.parts or '\\' in info.filename
                    or info.is_dir() or not item.parts
                    or stat.S_IFMT(mode) not in (0, stat.S_IFREG)):
                raise ValueError('ARCHIVE_PATH_OR_TYPE_INVALID')
        if sum(x.file_size for x in bundle.infolist()) > 512 * 1024 * 1024:
            raise ValueError('ARCHIVE_TOO_LARGE')
        manifest = json.loads(bundle.read('ARTIFACT-MANIFEST.json'))
        if manifest['kind'] != 'website' or set(names) != set(manifest['files']) | {'ARTIFACT-MANIFEST.json'}:
            raise ValueError('MANIFEST_MEMBER_SET_INVALID')
        content = ''.join(f'{value}  {name}\n' for name, value in sorted(manifest['files'].items()))
        if hashlib.sha256(content.encode()).hexdigest() != manifest['contentId']:
            raise ValueError('CONTENT_ID_INVALID')
        for name, expected_hash in manifest['files'].items():
            value = hashlib.sha256()
            with bundle.open(name) as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b''):
                    value.update(chunk)
            if value.hexdigest() != expected_hash:
                raise ValueError('PAYLOAD_HASH_MISMATCH')
        release = json.loads(bundle.read('release.json'))
        apk = release['android']
        if (release['releaseStatus'] != 'development' or apk['kind'] != 'debug-preview'
                or apk['url'] != 'downloads/fenleng-fridge_latest.apk'
                or manifest['files'][apk['url']] != apk['sha256']
                or bundle.getinfo(apk['url']).file_size != apk['bytes']):
            raise ValueError('PREVIEW_ARTIFACT_IDENTITY_INVALID')
        for page in ['index.html', 'app/index.html']:
            if 'data-i18n="androidPreviewKind"' not in bundle.read(page).decode('utf-8'):
                raise ValueError('PREVIEW_LABEL_MISSING')
    return manifest, release


def atomic_write(path, data):
    path = Path(path)
    temporary = path.with_name(path.name + '.fridge-next')
    if temporary.exists() or temporary.is_symlink():
        raise ValueError('TEMPORARY_PATH_OCCUPIED')
    with temporary.open('xb') as target:
        target.write(data)
        target.flush()
        os.fsync(target.fileno())
    os.replace(temporary, path)


def verify_release_tree(directory, manifest):
    if directory.is_symlink() or any(p.is_symlink() for p in directory.rglob('*')):
        raise ValueError('RELEASE_TREE_SYMLINK')
    names = {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file()}
    if names != set(manifest['files']) | {'ARTIFACT-MANIFEST.json'}:
        raise ValueError('RELEASE_TREE_MEMBER_SET_MISMATCH')
    if json.loads((directory / 'ARTIFACT-MANIFEST.json').read_text()) != manifest:
        raise ValueError('RELEASE_TREE_MANIFEST_MISMATCH')
    for name, digest in manifest['files'].items():
        if sha256(directory / name) != digest:
            raise ValueError('RELEASE_TREE_PAYLOAD_MISMATCH')


def wait_healthy(check, attempts=10, sleep=time.sleep):
    for attempt in range(1, attempts + 1):
        try:
            check()
            return attempt
        except (OSError, ValueError):
            if attempt == attempts:
                raise
            sleep(1)


def snapshot(config, link, backup):
    backup.mkdir(parents=True, exist_ok=False)
    if config.is_symlink() or (link.exists() and not link.is_symlink()):
        raise ValueError('UNEXPECTED_TARGET_TYPE')
    state = {'configExisted': config.exists(),
             'linkTarget': os.readlink(link) if link.is_symlink() else None}
    if state['configExisted']:
        shutil.copyfile(config, backup / 'nginx-before.conf')
    (backup / 'before.json').write_text(json.dumps(state) + '\n')
    return state


def restore(config, link, backup):
    state = json.loads((backup / 'before.json').read_text())
    if state['configExisted']:
        atomic_write(config, (backup / 'nginx-before.conf').read_bytes())
    elif config.exists():
        config.unlink()
    if link.is_symlink():
        link.unlink()
    elif link.exists():
        raise ValueError('ROLLBACK_LINK_TYPE_CHANGED')
    if state['linkTarget'] is not None:
        link.symlink_to(state['linkTarget'], target_is_directory=True)
