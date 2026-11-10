#!/usr/bin/env python3
"""Run the pinned, complete UI UX Pro Max engine offline; return advisory evidence."""
import base64
import gzip
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    args = sys.argv[1:]
    # Upstream persistence creates another design-system authority. FL persists
    # reviewed decisions in the project's existing design knowledge instead.
    blocked = ('--persist', '--force', '--output-dir', '--page')
    # argparse accepts abbreviated long options and attached short values.
    if any((arg.startswith('--') and any(option.startswith(arg.split('=')[0]) for option in blocked))
           or arg.startswith('-o') for arg in args):
        print('FL: persist reviewed token mappings in project knowledge; upstream persistence is disabled.', file=sys.stderr)
        return 2
    archive = Path(__file__).resolve().parent.parent / 'assets' / 'upstream.json.gz'
    bundle = json.loads(gzip.decompress(archive.read_bytes()))
    with tempfile.TemporaryDirectory(prefix='fl-ux-pro-') as directory:
        root = Path(directory)
        for entry in bundle['entries']:
            dest = (root / entry['path']).resolve()
            if not dest.is_relative_to(root.resolve()):
                raise ValueError('Archive path escapes temporary directory')
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(base64.b64decode(entry['content'], validate=True))
        env = dict(os.environ, PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1')
        result = subprocess.run([sys.executable, str(root / 'scripts' / 'search.py'), *args],
                                capture_output=True, encoding='utf-8', env=env)
        if result.stderr:
            print(result.stderr, file=sys.stderr, end='')
        if '--json' in args and result.returncode == 0:
            payload = json.loads(result.stdout)
            payload['fenleng'] = {
                'status': 'advisory-requires-token-mapping',
                'upstreamCommit': bundle['commit'],
                'authority': 'fl-ui-design-system',
                'note': 'Map candidate colors, fonts, spacing and motion to verified project/Fenleng tokens before implementation.'
            }
            print(json.dumps(payload, ensure_ascii=False, indent=2))
        else:
            print(result.stdout, end='')
            if result.returncode == 0:
                print('\nFL: advisory evidence only; resolve project/Fenleng tokens before implementation.')
        return result.returncode


if __name__ == '__main__':
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main())
