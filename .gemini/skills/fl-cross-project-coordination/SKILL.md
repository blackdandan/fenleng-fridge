---
name: fl-cross-project-coordination
description: "只读查询项目矩阵，形成跨项目归属、证据、方案、风险和人类决策点。 触发场景包含：查询多个 Fenlengtech 项目的知识、判断问题属于哪个项目、分析跨仓库依赖或契约影响。"
---

# fl-cross-project-coordination

只读查询项目矩阵，形成跨项目归属、证据、方案、风险和人类决策点。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`查询多个 Fenlengtech 项目的知识`、`判断问题属于哪个项目`、`分析跨仓库依赖或契约影响`
- **工程信号**：`文件/目录: fenleng.project.yaml`

### 排除条件 (Negative Signals)
- 用户只要求实现单仓库内的明确变更

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

## 目标

通过只读 Project Knowledge MCP 找到跨项目问题的归属、影响、证据与候选方案，并把讨论阶段和代码修改授权严格分离。

## 输入

- 问题描述、调用方项目和已知项目范围。
- 项目矩阵 Registry、依赖图和 MCP 查询能力。
- 人类明确给出的项目级授权。

## 输出

- 包含证据、项目归属、依赖、候选变更、风险、顺序和授权状态的协调结果。
- 获得授权时，按项目拆分的 `fl-ai-coding-delivery` 输入。

## 执行步骤

1. 发现候选项目及依赖。
2. 只读查询 Manifest、状态、知识和版本证据。
3. 形成归属、受影响项目、拟议变更、风险和未知项。
4. 按模板输出协调结果；未获授权时停在 `awaiting-human-decision`。
5. 人类明确授权后，只把被授权项目和范围分别送入 `fl-ai-coding-delivery`。当 Owner 在单人矩阵全闭环任务中已授权联动修改或“遇阻自行临时决定并继续”，且本机同级工作区存在干净的 `fenleng-shared-platform`、`fenleng-client-sdk` 等上游仓库时，启用 **同机跨仓直通模式（Same-Machine Matrix Fast-Track）**：在契约测试与 `TD` 临时决策登记保护下直接联动补齐上游平台/SDK 能力并回写消费端，不再先编写大量防御性缺口文档与业务层禁用/降级分支后再二次返工。
6. 任一项目的实现结果不得自动授权其他项目、Registry、提交、推送或发布。

## 人类控制点

- 项目归属、跨项目契约策略、兼容方式和执行顺序由人类确认。
- 每个目标项目必须有明确授权范围。

## 必须遵守

- `references/project-knowledge-cross-project-human-gate.md`
- `references/project-knowledge-project-knowledge-exposure.md`

## 成功标准

- 结论包含可追溯版本证据和明确的不确定项。
- 讨论阶段没有写操作。
- 授权按项目隔离，并能进入独立交付闭环。

## 失败处理

- 项目不可见或证据不足：保持 `blocked` 或 `awaiting-human-decision`，不猜测。
- MCP 查询失败：记录错误和已取得证据，不把缓存或旧 ref 伪装为最新事实。
- 授权不清：停止写入阶段并请求精确项目和范围。
