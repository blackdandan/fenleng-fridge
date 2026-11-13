"""Read-only release evidence on the registered production host."""
import json
from pathlib import Path
import subprocess

ROOT=Path('/opt/fenleng-shared-platform')
def run(*args):return subprocess.check_output(args,text=True).strip()

def main():
    active=(ROOT/'production/release').resolve(strict=True)
    assert active==ROOT/'releases/0.1.0-rc.138'
    manifest=json.loads((active/'candidate-manifest.json').read_text())
    assert manifest['sourceCommit']=='35487625d6e1a49bf18c925a90d7521b89c30477'
    container='fenleng-shared-platform-production-postgres-1'
    sql='SELECT max(version::int) FROM platform.flyway_schema_history WHERE success'
    schema=run('docker','exec',container,'sh','-c',
        'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"','verify-schema',sql)
    assert schema=='63'
    health={}
    for item in manifest['images']:
        name=f"fenleng-shared-platform-production-{item['component']}-1"
        state=json.loads(run('docker','inspect','--format','{{json .State.Health}}',name))
        assert state['Status']=='healthy'
        health[item['component']]=state['Status']
    backup=ROOT/'production/backups/offline-0.1.0-rc.138/postgres.dump'
    assert backup.is_file() and backup.stat().st_size>1000
    print(json.dumps(dict(status='PASS',version=manifest['version'],sourceCommit=manifest['sourceCommit'],schemaVersion=int(schema),health=health,databaseBackupBytes=backup.stat().st_size,rollbackVersion='0.1.0-rc.137')))

if __name__=='__main__':main()
