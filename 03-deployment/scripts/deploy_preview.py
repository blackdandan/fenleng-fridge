"""Fixed fenleng-fridge preview deployment; no arbitrary host/path CLI."""
import argparse
import datetime
import fcntl
import json
import os
import re
from pathlib import Path
import subprocess
import urllib.request
import zipfile
from preview_bundle import atomic_write, restore, sha256, snapshot, verify_bundle, verify_release_tree, wait_healthy

ROOT = Path('/opt/fenleng-websites/fenleng-fridge')
CONFIG = Path('/etc/nginx/conf.d/fenleng-fridge.conf')
LINK = Path('/usr/share/nginx/fenleng-fridge')
DOMAIN = 'fridge.fenlengtech.com'
HERE = Path(__file__).resolve().parent


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=180)
    # Fixed commands contain no credentials; never read private keys/account files.
    print(json.dumps({'command': args, 'exitCode': result.returncode,
                      'output': (result.stdout + result.stderr)[-6000:]}), flush=True)
    result.check_returncode()


def nginx_reload():
    run(['/usr/sbin/nginx', '-t'])
    run(['/usr/bin/systemctl', 'reload', 'nginx'])


def config_bytes(tls):
    http = '''# fenleng-fridge approved development preview
server {
    listen 80;
    server_name fridge.fenlengtech.com;
    location ^~ /.well-known/acme-challenge/ { root /var/www/html; }
    location / { HTTP_ACTION }
}
'''
    if not tls:
        return http.replace('HTTP_ACTION', 'return 503;').encode()
    return (http.replace('HTTP_ACTION', 'return 301 https://fridge.fenlengtech.com$request_uri;') + '''
server {
    listen 443 ssl;
    server_name fridge.fenlengtech.com;
    ssl_certificate /etc/letsencrypt/live/fridge.fenlengtech.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/fridge.fenlengtech.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    root /usr/share/nginx/fenleng-fridge;
    index index.html;
    charset utf-8;
    add_header Cache-Control "no-cache";
    location /downloads/ {
        types { application/vnd.android.package-archive apk; }
        add_header Cache-Control "no-cache";
        add_header Content-Disposition 'attachment; filename="fenleng-fridge_latest.apk"';
        try_files $uri =404;
    }
    location / { try_files $uri $uri/ =404; }
}
''').encode()


