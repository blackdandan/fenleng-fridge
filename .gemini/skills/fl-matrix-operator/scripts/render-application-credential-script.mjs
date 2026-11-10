#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

function fail(message) {
  console.error(`[credential-script] ${message}`);
  process.exit(2);
}

function values(argv, name) {
  const result = [];
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === name) result.push(argv[index + 1]);
  }
  return result.filter(value => typeof value === 'string' && value.length > 0);
}

function value(argv, name) {
  const found = values(argv, name);
  if (found.length !== 1) fail(`${name} is required exactly once`);
  return found[0];
}

function slug(input, label) {
  if (!/^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$|^[a-z0-9]$/.test(input)) {
    fail(`${label} must be lowercase kebab-case`);
  }
  return input;
}

function envKey(input, label) {
  if (!/^[A-Z][A-Z0-9_]*$/.test(input)) fail(`${label} must be an uppercase environment key`);
  return input;
}

function shellQuote(input) {
  return `'${input.replaceAll("'", `'"'"'`)}'`;
}

function relativeInside(root, candidate, label) {
  if (path.isAbsolute(candidate)) fail(`${label} must be relative to --project-root`);
  const absolute = path.resolve(root, candidate);
  const relative = path.relative(root, absolute);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) fail(`${label} must stay inside --project-root`);
  return { absolute, relative };
}

const argv = process.argv.slice(2);
const projectRoot = path.resolve(value(argv, '--project-root'));
if (!fs.existsSync(projectRoot) || !fs.statSync(projectRoot).isDirectory()) fail('--project-root must be an existing directory');

const projectId = slug(value(argv, '--project-id'), 'project id');
const environment = value(argv, '--environment');
if (!['local', 'production'].includes(environment)) fail('--environment must be local or production');
const provider = slug(value(argv, '--provider'), 'provider');
const purpose = slug(value(argv, '--purpose'), 'purpose');
const vaultName = slug(value(argv, '--vault-name'), 'vault name');
const secretRuntimeKey = envKey(value(argv, '--secret-runtime-key'), 'secret runtime key');
const appIdKeys = values(argv, '--app-id-key').map((item, index) => envKey(item, `app id key ${index + 1}`));
if (appIdKeys.length === 0) fail('--app-id-key is required at least once');
if (new Set(appIdKeys).size !== appIdKeys.length) fail('--app-id-key values must be unique');

const appIdFile = relativeInside(projectRoot, value(argv, '--app-id-file'), '--app-id-file');
const output = relativeInside(projectRoot, value(argv, '--output'), '--output');
if (output.absolute === appIdFile.absolute) fail('--output and --app-id-file must be different files');

const script = `#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly project_id=${shellQuote(projectId)}
readonly environment=${shellQuote(environment)}
readonly provider=${shellQuote(provider)}
readonly purpose=${shellQuote(purpose)}
readonly project_root=${shellQuote(projectRoot)}
readonly app_id_file=${shellQuote(appIdFile.absolute)}
readonly vault_name=${shellQuote(vaultName)}
readonly secret_runtime_key=${shellQuote(secretRuntimeKey)}
readonly vault_host='root@121.199.10.6'
readonly app_id_keys=(${appIdKeys.map(shellQuote).join(' ')})

update_env_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temporary
  mkdir -p "$(dirname "$file")"
  temporary="$(mktemp "${'${file}'}.tmp.XXXXXX")"
  if [[ -f "$file" ]]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { replaced = 0 }
      index($0, key "=") == 1 { print key "=" value; replaced = 1; next }
      { print }
      END { if (!replaced) print key "=" value }
    ' "$file" > "$temporary"
  else
    printf '%s=%s\\n' "$key" "$value" > "$temporary"
  fi
  chmod 0644 "$temporary"
  mv "$temporary" "$file"
}

printf 'AppID for %s/%s/%s/%s: ' "$project_id" "$environment" "$provider" "$purpose"
IFS= read -r app_id
if [[ ! "$app_id" =~ ^[A-Za-z0-9._:+/-]+$ ]]; then
  printf 'Invalid AppID format. No files were changed.\\n' >&2
  exit 2
fi

for key in "${'${app_id_keys[@]}'}"; do
  update_env_key "$app_id_file" "$key" "$app_id"
done
unset app_id

printf '\\nAppID stored in %s.\\n' "$app_id_file"
printf 'Now enter AppSecret in the remote vault prompt. It will not pass through this script.\\n'
ssh -t "$vault_host" fl-secret set "$vault_name"

if ! ssh "$vault_host" fl-secret list | grep -F -- "$vault_name" >/dev/null; then
  printf 'Vault command completed, but %s was not found by the metadata-only list check.\\n' "$vault_name" >&2
  exit 3
fi

printf 'Credential binding ready: project=%s environment=%s provider=%s purpose=%s vault=%s runtimeKey=%s\\n' \
  "$project_id" "$environment" "$provider" "$purpose" "$vault_name" "$secret_runtime_key"
`;

fs.mkdirSync(path.dirname(output.absolute), { recursive: true });
fs.writeFileSync(output.absolute, script, { mode: 0o755 });
fs.chmodSync(output.absolute, 0o755);
console.log(`[credential-script] wrote ${output.absolute}`);
console.log(`[credential-script] AppID target ${appIdFile.relative}; AppSecret vault ${vaultName}; runtime key ${secretRuntimeKey}`);
