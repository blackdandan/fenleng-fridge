#!/usr/bin/env python3
"""Validate the minimum structure of a generated OpenClaw project.

中文注释：本执行器只做确定性结构检查，不判断业务内容质量。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text()


def has_frontmatter(text: str) -> bool:
    return text.startswith("---\n") and "\n---\n" in text[4:]


def parse_simple_yaml(text: str) -> dict:
    import re
    steps = []
    current_step = {}
    lines = text.splitlines()
    in_steps = False
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("steps:"):
            in_steps = True
            continue
        if not line.startswith(" ") and not line.startswith("-") and stripped.endswith(":"):
            in_steps = False
            continue

        if in_steps:
            list_match = re.match(r"^\s*-\s+id:\s*[\"']?([a-zA-Z0-9_-]+)[\"']?", line)
            if list_match:
                if current_step:
                    steps.append(current_step)
                current_step = {"id": list_match.group(1)}
                continue

            id_match = re.match(r"^\s*id:\s*[\"']?([a-zA-Z0-9_-]+)[\"']?", line)
            if id_match:
                if current_step:
                    steps.append(current_step)
                current_step = {"id": id_match.group(1)}
                continue

            app_match = re.match(r"^\s*approval:\s*[\"']?([a-zA-Z0-9_-]+)[\"']?", line)
            if app_match and current_step:
                current_step["approval"] = app_match.group(1)
                continue

            cond_match = re.match(r"^\s*(?:condition|when):\s*[\"']?(.*?)[\"']?\s*$", line)
            if cond_match and current_step:
                current_step["condition"] = cond_match.group(1)
                continue

    if current_step:
        steps.append(current_step)
    return {"steps": steps}


def load_lobster_yaml(text: str) -> dict:
    try:
        import yaml
        return yaml.safe_load(text) or {}
    except ImportError:
        return parse_simple_yaml(text)
    except Exception as e:
        raise ValueError(f"YAML syntax error: {e}")


def validate_project(root: Path) -> dict:
    findings: list[str] = []

    required_dirs = ["skills", "taskflows", "scripts", "schemas", "smoke-tests", "evolution"]
    for directory in required_dirs:
        if not (root / directory).is_dir():
            findings.append(f"missing directory: {directory}")

    project_yaml = root / "openclaw.project.yaml"
    if not project_yaml.is_file():
        findings.append("missing file: openclaw.project.yaml")
    else:
        yaml_content = read_text(project_yaml)
        if "{{" in yaml_content and "}}" in yaml_content:
            findings.append("unresolved template placeholders in openclaw.project.yaml")
        else:
            try:
                data = load_lobster_yaml(yaml_content)
                resiliency = data.get("resiliency")
                if not resiliency:
                    has_resiliency = "resiliency:" in yaml_content
                    has_orphan = re.search(r"supports_orphan_recovery:\s*(true|false)", yaml_content)
                    has_idempotent = "idempotent_steps:" in yaml_content
                    if not has_resiliency:
                        findings.append("missing 'resiliency' configuration in openclaw.project.yaml")
                    elif not has_orphan or not has_idempotent:
                        findings.append("resiliency configuration must define 'supports_orphan_recovery' and 'idempotent_steps'")
                else:
                    if not isinstance(resiliency, dict):
                        findings.append("'resiliency' config must be an object")
                    else:
                        if "supports_orphan_recovery" not in resiliency or "idempotent_steps" not in resiliency:
                            findings.append("resiliency configuration must define 'supports_orphan_recovery' and 'idempotent_steps'")
            except Exception as e:
                findings.append(f"invalid YAML structure in openclaw.project.yaml: {e}")


    skill_files = sorted((root / "skills").glob("*/SKILL.md")) if (root / "skills").is_dir() else []
    if not skill_files:
        findings.append("missing entry/supporting SKILL.md under skills/*/")
    else:
        frontmatter_skills = [path for path in skill_files if has_frontmatter(read_text(path))]
        if not frontmatter_skills:
            findings.append("no SKILL.md contains YAML frontmatter")
        entry_candidates = []
        for path in frontmatter_skills:
            text = read_text(path)
            if re.search(r"entry|入口|trigger|触发", text, re.IGNORECASE):
                entry_candidates.append(path)
        if not entry_candidates:
            findings.append("no entry Skill candidate mentions trigger/入口")

    taskflow_files = list((root / "taskflows").glob("*")) if (root / "taskflows").is_dir() else []
    if not any(path.is_file() for path in taskflow_files):
        findings.append("missing taskflow/orchestration file")
    else:
        lobster_files = [path for path in taskflow_files if path.suffix in (".lobster", ".yaml", ".yml")]
        for path in lobster_files:
            try:
                content = read_text(path)
                if "{{" in content and "}}" in content:
                    findings.append(f"unresolved template placeholders in orchestration file: {path.name}")
                    continue

                data = load_lobster_yaml(content)
                steps = data.get("steps")
                if not steps or not isinstance(steps, list):
                    findings.append(f"lobster workflow {path.name} must contain a non-empty list of 'steps'")
                    continue

                known_ids = set()
                for i, step in enumerate(steps):
                    if not isinstance(step, dict) or "id" not in step:
                        findings.append(f"step at index {i} in {path.name} is missing 'id'")
                        continue
                    step_id = step["id"]
                    if step_id in known_ids:
                        findings.append(f"duplicate step id '{step_id}' in {path.name}")
                    known_ids.add(step_id)

                for i, step in enumerate(steps):
                    if not isinstance(step, dict):
                        continue
                    condition = step.get("condition") or step.get("when")
                    if condition and isinstance(condition, str):
                        vars_in_cond = re.findall(r"\$([a-zA-Z0-9_-]+)(?:\.|\s|$)", condition)
                        for var in vars_in_cond:
                            if var not in ("args", "env") and var not in known_ids:
                                findings.append(f"step '{step.get('id', i)}' references undefined step id '${var}' in condition")
            except Exception as exc:
                findings.append(f"failed to parse lobster file {path.name}: {exc}")


    script_files = list((root / "scripts").glob("*")) if (root / "scripts").is_dir() else []
    if not any(path.is_file() for path in script_files):
        findings.append("missing script or runner file")
    else:
        if project_yaml.is_file():
            try:
                yaml_content = read_text(project_yaml)
                idempotent_steps = []
                if "resiliency:" in yaml_content:
                    res_block = yaml_content.split("resiliency:")[-1]
                    idempotent_steps = re.findall(r"-\s+[\"']?([a-zA-Z0-9_-]+)[\"']?\s*(?:\n|$)", res_block)
                for step in idempotent_steps:
                    step_scripts = list((root / "scripts").glob(f"{step}.*"))
                    for script_path in step_scripts:
                        script_code = read_text(script_path)
                        if not any(kw in script_code.lower() for kw in ["state", "cache", "exist", "json", "history", "checkpoint"]):
                            findings.append(f"idempotent script scripts/{script_path.name} lacks state/cache validation logic")
            except Exception:
                pass


    schema_files = list((root / "schemas").glob("*.json")) if (root / "schemas").is_dir() else []
    if not schema_files:
        findings.append("missing JSON schema files")
    for schema in schema_files:
        try:
            json.loads(read_text(schema))
        except json.JSONDecodeError as exc:
            findings.append(f"invalid JSON schema: {schema.relative_to(root)}: {exc}")

    smoke_files = list((root / "smoke-tests").glob("*")) if (root / "smoke-tests").is_dir() else []
    if not any(path.is_file() for path in smoke_files):
        findings.append("missing smoke test input or instructions")

    if not (root / "evolution" / "repair-log.md").is_file():
        findings.append("missing evolution/repair-log.md")
    if not (root / "evolution" / "evolution-log.md").is_file():
        findings.append("missing evolution/evolution-log.md")

    return {
        "checked_root": str(root),
        "passed": not findings,
        "findings": findings,
    }


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(json.dumps({
            "passed": False,
            "findings": ["usage: validate_openclaw_project_spec.py <project-root>"],
        }, ensure_ascii=False, indent=2))
        return 2

    root = Path(argv[1]).resolve()
    if not root.exists():
        print(json.dumps({
            "checked_root": str(root),
            "passed": False,
            "findings": ["project root does not exist"],
        }, ensure_ascii=False, indent=2))
        return 1

    result = validate_project(root)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
