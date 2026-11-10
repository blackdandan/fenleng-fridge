#!/usr/bin/env python3
"""
MVP To Project 确定性执行器。

本脚本负责：
- 创建标准项目资产目录和指导文件
- 根据技术栈创建 06-project 下的工程容器级目录
- 为历史项目生成强映射迁移报告
- 在用户确认后执行顶层目录和文档类资产迁移

脚本不负责理解 MVP，也不负责展开代码工程内部结构。
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path


STANDARD_DIRS = {
    "00-context": {
        "title": "00-context",
        "purpose": "项目上下文入口，记录项目身份、关键决策、约束、术语和外部链接。",
        "includes": "- project.yaml\n- decisions.md\n- constraints.md\n- glossary.md\n- links.md",
        "excludes": "- 不放产品需求正文\n- 不放真实代码\n- 不放部署账号密码",
        "key_files": "- README.md\n- project.yaml\n- decisions.md\n- constraints.md\n- glossary.md\n- links.md",
        "relationships": "为所有目录提供入口上下文；具体资料应放入对应编号目录。",
    },
    "01-product": {
        "title": "01-product",
        "purpose": "保存 MVP、需求范围、用户流程和验收标准等产品确定性产物。",
        "includes": "- MVP.md\n- requirements.md\n- feature-scope.md\n- user-flow.md\n- acceptance-criteria.md",
        "excludes": "- 不放代码\n- 不放部署记录\n- 不放经验复盘",
        "key_files": "- README.md\n- MVP.md\n- acceptance-criteria.md",
        "relationships": "上游来自 MVP 定义；下游约束工程指导和后续 coding。",
    },
    "02-engineering": {
        "title": "02-engineering",
        "purpose": "保存技术选型、架构和 coding 指导，不保存真实代码。",
        "includes": "- engineering-guide.md\n- architecture.md\n- coding-guide.md",
        "excludes": "- 不放 src 等代码目录\n- 不放部署状态\n- 不放运营资料",
        "key_files": "- README.md\n- engineering-guide.md\n- architecture.md\n- coding-guide.md",
        "relationships": "指导 06-project 内的真实代码工程组织。",
    },
    "03-deployment": {
        "title": "03-deployment",
        "purpose": "保存部署指导、环境说明、服务器、域名证书、发布记录和线上状态。",
        "includes": "- deployment-guide.md\n- environments.md\n- server.md\n- domain-and-ssl.md\n- release-record.md\n- online-status.md",
        "excludes": "- 不放产品范围\n- 不放真实业务代码\n- 不放通用知识库内容",
        "key_files": "- README.md\n- deployment-guide.md\n- online-status.md",
        "relationships": "承接工程产物的上线运行信息。",
    },
    "04-operations": {
        "title": "04-operations",
        "purpose": "保存账号、合规、上架、知识产权和项目管理增强资料。",
        "includes": "- accounts.md\n- compliance.md\n- app-store.md\n- project-management.md\n- 迁移产生的合规或知识产权资料子目录",
        "excludes": "- 不放真实代码\n- 不放工程架构指导\n- 不放当前产品需求源文档",
        "key_files": "- README.md\n- accounts.md\n- compliance.md\n- app-store.md",
        "relationships": "支撑项目运营和合规，不替代产品或工程目录。",
    },
    "05-knowledge": {
        "title": "05-knowledge",
        "purpose": "保存经验沉淀、排障记录、复盘和参考资料。",
        "includes": "- lessons-learned.md\n- troubleshooting.md\n- dev-notes.md\n- references/",
        "excludes": "- 不放当前交付源需求\n- 不放真实代码\n- 不放账号凭据",
        "key_files": "- README.md\n- lessons-learned.md\n- troubleshooting.md",
        "relationships": "作为经验库反哺后续项目，不作为当前交付的唯一依据。",
    },
    "06-project": {
        "title": "06-project",
        "purpose": "保存真实代码工程、工程脚本和工程内 README。",
        "includes": "- server/、web/、android/ 等工程容器\n- scripts/ 等工程脚本容器\n- 工程内部 README",
        "excludes": "- 不放产品需求\n- 不放架构指导源文档\n- 不放部署账号和运营资料",
        "key_files": "- README.md\n- 按技术栈生成的工程容器级目录",
        "relationships": "由 02-engineering 指导；内部结构由后续 coding 阶段决定。",
    },
}

IGNORED_TOP_LEVEL = {".git", ".fenleng", ".venv", ".vscode", "temp", ".DS_Store", "cookies.txt", "package-lock.json"}
PROJECT_CODE_DIRS = {"projects-server": "06-project/server", "projects-android": "06-project/android", "projects-web": "06-project/web", "scripts": "06-project/scripts"}
DIRECT_MAPPING = {
    "1-整合管理": "02-engineering",
    "2-范围管理": "01-product",
    "3-质量管理": "05-knowledge",
    "4-知识库": "05-knowledge",
    "5-工作过程存档": "05-knowledge",
    "6-部署": "03-deployment",
    "7-知识产权管理": "04-operations",
    "人力资源管理": "04-operations/project-management/resource",
    "干系人管理": "04-operations/project-management/stakeholder",
    "成本管理": "04-operations/project-management/cost",
    "时间管理": "04-operations/project-management/schedule",
    "沟通管理": "04-operations/project-management/communication",
    "采购管理": "04-operations/project-management/procurement",
    "风险管理": "04-operations/project-management/risk",
    "软考高项学习": "05-knowledge/certification",
}


def render(template: str, replacements: dict[str, str]) -> str:
    content = template
    for key, value in replacements.items():
        content = content.replace("{{" + key + "}}", value)
    return content


def load_template(base_dir: Path, name: str) -> str:
    return (Path(__file__).resolve().parents[1] / "assets" / "mvp-to-project" / name).read_text(encoding="utf-8")


def write_file(path: Path, content: str, created: list[str], updated: list[str], overwrite: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existed = path.exists()
    if existed and not overwrite:
        return
    path.write_text(content, encoding="utf-8")
    (updated if existed else created).append(str(path))


def yaml_items(items: list[str], indent: str = "    ") -> str:
    if not items:
        return f'{indent}- "TODO: 待补充"'
    return "\n".join(f'{indent}- "{item}"' for item in items)


def bullet_items(items: list[str]) -> str:
    if not items:
        return "- TODO: 待补充"
    return "\n".join(f"- {item}" for item in items)


def split_items(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def result(mode: str, status: str, target: Path, next_action: str, *, migration_report=None, created_dirs=None, created_files=None, updated_files=None, moved_paths=None, ignored_paths=None, manual_review_paths=None, warnings=None, errors=None) -> dict:
    return {
        "mode": mode,
        "status": status,
        "target_project_path": str(target),
        "migration_report": str(migration_report) if migration_report else None,
        "created_directories": created_dirs or [],
        "created_files": created_files or [],
        "updated_files": updated_files or [],
        "moved_paths": moved_paths or [],
        "ignored_paths": ignored_paths or [],
        "manual_review_paths": manual_review_paths or [],
        "warnings": warnings or [],
        "errors": errors or [],
        "next_action": next_action,
    }


def ensure_standard_structure(args: argparse.Namespace, base_dir: Path, target: Path, created_dirs: list[str], created_files: list[str], updated_files: list[str]) -> None:
    readme_template = load_template(base_dir, "directory-README.md.template")
    for directory, values in STANDARD_DIRS.items():
        path = target / directory
        if not path.exists():
            path.mkdir(parents=True)
            created_dirs.append(str(path))
        readme = render(
            readme_template,
            {
                "TITLE": values["title"],
                "PURPOSE": values["purpose"],
                "INCLUDES": values["includes"],
                "EXCLUDES": values["excludes"],
                "KEY_FILES": values["key_files"],
                "RELATIONSHIPS": values["relationships"],
            },
        )
        write_file(path / "README.md", readme, created_files, updated_files, args.overwrite)

    tech_stack = split_items(args.tech_stack)
    containers = split_items(args.project_containers)
    context = target / "00-context"
    write_file(
        context / "project.yaml",
        render(
            load_template(base_dir, "project.yaml.template"),
            {
                "PROJECT_NAME": args.project_name,
                "PROJECT_TYPE": args.project_type,
                "TECH_STACK_ITEMS": yaml_items(tech_stack),
                "PROJECT_CONTAINER_ITEMS": yaml_items(containers),
            },
        ),
        created_files,
        updated_files,
        args.overwrite,
    )
    for name, content in {
        "decisions.md": "# Decisions\n\n- TODO: 记录项目关键决策。\n",
        "constraints.md": "# Constraints\n\n- TODO: 记录预算、时间、技术、合规等约束。\n",
        "glossary.md": "# Glossary\n\n- TODO: 记录项目术语。\n",
        "links.md": "# Links\n\n- TODO: 记录 Figma、仓库、服务、文档等外部链接。\n",
    }.items():
        write_file(context / name, content, created_files, updated_files, args.overwrite)

    engineering = target / "02-engineering"
    replacements = {
        "PROJECT_TYPE": args.project_type,
        "TECH_STACK_LIST": bullet_items(tech_stack),
        "PROJECT_CONTAINER_LIST": bullet_items([f"../06-project/{item}/" for item in containers]),
    }
    for template_name, output_name in {
        "engineering-guide.md.template": "engineering-guide.md",
        "architecture.md.template": "architecture.md",
        "coding-guide.md.template": "coding-guide.md",
    }.items():
        write_file(engineering / output_name, render(load_template(base_dir, template_name), replacements), created_files, updated_files, args.overwrite)

    for container in containers:
        container_path = target / "06-project" / container
        if not container_path.exists():
            container_path.mkdir(parents=True)
            created_dirs.append(str(container_path))
        write_file(
            container_path / "README.md",
            f"# {container}\n\n本目录是工程容器级目录。内部代码结构由后续 coding 阶段依据 `../../02-engineering/coding-guide.md` 创建。\n",
            created_files,
            updated_files,
            args.overwrite,
        )


def classify_top_level(path: Path) -> tuple[str, str | None]:
    name = path.name
    if name in STANDARD_DIRS:
        return "keep", name
    if name in IGNORED_TOP_LEVEL or name.startswith("."):
        return "ignore", None
    if name in PROJECT_CODE_DIRS:
        return "move", PROJECT_CODE_DIRS[name]
    if name in DIRECT_MAPPING:
        return "merge", DIRECT_MAPPING[name]
    if path.is_file() and name in {"README.md", "AGENTS.md", ".gitmodules"}:
        return "keep", name
    return "manual-review", None


def migration_rows(target: Path) -> tuple[list[dict[str, str]], list[str], list[str]]:
    rows: list[dict[str, str]] = []
    ignored: list[str] = []
    manual: list[str] = []
    for child in sorted(target.iterdir(), key=lambda item: item.name):
        action, destination = classify_top_level(child)
        rows.append({"path": child.name, "action": action, "destination": destination or ""})
        if action == "ignore":
            ignored.append(str(child))
        if action == "manual-review":
            manual.append(str(child))
    return rows, ignored, manual


def write_migration_report(args: argparse.Namespace, base_dir: Path, target: Path, created_files: list[str], updated_files: list[str]) -> tuple[Path, list[dict[str, str]], list[str], list[str]]:
    rows, ignored, manual = migration_rows(target)
    table = ["| 路径 | 动作 | 目标 |", "| --- | --- | --- |"]
    for row in rows:
        table.append(f"| `{row['path']}` | `{row['action']}` | `{row['destination']}` |")
    manual_list = "\n".join(f"- {item}" for item in manual) if manual else "- 无"
    report = render(load_template(base_dir, "migration-report.md.template"), {"MAPPING_TABLE": "\n".join(table), "MANUAL_REVIEW_LIST": manual_list})
    path = target / "00-context" / "migration-report.md"
    write_file(path, report, created_files, updated_files, True)
    return path, rows, ignored, manual


def apply_migration(target: Path, rows: list[dict[str, str]]) -> list[dict[str, str]]:
    moved: list[dict[str, str]] = []
    for row in rows:
        if row["action"] not in {"move", "merge"} or not row["destination"]:
            continue
        source = target / row["path"]
        destination = target / row["destination"]
        if not source.exists():
            continue
        if destination.exists():
            destination.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                for child in source.iterdir():
                    shutil.move(str(child), str(destination / child.name))
                source.rmdir()
            else:
                shutil.move(str(source), str(destination / source.name))
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(destination))
        moved.append({"from": str(source), "to": str(destination)})
    return moved


def run(args: argparse.Namespace) -> dict:
    target = Path(args.target).resolve()
    base_dir = Path(__file__).resolve().parents[3]
    created_dirs: list[str] = []
    created_files: list[str] = []
    updated_files: list[str] = []

    ensure_standard_structure(args, base_dir, target, created_dirs, created_files, updated_files)

    if args.mode == "create-new-project":
        return result(args.mode, "created", target, "complete", created_dirs=created_dirs, created_files=created_files, updated_files=updated_files)

    report_path, rows, ignored, manual = write_migration_report(args, base_dir, target, created_files, updated_files)
    if not args.apply_migration:
        return result(args.mode, "migration_planned", target, "await_user_confirmation", migration_report=report_path, created_dirs=created_dirs, created_files=created_files, updated_files=updated_files, ignored_paths=ignored, manual_review_paths=manual)

    if manual and not args.allow_manual_review:
        return result(args.mode, "failed", target, "stop", migration_report=report_path, created_dirs=created_dirs, created_files=created_files, updated_files=updated_files, ignored_paths=ignored, manual_review_paths=manual, errors=["存在 manual-review 路径，未允许继续迁移。"])

    moved = apply_migration(target, rows)
    return result(args.mode, "migrated", target, "complete", migration_report=report_path, created_dirs=created_dirs, created_files=created_files, updated_files=updated_files, moved_paths=moved, ignored_paths=ignored, manual_review_paths=manual)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MVP 转项目资产目录执行器。")
    parser.add_argument("--mode", choices=["create-new-project", "migrate-existing-project"], required=True)
    parser.add_argument("--target", default=".")
    parser.add_argument("--project-name", required=True)
    parser.add_argument("--project-type", required=True)
    parser.add_argument("--tech-stack", required=True, help="逗号分隔技术栈。")
    parser.add_argument("--project-containers", default="", help="逗号分隔工程容器，例如 server,web,android。")
    parser.add_argument("--overwrite", action="store_true", help="覆盖已有指导文件。")
    parser.add_argument("--apply-migration", action="store_true", help="执行已确认的迁移。")
    parser.add_argument("--allow-manual-review", action="store_true", help="存在人工复核路径时仍允许迁移可自动处理部分。")
    return parser.parse_args()


def main() -> int:
    try:
        payload = run(parse_args())
    except Exception as exc:  # noqa: BLE001 - 顶层必须输出结构化失败
        payload = result("create-new-project", "failed", Path(".").resolve(), "stop", errors=[str(exc)])
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, indent=2))
    sys.stdout.write("\n")
    return 0 if payload["status"] != "failed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
