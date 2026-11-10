# OpenAI Luna CLI 能力快照

仅在选择 `openai-luna-max` 执行器、诊断其特殊能力或用户明确要求刷新时读取。普通派发不得重新枚举模型。

## 固定配置

- CLI：本机 `codex exec`，使用原生 Session 新建与恢复能力。
- 模型：`gpt-5.6-luna`。
- 推理强度：`max`。
- 工作区：通过 `--cd` 绑定 Delegation Broker 锁定的 Git 根目录。
- 输出：`--json`；原始 JSONL 由 MCP Broker 和输出过滤器消费。
- 能力边界：与默认持续流执行器保持相同的任务类别、偏好任务、风险上限及读写、验证、审查能力。
- 路由角色：默认持续流执行器的后备候选；首选未安装、未认证、网络不可达或最小 `OK` 探针失败时可以被自动选中。

## Session

首轮使用 `codex exec` 创建 Session，后续轮次使用 `codex exec resume <SESSION_ID>`。模型和推理强度在创建与恢复命令中都显式固定，不跟随宿主临时默认值漂移。

## 证据

OpenAI 官方模型文档声明 `gpt-5.6-luna` 支持 `reasoning.effort=max`、结构化输出、工具、Skills 和 MCP：<https://developers.openai.com/api/docs/models/gpt-5.6-luna>。
