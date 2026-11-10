---
name: fl-project-knowledge-maintenance
description: "审计并维护宿主项目 Manifest、契约知识与生命周期一致性。 触发场景包含：更新项目知识或 Manifest、审计契约变化与知识一致性、检查项目知识漂移。"
---

# fl-project-knowledge-maintenance

审计并维护宿主项目 Manifest、契约知识与生命周期一致性。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`更新项目知识或 Manifest`、`审计契约变化与知识一致性`、`检查项目知识漂移`
- **工程信号**：`文件/目录: fenleng.project.yaml`

### 排除条件 (Negative Signals)
- 用户只要求跨项目只读讨论

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

## 目标

让宿主项目的契约、知识入口、依赖说明和生命周期持续与代码事实一致，并用确定性审计阻断知识漂移。

## 输入

- 宿主项目根目录、Git 比较基线和授权范围。
- 当前 Manifest、知识资产和代码变更。

## 输出

- 授权范围内更新的知识资产和 Manifest。
- 包含变更影响、知识更新、校验结果和未解决漂移的审计结果。

## 执行步骤

1.  读取 Manifest 和 Git 变化。
2. 运行 `fl kno --project <path>`。
3. 运行 `fl kno audit --project <path> --base <ref>`。
4. 若发现契约敏感变化但没有知识变化，保持 `blocked` 并列出待同步资产。
5. 在授权范围内更新知识、入口或生命周期信息，然后重跑两个命令。
6. 输出维护结果；跨项目或 Registry 修改转入人类授权流程。

## 人类控制点

- 修改其他仓库、中央 Registry、提交、推送和发布必须单独授权。
- 无法确定兼容策略的契约变化必须由人类决定。

## 必须遵守

- `references/project-knowledge-project-knowledge-exposure.md`
- `references/project-knowledge-cross-project-human-gate.md`

## 成功标准

- validate 与 audit 没有阻断项。
- 契约变化和知识变化可在 Git Diff 中对应。
- 未执行未经授权的跨项目写操作。

## 失败处理

- Manifest 无效：先修复 Manifest，不继续声称知识一致。
- Git 基线无效：返回阻断结果并要求有效 ref。
- 知识同步范围未授权：保留工作区并列出最小授权需求。