def health(release):
    for path in ['/', '/terms/', '/privacy/', '/app/', '/release.json']:
        with urllib.request.urlopen('https://' + DOMAIN + path, timeout=20) as response:
            if response.status != 200:
                raise ValueError('HTTPS_HEALTH_FAILED')
            body = response.read()
            if path == '/release.json' and json.loads(body) != release:
                raise ValueError('ONLINE_RELEASE_IDENTITY_MISMATCH')
    request = urllib.request.Request('https://' + DOMAIN + '/' + release['android']['url'], method='HEAD')
    with urllib.request.urlopen(request, timeout=20) as response:
        if (response.status != 200 or int(response.headers['Content-Length']) != release['android']['bytes']
                or response.headers.get_content_type() != 'application/vnd.android.package-archive'):
            raise ValueError('DOWNLOAD_HEAD_FAILED')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['verify', 'deploy', 'rollback', 'install-renewal-hook'])
    args = parser.parse_args()
    binding = json.loads((HERE / 'binding.json').read_text())
    if (binding['host'] != 'root@121.199.10.6' or binding['domain'] != DOMAIN
            or binding['projectId'] != 'fenleng-fridge' or binding['approval'] != 'owner-approved-development-preview'):
        raise ValueError('FIXED_BINDING_INVALID')
    archive = HERE / binding['archiveName']
    if archive.parent != HERE or archive.name != 'website.zip':
        raise ValueError('FIXED_ARCHIVE_PATH_INVALID')
    manifest, release = verify_bundle(archive, binding['archiveSha256'])
    if manifest['contentId'] != binding['contentId'] or release['android']['sha256'] != binding['apkSha256']:
        raise ValueError('CANDIDATE_IDENTITY_MISMATCH')
    version = manifest['contentId'][:12]
    deployment_id = binding.get('deploymentId', version)
    if not re.fullmatch(re.escape(version) + r'(?:-r[1-9][0-9]*)?', deployment_id):
        raise ValueError('DEPLOYMENT_ID_INVALID')
    if HERE != ROOT / 'uploads' / deployment_id:
        raise ValueError('REGISTERED_SCRIPT_LOCATION_REQUIRED')
    if args.action == 'verify':
        print(json.dumps({'status': 'verified', 'contentId': manifest['contentId']}))
        return
    backup = ROOT / 'backups' / deployment_id
    with (ROOT / '.publish.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.action == 'install-renewal-hook':
            source = HERE / 'fridge-certificate-renewed.sh'
            hook = Path('/etc/letsencrypt/renewal-hooks/deploy/fenleng-fridge.sh')
            if sha256(source) != binding['renewalHookSha256']:
                raise ValueError('RENEWAL_HOOK_IDENTITY_MISMATCH')
            if hook.exists() or hook.is_symlink():
                raise ValueError('RENEWAL_HOOK_OCCUPIED_REVIEW_REQUIRED')
            backup.mkdir(parents=True, exist_ok=False)
            (backup / 'renewal-hook-before.json').write_text('{"existed": false}\n')
            run(['/bin/sh', '-n', str(source)])
            atomic_write(hook, source.read_bytes())
            hook.chmod(0o755)
            try:
                run(['/usr/bin/env', 'RENEWED_LINEAGE=/etc/letsencrypt/live/fridge.fenlengtech.com', '/bin/sh', str(hook)])
                attempts = wait_healthy(lambda: health(release))
            except BaseException:
                hook.unlink()
                raise
            print(json.dumps({'status': 'renewal-hook-installed-and-verified', 'path': str(hook), 'healthAttempts': attempts}))
            return
        if args.action == 'rollback':
            restore(CONFIG, LINK, backup)
            nginx_reload()
            print(json.dumps({'status': 'rolled-back', 'backup': str(backup)}))
            return
        if CONFIG.exists() or LINK.exists() or LINK.is_symlink():
            raise ValueError('FIRST_BINDING_TARGET_OCCUPIED_REVIEW_REQUIRED')
        release_dir = ROOT / 'releases' / version
        reused = release_dir.exists()
        if reused:
            verify_release_tree(release_dir, manifest)
        snapshot(CONFIG, LINK, backup)
        try:
            if not reused:
                release_dir.mkdir(parents=True)
                with zipfile.ZipFile(archive) as bundle:
                    for info in bundle.infolist():
                        target = release_dir / info.filename
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with bundle.open(info) as source, target.open('xb') as destination:
                            import shutil
                            shutil.copyfileobj(source, destination, 1024 * 1024)
                        target.chmod(0o644)
            verify_release_tree(release_dir, manifest)
            atomic_write(CONFIG, config_bytes(False))
            nginx_reload()
            run(['/usr/bin/certbot', 'certonly', '--non-interactive', '--webroot',
                 '-w', '/var/www/html', '--preferred-challenges', 'http',
                 '--cert-name', DOMAIN, '-d', DOMAIN, '--keep-until-expiring'])
            next_link = LINK.with_name(LINK.name + '.next')
            if next_link.exists() or next_link.is_symlink():
                raise ValueError('LINK_TEMPORARY_OCCUPIED')
            next_link.symlink_to(release_dir, target_is_directory=True)
            os.replace(next_link, LINK)
            atomic_write(CONFIG, config_bytes(True))
            nginx_reload()
            health_attempts = wait_healthy(lambda: health(release))
            result = {'status': 'deployed-preview', 'domain': DOMAIN,
                      'contentId': manifest['contentId'], 'archiveSha256': binding['archiveSha256'],
                      'apkSha256': release['android']['sha256'], 'releaseDir': str(release_dir),
                      'backup': str(backup), 'healthAttempts': health_attempts,
                      'observedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
            (backup / 'deployment-result.json').write_text(json.dumps(result, indent=2) + '\n')
            print(json.dumps(result), flush=True)
        except BaseException:
            restore(CONFIG, LINK, backup)
            nginx_reload()
            raise


if __name__ == '__main__':
    main()
