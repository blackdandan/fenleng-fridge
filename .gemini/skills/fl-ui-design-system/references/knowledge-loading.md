# Design System Knowledge 加载规则

## 当前就在 fenlengtechbase

直接读取 `knowledge/design-system/` 下的规范真相源，不读取 `dist/` 或 `plugins/` 中的派生副本。

## 当前在其他项目

优先使用 `fenleng-project-knowledge` MCP：

1. 查询 `get_project_manifest` 确认 `fenlengtechbase` 的版本和 commit 证据；
2. 查询 `list_project_knowledge` 确认 `knowledge/design-system/` 在暴露根内；
3. 读取 README 和当前任务所需的具体文件；
   涉及文字、密度或可访问性时，同时读取 `text-scale-contract.md`。
4. 在输出中保留 repository、ref、commit、source 和 retrievedAt 证据。

本地同级工作区可作为 MCP Roots 的来源，但不能绕过 Manifest 的知识根和 deniedPaths 约束。
