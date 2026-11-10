# OpenClaw Project Generation Rule

<!-- 中文注释：本规则定义芬棱生成 OpenClaw 工程时不可违反的边界。 -->

## 适用场景

当芬棱生成、验证、修复或进化一个可部署到 OpenClaw 的项目包时，必须遵守本规则。

## 核心定义

OpenClaw 工程不是单个 Skill。

OpenClaw 工程必须至少包含：

- 入口 Skill：用户在 OpenClaw 对话中通过 Channel 触发完整工程。
- 支撑 Skills：承载可复用操作手册和能力说明。
- 编排层：Lobster 管道（.lobster 文件）、Task Flow 或运行脚本，用于多阶段执行。
- 配置：描述入口、能力、依赖、存储和 smoke test。
- Schema：固定关键输入、输出和验证结果。
- Smoke test：证明工程可触发，至少能 dry-run。
- 修复与进化记录：记录失败点、修复动作和资产升级建议。

## 入口 Skill 与 Channel 交互规则

- 入口 Skill 绑定对应的通信通道（抽象为 Channel，例如 Discord, Telegram, Feishu 等），且仅作为 Channel 交互与参数收集的窗口。
- 入口 Skill 只负责意图触发、输入归一化、参数确认、挂起等待和最终结果投递。
- 入口 Skill 不得直接执行耗时较长的业务逻辑，多阶段的计算和执行必须下沉至子智能体（subAgent）或编排脚本。
- 入口 Skill 必须定义触发语句、参数 Schema 以及向 Channel 发送结果回执的方式。

## 主-子智能体协同规则（Requester-Specialist Pattern）

- 主 Agent（即与 Channel 交互的 Requester Session）作为流程编排器。对于重度或长耗时任务，必须使用 `sessions_spawn` 工具委托给专门的子智能体（Specialist subAgent）并行或隔离运行。
- 在飞书、Discord 等支持线程的 Channel 中，调用 `sessions_spawn` 时必须指定 `thread: true`（或 `mode: "session"`）将子智能体绑定到子线程会话，防止中间执行过程污染 Channel 的主对话区域。
- 主 Agent 在通过 `sessions_spawn` 发起子智能体运行后，必须立即调用 `sessions_yield` 挂起当前会话，非阻塞地等待子任务的完成 Announce 事件，严禁在主智能体内编写轮询（polling）或 sleep 逻辑。

## 编排层与审批门规则

- 自动化流程编排优先使用官方 `.lobster` 管道文件驱动。
- 编排层默认采用**全自动流转模式**（Straight-through Execution），步骤之间利用标准 JSON 管道（`stdin: $step.stdout`）连续流转，直至流程成功终结或抛出报错。
- 仅在明确需要人类主观决策、安全确认或敏感副作用（如写数据库、资金支出、向 Channel 发送广播等）的阶段，才应在 Lobster 步骤中声明 `approval: required` 以开启审批闸门（Approval Gate）。
- 触发审批门时，子智能体挂起并产出 compact `resumeToken`，由主 Agent 通过 Channel 反馈给人类用户，收到批准指令后调用 `action: "resume"` 恢复执行。


## 验证规则

- 生成项目后必须执行结构校验。
- 校验至少覆盖入口 Skill、项目配置、编排层、scripts、schemas、smoke test 和修复记录。
- 无法执行真实 OpenClaw 时，必须生成 dry-run smoke test，不得伪装为已部署成功。

## 修复与进化规则

- 验证失败必须输出修复计划。
- Smoke test 失败必须记录输入、失败节点、错误摘要和建议修复动作。
- 修复完成后必须重新验证。
- 反复出现的问题应沉淀为对应标准 Skill、reference、asset 或 script 的改进建议。

## 容灾与断点续传规则

- **状态持久化与可追溯**：生成的工程包必须包含持久化的执行状态缓存文件约定，确保异常中断后任务流程是可审计与可追溯的。
- **主 Agent 中断扫描重连**：主 Agent 必须设计在会话连线（Channel 恢复连接）或网关重启恢复时，主动扫描挂起或最近异常阻断的子会话。
- **重连恢复询问**：若扫描发现存在遗留的挂起子任务，主 Agent 应提取最新 `resumeToken`，在 Channel 中主动询问用户是否需要“从断点继续恢复执行”。
- **阶段执行器幂等性**：为了支持从断点恢复运行，所有在 `openclaw.project.yaml` 规格中声明为幂等的阶段执行脚本，在启动时必须先校验本地状态缓存，已成功运行的步骤必须自动跳过，防止造成副作用污染。
