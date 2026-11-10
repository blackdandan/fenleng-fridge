# Cross-project Human Gate

## 原则

跨项目知识查询、归属分析和方案讨论默认只读。MCP 返回的内容是决策证据，不是对任何仓库的修改授权。

## 强制边界

- 协调阶段不得修改、提交、推送或发布任何受影响项目。
- 每项拟议变更必须标明目标项目、证据、风险和依赖关系。
- 只有人类明确授权的项目和变更范围，才可分别进入该项目的 `fl-ai-coding-delivery`。
- **单人矩阵同机跨仓直通（Same-Machine Matrix Fast-Track）**：若 Owner 已在任务指令或 `00-context/project.yaml`（`sameMachineUpstreamSyncAllowed: true`）中授权跨仓补齐基座能力，且本机存在目标上游仓库（如 `fenleng-shared-platform`、`fenleng-client-sdk`），AI 应在契约测试保护下直接完成上游接口与 SDK 实现并同步记录 `TD`，避免先在消费仓库构造降级/禁用桩代码再推倒返工。
- 对一个项目的授权不得推导为对其他项目、中央 Registry 或远程仓库的授权。
- 项目归属、兼容策略或执行顺序仍有争议时，结果必须保持 `awaiting-human-decision`。

## 通过条件

协调结果包含可追溯证据、受影响项目、拟议变更、风险、人类决策点和已授权项目；未经授权时 `nextAction` 只能是 `await-human-decision` 或 `stop`。
