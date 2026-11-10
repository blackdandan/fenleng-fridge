#!/usr/bin/env python3
"""Keep Japanese Clash nodes only, then select the fastest AGY-working node.

Run after Clash for Windows has finished applying a subscription update:
  refresh.py              # AGY-test every Japanese node
  refresh.py --fast       # latency prefilter, then test the fastest 8 nodes
  refresh.py --prune      # also write a Japanese-only profile, with a backup

The active profile is backed up before any modification.  This script never
updates the subscription itself; that remains Clash for Windows' job.
"""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import yaml


CONFIG = pathlib.Path.home() / ".config/clash/config.yaml"
PROFILES = pathlib.Path.home() / ".config/clash/profiles"
AGY = pathlib.Path.home() / ".local/bin/agy"
JP_RE = re.compile(r"(?:日本|JP)", re.IGNORECASE)
SPECIAL = {"DIRECT", "REJECT", "REJECT-DROP", "PASS"}
AVAILABLE_LABEL_PREFIX = "AGY可用节点"
COMPANY_BROWSER_PROXY = "公司浏览器代理"
INTERNAL_DNS = "192.168.137.1"
AGY_SERVICE_HOSTS = {
    "aiplatform.googleapis.com",
    "cloudcode-pa.googleapis.com",
    "daily-cloudcode-pa.googleapis.com",
    "generativelanguage.googleapis.com",
}
COMPANY_TEMPLATE_RULES = [
    f"DOMAIN,b2bpub.myhexin.com,{COMPANY_BROWSER_PROXY}",
    "DOMAIN,wifiauth.myhexin.com,DIRECT",
    "DOMAIN,gitlab-outer.myhexin.com,DIRECT",
    "DOMAIN-SUFFIX,myhexin.com,DIRECT",
    "DOMAIN-SUFFIX,10jqka.com.cn,DIRECT",
    "DOMAIN-SUFFIX,10jqka.com,DIRECT",
    "DOMAIN,b2bcrm.0033.com,DIRECT",
    "DOMAIN,effi-cp.0033.com,DIRECT",
    "DOMAIN,mall.stocke.com.cn,DIRECT",
    "DOMAIN-SUFFIX,local,DIRECT",
    "IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
    "IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
    "IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
    "IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
]


class ControllerError(RuntimeError):
    pass


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def controller_settings() -> tuple[str, str]:
    try:
        raw = CONFIG.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"cannot read {CONFIG}: {exc}")
    controller = re.search(r"^external-controller:\s*['\"]?([^'\"\s#]+)", raw, re.M)
    secret = re.search(r"^secret:\s*['\"]?([^'\"\s#]+)", raw, re.M)
    if not controller or not secret:
        fail("Clash external-controller or secret is missing")
    return controller.group(1), secret.group(1)


