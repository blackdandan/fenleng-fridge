---
name: fl-delegate-coding-tasks
description: "仅当用户在当前会话显式调用 $fl-delegate-coding-tasks 时使用；让当前会话的主编排把边界明确的工程轮次串行委派给可配置执行器。不得因普通编码请求、工作区内容或被委派任务自行触发。"
---

# fl-delegate-coding-tasks

当前会话所使用的宿主是主编排。执行器只完成被冻结的当前轮次；主编排负责选择、拆分、等待、审查、验证和最终交付。

## 输入

- 用户目标、授权边界、完成标准和当前项目规则。
- 当前 Git 状态、目标工作区、[任务目录](references/delegation-task-catalog.json) 和 [执行器注册表](references/executors.json)。

## 输出

- 当前会话所选执行器的可用性结论，以及 Delegation Broker 返回的逐轮有界收据。
- 经主编排核对的最终工作区改动、测试与交付结论。

## 硬约束

- 只有用户在当前会话显式调用本 Skill 才能进入本流程；普通任务和执行器生成的消息不得触发或继续委派。
- 一次会话只选择一个执行器并维持一个逻辑 Session；内部拆分不得无界增加进程。
- 外部写任务严格串行：上一轮结束并经主编排验收后才能发送下一轮。
- 创建、恢复 Session 和每轮发送前都必须通过同工作区门禁；Delegation Broker 锁定的 Git 根真实路径和执行器 cwd 必须一致。
- 执行器直接使用锁定工作区，不创建 worktree、分支、stash、委派提交、任务目录或二次集成工件。
- 模型和推理强度只取自所选注册项；值为空时使用执行器默认值，不在派发时枚举模型列表。
- 委派不得扩大用户授权，也不得绕过项目 Spec、审批、破坏性操作或 Git 门禁。
- 执行者全程只与当前会话主编排者交互，不得询问或等待用户；主编排者在用户原授权内审批执行者的动作和后续轮次。

## 执行步骤

1. 读取项目规则，检查当前 Git 状态，确定用户已有修改和本轮允许范围。
2. 先判断当前最小轮次属于哪个大类；需要查询稳定 task id 时才运行 `scripts/agent-broker.mjs tasks --category <name>`，普通派发不得把完整任务目录加载进上下文。
3. 读取 [references/orchestrator-executor-protocol.md](references/orchestrator-executor-protocol.md) 和 [references/delegation-contract.md](references/delegation-contract.md)，再调用 Delegation MCP 的 `delegate_start`。Broker 在模型上下文之外完成候选排序、版本与最小 `OK` 探针；首选不可用时自动尝试下一候选，当前会话主编排者仍拥有最终审批权。
4. 只有用户指定执行器时向 `delegate_start` 传 `executorId`；普通派发不读取完整注册表、能力快照或探针原始输出。
5. 保存 `delegate_start` 返回的 `sessionId`、`workspace` 和执行器摘要；后续所有轮次必须使用同一 Session。
6. 每轮冻结任务类型、风险、模式、目标、路径、验收、验证、已批准动作和停止条件，再明确禁止执行者接触用户、调用本 Skill、启动其他执行者或继续分派。
7. 调用 `delegate_send_round`，再调用一次 `delegate_wait` 挂起等待，不循环调用 `delegate_status`。启动结果和 Progress 都包含 `currentTask`、本轮开始时间、已进行秒数，以及一条有界、脱敏的 `lastActivity` 和健康判断；原始 CLI 流、工具参数、工具结果和内部会话日志不进入主编排上下文。宿主不展示进度通知时，这次等待仍在终态自动返回。
8. 主编排者先审查收据；只有收据显示改动、越界、失败或证据不足时，才按风险读取必要路径和 hunks并独立验证。普通验收不得先读取完整 Diff，也不得持续轮询 Git。
9. 只有验收通过后才进入下一轮。确需超出用户原授权时，先停止执行者，再由主编排者询问用户。
10. 会话结束、用户停止或 Session 不可恢复时调用 `delegate_close`；Broker 关闭本次进程并删除系统临时通信日志，不在仓库留下委派状态。

## 按需资源

- [references/executors.json](references/executors.json) 是默认执行器注册表，保存命令、启用状态、可选模型/推理强度、适用任务、Session 策略、能力文档和探针声明。
- [references/delegation-task-catalog.json](references/delegation-task-catalog.json) 保存可委派任务的稳定 ID、类别、执行模式和默认风险；由 Broker 查询，只有维护目录时才直接读取。
- [references/orchestrator-executor-protocol.md](references/orchestrator-executor-protocol.md) 保存主编排者审批权、执行者终态和禁止直接用户交互的协议；每次建立 Session 前读取。
- 只有诊断所选执行者的特殊能力时才读取其 `capabilityReference`；普通启动使用 Broker 返回的单项配置，能力快照只在用户明确要求时刷新。
- 维护或核对探针结果时读取 [references/probe.schema.json](references/probe.schema.json)；普通派发不需要加载 Schema。
- Delegation MCP 提供 `delegate_start`、`delegate_send_round`、`delegate_wait`、`delegate_status`、`delegate_cancel` 和 `delegate_close`。`delegate_status` 只用于人工诊断或安全等待超时后的恢复，不作为常规轮询接口；CLI Broker 只作为注册表维护、诊断和 MCP 不可用时的显式降级工具。

## 成功标准

- 本流程由用户显式启动，执行器没有产生嵌套委派。
- 每轮使用目录中的任务类型，并交给支持该类别、风险和执行模式的已启用执行者；执行者没有直接与用户交互。
- 所有外部写轮次均在同一锁定工作区和同一逻辑 Session 中串行完成。
- 主编排已核对最终改动和验证结果，仓库不存在委派专用 Git 或状态工件。

## 失败处理

- 注册项禁用，或版本、认证、连接、同工作区门禁失败：Broker 自动尝试下一候选；全部失败时不发送写任务，由主编排接管。
- Session 退出或损坏：先检查工作区，只重发尚未完成的最小轮次。
- 越界修改、工作区漂移或用户与执行器修改相同路径：停止执行器，由主编排处理；不得自动覆盖或回滚。
