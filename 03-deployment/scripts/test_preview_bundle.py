import hashlib
import json
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile
from preview_bundle import atomic_write, restore, sha256, snapshot, verify_bundle, verify_release_tree, wait_healthy

WORKSPACE = Path(__file__).resolve().parents[2]


class PreviewBundleTest(unittest.TestCase):
    def setUp(self):
        parent = WORKSPACE / '.fenleng/publish-tests'
        parent.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix='preview-', dir=parent)
        self.root = Path(temporary.name)
        def cleanup():
            self.root.resolve().relative_to(parent.resolve())
            temporary.cleanup()
        self.addCleanup(cleanup)

    def bundle(self, *, extra=None, tamper=False, symlink=False):
        apk = b'synthetic-preview-apk'
        release = {'releaseStatus': 'development', 'android': {
            'kind': 'debug-preview', 'url': 'downloads/fenleng-fridge_latest.apk',
            'bytes': len(apk), 'sha256': hashlib.sha256(apk).hexdigest()}}
        files = {'release.json': json.dumps(release).encode(),
                 'index.html': b'<p data-i18n="androidPreviewKind">Debug</p>',
                 'app/index.html': b'<p data-i18n="androidPreviewKind">Debug</p>',
                 release['android']['url']: apk}
        if extra:
            files[extra] = b'forbidden'
        hashes = {name: hashlib.sha256(data).hexdigest() for name, data in files.items()}
        text = ''.join(f'{value}  {name}\n' for name, value in sorted(hashes.items()))
        manifest = {'kind': 'website', 'files': hashes, 'contentId': hashlib.sha256(text.encode()).hexdigest()}
        path = self.root / 'website.zip'
        with zipfile.ZipFile(path, 'w') as target:
            for name, data in files.items():
                info = zipfile.ZipInfo(name)
                if symlink and name == 'index.html':
                    info.external_attr = (stat.S_IFLNK | 0o777) << 16
                target.writestr(info, b'changed' if tamper and name == 'index.html' else data)
            target.writestr('ARTIFACT-MANIFEST.json', json.dumps(manifest))
        return path, sha256(path)

    def test_valid_candidate_has_expected_identity(self):
        path, digest = self.bundle()
        manifest, release = verify_bundle(path, digest)
        self.assertEqual(4, len(manifest['files']))
        self.assertEqual('debug-preview', release['android']['kind'])

    def test_outer_hash_mismatch_rejected(self):
        path, _ = self.bundle()
        with self.assertRaisesRegex(ValueError, 'ARCHIVE_HASH_MISMATCH'):
            verify_bundle(path, '0' * 64)

    def test_traversal_rejected_even_when_manifest_matches(self):
        path, digest = self.bundle(extra='../escape')
        with self.assertRaisesRegex(ValueError, 'PATH_OR_TYPE'):
            verify_bundle(path, digest)
        self.assertFalse((self.root.parent / 'escape').exists())

    def test_symlink_member_rejected(self):
        path, digest = self.bundle(symlink=True)
        with self.assertRaisesRegex(ValueError, 'PATH_OR_TYPE'):
            verify_bundle(path, digest)

    def test_payload_tamper_rejected(self):
        path, digest = self.bundle(tamper=True)
        with self.assertRaisesRegex(ValueError, 'PAYLOAD_HASH_MISMATCH'):
            verify_bundle(path, digest)

    def test_restore_preserves_previous_config_and_link(self):
        config, link, backup = self.root / 'site.conf', self.root / 'active', self.root / 'backup'
        old = self.root / 'old'
        old.mkdir()
        config.write_bytes(b'original')
        link.symlink_to(old, target_is_directory=True)
        snapshot(config, link, backup)
        atomic_write(config, b'new configuration')
        link.unlink()
        link.symlink_to(self.root / 'new', target_is_directory=True)
        restore(config, link, backup)
        self.assertEqual(b'original', config.read_bytes())
        self.assertEqual(old, link.resolve())

    def test_first_binding_rollback_removes_only_created_entry_points(self):
        config, link, backup = self.root / 'site.conf', self.root / 'active', self.root / 'backup'
        snapshot(config, link, backup)
        config.write_bytes(b'new')
        link.symlink_to(self.root / 'retained-release', target_is_directory=True)
        restore(config, link, backup)
        self.assertFalse(config.exists())
        self.assertFalse(link.is_symlink())
        self.assertTrue(backup.exists())

    def test_unexpected_existing_directory_is_preserved(self):
        config, link, backup = self.root / 'site.conf', self.root / 'active', self.root / 'backup'
        link.mkdir()
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_TARGET_TYPE'):
            snapshot(config, link, backup)
        self.assertTrue(link.is_dir())

    def test_reload_readiness_retries_transient_failure_without_disabling_validation(self):
        calls = []
        def check():
            calls.append(1)
            if len(calls) < 3:
                raise OSError('old worker certificate')
        self.assertEqual(3, wait_healthy(check, sleep=lambda _: None))

    def test_reload_readiness_keeps_permanent_failure_bounded(self):
        calls = []
        def check():
            calls.append(1)
            raise ValueError('wrong release')
        with self.assertRaisesRegex(ValueError, 'wrong release'):
            wait_healthy(check, attempts=3, sleep=lambda _: None)
        self.assertEqual(3, len(calls))

    def test_reusing_immutable_tree_requires_every_payload_hash(self):
        archive, digest = self.bundle()
        manifest, _ = verify_bundle(archive, digest)
        directory = self.root / 'retained-release'
        directory.mkdir()
        with zipfile.ZipFile(archive) as source:
            source.extractall(directory)
        verify_release_tree(directory, manifest)
        (directory / 'index.html').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'RELEASE_TREE_PAYLOAD_MISMATCH'):
            verify_release_tree(directory, manifest)


if __name__ == '__main__':
    unittest.main()