def api(url: str, secret: str, method: str = "GET", body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(
        url, data=data, method=method,
        headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            # Clash returns an empty 204/200 body for successful proxy changes.
            # Treat that as success rather than mistaking it for malformed JSON.
            payload = response.read()
            return json.loads(payload) if payload.strip() else {}
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError) as exc:
        raise ControllerError(str(exc)) from exc


def profile_proxy_names(candidate: pathlib.Path) -> set[str]:
    try:
        document = yaml.safe_load(candidate.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        return set()
    if not isinstance(document, dict):
        return set()
    return {
        str(proxy.get("name"))
        for proxy in document.get("proxies", [])
        if isinstance(proxy, dict)
    }


def active_profile(selected_node: str) -> pathlib.Path:
    """Resolve the active CFW profile and verify that it defines the node.

    Several profiles can define identically named subscription nodes. CFW's
    profiles/list.yml is the authority for the loaded profile; choosing the
    newest matching YAML can silently label a different profile.
    """
    manifest = PROFILES / "list.yml"
    try:
        listing = yaml.safe_load(manifest.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError):
        listing = None
    if isinstance(listing, dict) and isinstance(listing.get("files"), list):
        index = listing.get("index")
        files = listing["files"]
        if isinstance(index, int) and 0 <= index < len(files) and isinstance(files[index], dict):
            filename = files[index].get("time")
            if isinstance(filename, str) and pathlib.Path(filename).name == filename:
                candidate = PROFILES / filename
                if selected_node in profile_proxy_names(candidate):
                    return candidate
                fail("the active CFW profile does not define the selected runtime node; reload the subscription before writing labels")

    matches: list[pathlib.Path] = []
    for candidate in PROFILES.glob("*.yml"):
        if candidate.name == "list.yml":
            continue
        if selected_node in profile_proxy_names(candidate):
            matches.append(candidate)
    if not matches:
        fail("could not find the active subscription profile defining the selected node")
    if len(matches) > 1:
        fail("multiple profiles define the selected node and the active CFW manifest is unavailable; refusing to guess")
    return matches[0]


def apply_company_network_template(profile: pathlib.Path) -> pathlib.Path:
    """Idempotently restore the user's company DNS, Hosts and routing template."""
    try:
        document = yaml.safe_load(profile.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        fail(f"cannot parse {profile}: {exc}")
    if not isinstance(document, dict):
        fail(f"{profile} is not a Clash profile")

    proxy = {"name": COMPANY_BROWSER_PROXY, "type": "http", "server": "172.19.80.105", "port": 5000}
    document["proxies"] = [item for item in document.get("proxies", [])
                           if not (isinstance(item, dict) and item.get("name") == COMPANY_BROWSER_PROXY)]
    document["proxies"].insert(0, proxy)

    existing_rules = document.get("rules", [])
    wanted = {re.sub(r"\s+", "", rule) for rule in COMPANY_TEMPLATE_RULES}
    document["rules"] = COMPANY_TEMPLATE_RULES + [
        rule for rule in existing_rules if re.sub(r"\s+", "", str(rule)) not in wanted
    ]

    hosts = document.setdefault("hosts", {})
    hosts.update({"wifiauth.myhexin.com": "10.9.0.1", "gitlab-outer.myhexin.com": "10.222.1.225"})
    dns = document.setdefault("dns", {})
    dns["use-hosts"] = True
    policy = dns.setdefault("nameserver-policy", {})
    policy.update({
        "+.myhexin.com": INTERNAL_DNS,
        "+.10jqka.com.cn": INTERNAL_DNS,
        "+.10jqka.com": INTERNAL_DNS,
        "b2bcrm.0033.com": INTERNAL_DNS,
        "mall.stocke.com.cn": INTERNAL_DNS,
        "gitlab-outer.myhexin.com": INTERNAL_DNS,
    })

    rendered = yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100000)
    try:
        yaml.safe_load(rendered)
    except yaml.YAMLError as exc:
        fail(f"company-network template rendered invalid YAML: {exc}")
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = profile.with_name(f"{profile.name}.before-company-network-{stamp}.bak")
    shutil.copy2(profile, backup)
    temporary = profile.with_name(f".{profile.name}.{stamp}.tmp")
    temporary.write_text(rendered, encoding="utf-8")
    temporary.replace(profile)
    return backup


def prune_profile(profile: pathlib.Path) -> tuple[pathlib.Path, int]:
    try:
        document = yaml.safe_load(profile.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        fail(f"cannot parse {profile}: {exc}")
    if not isinstance(document, dict) or not isinstance(document.get("proxies"), list):
        fail(f"{profile} is not a Clash proxy profile")

    original_document = copy.deepcopy(document)
    original = document["proxies"]
    retained = [proxy for proxy in original if isinstance(proxy, dict) and (
        JP_RE.search(str(proxy.get("name", "")))
        or str(proxy.get("name", "")).startswith(AVAILABLE_LABEL_PREFIX)
        or proxy.get("name") == COMPANY_BROWSER_PROXY
    )]
    if not retained:
        fail("the profile contains no Japanese proxy nodes; no files were changed")
    kept_names = {str(proxy["name"]) for proxy in retained}
    group_names = {str(group.get("name")) for group in document.get("proxy-groups", []) if isinstance(group, dict)}
    document["proxies"] = retained
    for group in document.get("proxy-groups", []):
        if not isinstance(group, dict) or not isinstance(group.get("proxies"), list):
            continue
        group["proxies"] = [entry for entry in group["proxies"] if (
            not isinstance(entry, str)
            or entry in kept_names
            or entry in group_names
            or entry in SPECIAL
            or entry.startswith("[]")
        )]

    def non_node_configuration(value: dict) -> dict:
        """Return all semantic settings except the two lists this operation owns."""
        value = copy.deepcopy(value)
        value.pop("proxies", None)
        for item in value.get("proxy-groups", []):
            if isinstance(item, dict):
                item.pop("proxies", None)
        return value

    # Guard against future edits accidentally changing DNS, rules, ports, TUN,
    # providers, or any other configuration outside this narrow operation.
    if non_node_configuration(original_document) != non_node_configuration(document):
        fail("safety check failed: a non-node setting would change; profile was not written")

    rendered = yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100000)
    try:
        reloaded = yaml.safe_load(rendered)
    except yaml.YAMLError as exc:
        fail(f"safety check failed: rendered YAML cannot be read: {exc}")
    if non_node_configuration(original_document) != non_node_configuration(reloaded):
        fail("safety check failed after YAML serialization; profile was not written")

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = profile.with_name(f"{profile.name}.before-jp-only-{stamp}.bak")
    shutil.copy2(profile, backup)
    temporary = profile.with_name(f".{profile.name}.{stamp}.tmp")
    temporary.write_text(rendered, encoding="utf-8")
    temporary.replace(profile)
    return backup, len(original) - len(retained)


def label_verified_nodes(profile: pathlib.Path, selected_nodes: list[str]) -> pathlib.Path:
    """Add stable aliases for every verified node without renaming sources.

    Keeping source nodes is deliberate: a later run can still locate the
    profile using runtime names, while the user gets stable, numbered entries
    after Clash reloads the profile.
    """
    try:
        document = yaml.safe_load(profile.read_text(encoding="utf-8"))
    except (OSError, yaml.YAMLError) as exc:
        fail(f"cannot parse {profile}: {exc}")
    if not isinstance(document, dict) or not isinstance(document.get("proxies"), list):
        fail(f"{profile} is not a Clash proxy profile")

    sources = []
    for selected_node in selected_nodes:
        source = next((proxy for proxy in document["proxies"]
                       if isinstance(proxy, dict) and proxy.get("name") == selected_node), None)
        if source is None:
            fail(f"verified node is not defined in {profile}: {selected_node}")
        sources.append(source)
    original_document = copy.deepcopy(document)
    aliases = []
    for index, source in enumerate(sources, start=1):
        alias = copy.deepcopy(source)
        alias["name"] = f"{AVAILABLE_LABEL_PREFIX}{index}"
        aliases.append(alias)
    document["proxies"] = aliases + [
        proxy for proxy in document["proxies"]
        if not (isinstance(proxy, dict) and (
            proxy.get("name") == "选择节点" or str(proxy.get("name", "")).startswith(AVAILABLE_LABEL_PREFIX)
        ))
    ]
    primary_group = next((group for group in document.get("proxy-groups", [])
                          if isinstance(group, dict) and group.get("name") == "Proxy"), None)
    if not isinstance(primary_group, dict) or not isinstance(primary_group.get("proxies"), list):
        fail("the profile has no primary Proxy group; aliases were not written")
    alias_names = [alias["name"] for alias in aliases]
    primary_group["proxies"] = alias_names + [entry for entry in primary_group["proxies"] if not (
        entry == "选择节点" or (isinstance(entry, str) and entry.startswith(AVAILABLE_LABEL_PREFIX))
    )]

    def non_node_configuration(value: dict) -> dict:
        value = copy.deepcopy(value)
        value.pop("proxies", None)
        for item in value.get("proxy-groups", []):
            if isinstance(item, dict):
                item.pop("proxies", None)
        return value

    if non_node_configuration(original_document) != non_node_configuration(document):
        fail("safety check failed: a non-node setting would change; aliases were not written")
    rendered = yaml.safe_dump(document, allow_unicode=True, sort_keys=False, width=100000)
    try:
        reloaded = yaml.safe_load(rendered)
    except yaml.YAMLError as exc:
        fail(f"safety check failed: rendered YAML cannot be read: {exc}")
    if non_node_configuration(original_document) != non_node_configuration(reloaded):
        fail("safety check failed after YAML serialization; alias was not written")

    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = profile.with_name(f"{profile.name}.before-available-labels-{stamp}.bak")
    shutil.copy2(profile, backup)
    temporary = profile.with_name(f".{profile.name}.{stamp}.tmp")
    temporary.write_text(rendered, encoding="utf-8")
    temporary.replace(profile)
    return backup


def mean_delay(base: str, secret: str, name: str) -> int | None:
    encoded = urllib.parse.quote(name, safe="")
    url = f"http://{base}/proxies/{encoded}/delay?timeout=3500&url=http%3A%2F%2Fwww.gstatic.com%2Fgenerate_204"
    try:
        payload = api(url, secret)
        value = payload.get("meanDelay", payload.get("delay"))
        return int(value) if isinstance(value, (int, float)) else None
    except ControllerError:
        return None


def select(base: str, secret: str, name: str) -> None:
    api(f"http://{base}/proxies/Proxy", secret, "PUT", {"name": name})


def wait_until_selected(base: str, secret: str, expected: str) -> bool:
    """Avoid testing while Clash is still applying a just-selected node."""
    consecutive_matches = 0
    for _ in range(4):
        try:
            now = api(f"http://{base}/proxies", secret).get("proxies", {}).get("Proxy", {}).get("now")
        except ControllerError:
            now = None
        consecutive_matches = consecutive_matches + 1 if now == expected else 0
        if consecutive_matches >= 2:
            return True
        time.sleep(0.75)
    return False


def clash_proxy_port(base: str, secret: str) -> int:
    """Return a local HTTP-capable Clash inbound used to pin AGY tests."""
    try:
        configs = api(f"http://{base}/configs", secret)
    except ControllerError as exc:
        fail(f"cannot read Clash inbound configuration: {exc}")
    for key in ("mixed-port", "port"):
        value = configs.get(key)
        if isinstance(value, int) and 0 < value <= 65535:
            return value
    fail("Clash has no local mixed-port or HTTP port; AGY routing cannot be proven")


def agy_environment(proxy_port: int) -> dict[str, str]:
    """Force this test process through Clash instead of ambient/TUN routing."""
    environment = os.environ.copy()
    proxy_url = f"http://127.0.0.1:{proxy_port}"
    for key in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        environment[key] = proxy_url
    # Do not inherit an exception for a Google endpoint from the user's shell.
    environment["NO_PROXY"] = "127.0.0.1,localhost,::1"
    environment["no_proxy"] = environment["NO_PROXY"]
    return environment


def process_tcp_source_ports(pid: int) -> set[str]:
    """Read the process' live TCP source ports without inspecting payloads."""
    try:
        completed = subprocess.run(
            ["lsof", "-nP", "-a", "-p", str(pid), "-iTCP", "-Fn"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return set()
    ports = set()
    for line in completed.stdout.splitlines():
        if not line.startswith("n") or "->" not in line:
            continue
        local = line[1:].split("->", 1)[0]
        match = re.search(r":(\d+)$", local)
        if match:
            ports.add(match.group(1))
    return ports


def is_agy_service_host(host: object) -> bool:
    value = str(host or "").lower().rstrip(".")
    return value in AGY_SERVICE_HOSTS or (
        value.endswith(".googleapis.com") and "cloudcode" in value.rsplit(".googleapis.com", 1)[0]
    )


def agy_route_observations(connections: list[dict], source_ports: set[str], expected_node: str) -> tuple[bool, list[str]]:
    """Classify AGY API connections belonging to one observed process."""
    proved = False
    conflicts: list[str] = []
    for connection in connections:
        if not isinstance(connection, dict):
            continue
        metadata = connection.get("metadata", {})
        if not isinstance(metadata, dict):
            continue
        if str(metadata.get("sourcePort", "")) not in source_ports or not is_agy_service_host(metadata.get("host")):
            continue
        chains = connection.get("chains", [])
        chains = [str(item) for item in chains] if isinstance(chains, list) else []
        if expected_node in chains and "Proxy" in chains:
            proved = True
        else:
            conflicts.append(" -> ".join(chains) if chains else "unknown route")
    return proved, conflicts


def run_agy_attempt(base: str, secret: str, expected_node: str, proxy_port: int, request_timeout: int) -> tuple[bool, float, str]:
    started = time.monotonic()
    try:
        process = subprocess.Popen(
            [str(AGY), "--print-timeout", f"{request_timeout}s", "-p", "Reply only with: OK"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=agy_environment(proxy_port),
        )
    except OSError as exc:
        return False, 0.0, f"could not launch AGY: {exc}"

    deadline = started + request_timeout + 8
    source_ports: set[str] = set()
    route_proved = False
    route_conflicts: set[str] = set()
    controller_error: str | None = None
    while process.poll() is None and time.monotonic() < deadline:
        source_ports.update(process_tcp_source_ports(process.pid))
        if source_ports:
            try:
                connections = api(f"http://{base}/connections", secret).get("connections", [])
                proved, conflicts = agy_route_observations(connections, source_ports, expected_node)
                route_proved = route_proved or proved
                route_conflicts.update(conflicts)
            except ControllerError as exc:
                controller_error = str(exc)
        time.sleep(0.15)

    if process.poll() is None:
        process.kill()
        process.communicate()
        return False, time.monotonic() - started, "timeout"

    # One final sample catches a connection opened immediately before exit.
    source_ports.update(process_tcp_source_ports(process.pid))
    if source_ports:
        try:
            connections = api(f"http://{base}/connections", secret).get("connections", [])
            proved, conflicts = agy_route_observations(connections, source_ports, expected_node)
            route_proved = route_proved or proved
            route_conflicts.update(conflicts)
        except ControllerError as exc:
            controller_error = str(exc)

    output, _ = process.communicate()
    elapsed = time.monotonic() - started
    compact_output = (output or "").strip().replace("\n", " ")
    if process.returncode != 0 or compact_output != "OK":
        return False, elapsed, compact_output[:180]
    if route_conflicts:
        return False, elapsed, f"AGY API used a different route: {sorted(route_conflicts)[0]}"
    if not route_proved:
        detail = f"controller unavailable during route observation: {controller_error}" if controller_error else "no process-to-Clash route evidence"
        return False, elapsed, f"AGY replied OK but {detail}"
    return True, elapsed, "OK with exact Clash route evidence"


def agy_works(base: str, secret: str, expected_node: str, proxy_port: int, attempts: int, request_timeout: int) -> tuple[bool, float, str]:
    if not AGY.is_file():
        fail(f"AGY CLI was not found at {AGY}")
    total = 0.0
    for _ in range(attempts):
        ok, elapsed, detail = run_agy_attempt(base, secret, expected_node, proxy_port, request_timeout)
        total += elapsed
        if not ok:
            return False, total, detail
        # A distinct process plus matching controller-chain evidence prevents
        # an old desktop/TUN connection from making this node pass.
        if attempts > 1:
            time.sleep(1)
    return True, total, "OK with exact Clash route evidence"


def antigravity_language_server_pids() -> list[int]:
    try:
        completed = subprocess.run(
            ["pgrep", "-f", "/Applications/Antigravity.app/Contents/Resources/bin/language_server"],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    return [int(value) for value in completed.stdout.split() if value.isdigit()]


def restart_antigravity(base: str, secret: str, expected_node: str) -> tuple[bool, str]:
    """Cold-start the desktop app and prove its API route; interrupts sessions."""
    log = pathlib.Path.home() / "Library/Logs/Antigravity/language_server.log"
    initial_size = log.stat().st_size if log.exists() else 0
    subprocess.run(["pkill", "-KILL", "-f", "/Applications/Antigravity.app/"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["open", "-n", "-a", "Antigravity"], check=False)
    deadline = time.monotonic() + 35
    initialized = False
    route_proved = False
    route_conflicts: set[str] = set()
    while time.monotonic() < deadline:
        source_ports: set[str] = set()
        for pid in antigravity_language_server_pids():
            source_ports.update(process_tcp_source_ports(pid))
        if source_ports:
            try:
                connections = api(f"http://{base}/connections", secret).get("connections", [])
                proved, conflicts = agy_route_observations(connections, source_ports, expected_node)
                route_proved = route_proved or proved
                route_conflicts.update(conflicts)
            except ControllerError:
                pass
        try:
            with log.open("rb") as stream:
                stream.seek(initial_size if log.stat().st_size >= initial_size else 0)
                recent = stream.read().decode("utf-8", "replace")
            if "initialized server successfully" in recent:
                initialized = True
        except OSError:
            pass
        if route_conflicts:
            return False, f"language server used a different route: {sorted(route_conflicts)[0]}"
        if initialized and route_proved:
            return True, "language server initialized and its AGY API route matched the selected node"
        time.sleep(0.25)
    missing = []
    if not initialized:
        missing.append("language-server initialization")
    if not route_proved:
        missing.append("selected-node route evidence")
    return False, "cold-start timed out without " + " and ".join(missing)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fast", action="store_true", help="test only the fastest 8 Japanese candidates")
    parser.add_argument("--prune", action="store_true", help="also rewrite the active profile to retain Japanese nodes only")
    parser.add_argument("--quick", action="store_true", help="use one AGY request per candidate instead of the default two")
    parser.add_argument("--request-timeout", type=int, default=20, metavar="SECONDS", help="per-request AGY timeout, 5–45 seconds (default: 20)")
    parser.add_argument("--node", metavar="NAME", help="test one exact loaded Japanese node")
    parser.add_argument("--restart-antigravity", action="store_true", help="cold-start Antigravity after selection (interrupts its sessions)")
    args = parser.parse_args()
    if not 5 <= args.request_timeout <= 45:
        fail("--request-timeout must be between 5 and 45 seconds")

    base, secret = controller_settings()
    try:
        runtime = api(f"http://{base}/proxies", secret)
    except ControllerError as exc:
        fail(f"Clash controller is unavailable: {exc}")
    candidates = [name for name in runtime.get("proxies", {}).get("Proxy", {}).get("all", []) if isinstance(name, str) and JP_RE.search(name)]
    if args.node:
        if args.node not in candidates:
            fail("--node must exactly match a currently loaded Japanese node")
        candidates = [args.node]
    if not candidates:
        fail("no Japanese nodes are currently loaded; update/reload the subscription first")
    proxy_port = clash_proxy_port(base, secret)
    if shutil.which("lsof") is None:
        fail("lsof is required to bind each AGY request to its Clash connection evidence")

    delays = [(mean_delay(base, secret, name), name) for name in candidates]
    ranked = sorted((item for item in delays if item[0] is not None), key=lambda item: item[0])
    if not ranked:
        fail("all Japanese nodes failed Clash latency checks")
    test_set = ranked[:8] if args.fast else ranked
    previous = runtime.get("proxies", {}).get("Proxy", {}).get("now")
    attempts = 1 if args.quick else 2
    print(f"Testing {len(test_set)} Japanese node(s) with {attempts} fresh AGY CLI request(s) each…")
    winners: list[tuple[int, float, str]] = []
    for delay, name in test_set:
        try:
            select(base, secret, name)
        except ControllerError as exc:
            print(f"FAIL  delay={delay:4}ms  select failed  {name}  ({exc})")
            continue
        if not wait_until_selected(base, secret, name):
            print(f"FAIL  delay={delay:4}ms  switch not confirmed  {name}")
            continue
        ok, elapsed, detail = agy_works(base, secret, name, proxy_port, attempts, args.request_timeout)
        state = "OK" if ok else "FAIL"
        print(f"{state:4}  delay={delay:4}ms  agy={elapsed:4.1f}s  {name}" + ("" if ok else f"  ({detail})"))
        if ok:
            winners.append((delay, elapsed, name))
    if not winners:
        if isinstance(previous, str):
            try:
                select(base, secret, previous)
            except ControllerError:
                pass
        fail("no tested Japanese node passed AGY CLI; the previous selection was restored")
    winner = min(winners, key=lambda item: (item[0], item[1]))
    try:
        select(base, secret, winner[2])
    except ControllerError as exc:
        fail(f"a candidate passed AGY but could not be selected: {exc}")
    if not wait_until_selected(base, secret, winner[2]):
        fail("the winning node passed AGY but its final selection could not be confirmed")
    print(f"\nSELECTED: {winner[2]}  (delay={winner[0]}ms, AGY={winner[1]:.1f}s)")

    if args.restart_antigravity:
        restarted, detail = restart_antigravity(base, secret, winner[2])
        if restarted:
            print(f"Antigravity cold-start: {detail}")
        else:
            fail(f"Antigravity cold-start failed: {detail}")

    profile = active_profile(winner[2])
    template_backup = apply_company_network_template(profile)
    print(f"Company DNS/rules template written\nBackup: {template_backup}")

    if args.prune:
        backup, removed = prune_profile(profile)
        print(f"Profile pruned: {profile}\nBackup: {backup}\nRemoved non-Japanese nodes: {removed}")
        print("Note: the live selection is already applied. Clash for Windows may need a profile reload for the on-disk pruning to take effect.")

    verified = [name for _, _, name in sorted(winners, key=lambda item: (item[0], item[1]))]
    backup = label_verified_nodes(profile, verified)
    print(f"Available-node aliases written: {', '.join(f'{AVAILABLE_LABEL_PREFIX}{index}' for index in range(1, len(verified) + 1))}\nBackup: {backup}")
    print("Reload the active profile in Clash for Windows to make the numbered aliases appear at the top of Proxy.")


if __name__ == "__main__":
    main()
