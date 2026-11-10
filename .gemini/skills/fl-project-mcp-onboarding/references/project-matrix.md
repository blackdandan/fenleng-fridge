# Project Matrix Knowledge

本文件说明项目矩阵、项目组合和阶段状态。中央项目登记由 Project Knowledge MCP 的确定性解析和测试校验。

每个项目仓库通过根目录 `fenleng.project.yaml` 声明自己的身份、GitHub 仓库、知识入口、暴露策略、Owner 和生命周期。项目仓库是知识真相源；本目录只维护经过审查的中央发现索引，不复制项目完整知识。

## 接入流程

宿主项目首次加入体系时运行 `fl-project-mcp-onboarding`，并使用：

```text
fl kno --project <project-path>
```

只有本地 Manifest 校验通过后，才可以请求加入中央 Project Registry。中央登记、远程访问和跨项目修改仍需要独立授权。

## Registry 完成条件

Project Knowledge 接入不能只在目标仓库生成 `fenleng.project.yaml` 和接入证据。中央登记完成必须同时满足：

- `knowledge/project-matrix/projects.json` 包含目标项目 id。
- registry entry 的 repository、manifestPath、defaultRef 与目标仓库 `fenleng.project.yaml` 一致。
- `tests/` 中有目标项目的 registry 回归覆盖，或已有通用测试能阻止该 entry 被误删。
- `npm run check:project-registry` 和相关测试通过。
- 中央 registry 仓库变更已提交并推送。

`fenleng-shared-platform` 的 WP-021 曾只完成目标仓库侧 Manifest 和证据文档，未完成中央 registry 登记，导致 MCP 查询仍返回 `PROJECT_NOT_REGISTERED`。后续同类任务应把中央 registry 变更视为 WP-021 的必交付项。

## 查询模式

本地 Project Knowledge MCP 通过宿主提供的 MCP Roots 自动发现项目，也可以显式设置多个本地 Git 工作区：

```bash
export FENLENG_PROJECT_ROOTS="/path/project-a:/path/shared-auth"
```

查询结果必须包含 Git commit。没有可解析 commit 的目录不会作为可信项目知识节点提供。

没有 clone 到本地的登记项目通过 GitHub API 只读查询。服务先把 Registry 的默认 ref 或调用者指定 ref 解析为完整 commit，再从该 commit 读取 Manifest、Tree 和知识文件。私有仓库使用进程环境中的 `GITHUB_TOKEN`；Token 不写入 Registry、缓存、工具结果或审计。
