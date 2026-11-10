# 可配置执行器串行委派契约

仅在用户已于当前会话显式调用本 Skill，且主编排准备委派、恢复 Session 或审查执行结果时读取。

## 核心模型

```text
一次主会话 = 一个委派任务 = 一个执行器逻辑 Session

当前会话主编排冻结第 1 轮
  → 发送给注册表选中的执行器
  → 等待该轮明确完成
  → 审查工作区 Diff 和验证结果
  → 冻结第 2 轮
  → 发送给同一逻辑 Session
  → 等待并审查
  → ……
  → 当前会话主编排完成最终交付
```

任何时刻只有一轮外部写任务运行。上一轮没有完成、失败、停止或被主编排明确收回前，不得发送下一轮。不使用多执行器并发、worktree、任务分支、并发路径锁、结果提交或二次集成。

## 执行器注册表

默认注册表是 `references/executors.json`。主编排也可以接受用户指定的其他 JSON 文件，并通过 `--registry <path>` 传给 Broker。每个注册项包含：

- `id`、`enabled` 和命令；
- 可选的 `model`、`reasoningEffort`；值为 `null` 时使用执行器默认值；
- `suitableTasks`、`avoidTasks` 和按需读取的 `capabilityReference`；
- 支持的任务类别、偏好的具体任务、风险上限和读写/验证/审查能力；
- Session 策略、工作目录绑定、启动/恢复参数；
- 版本与最小 `OK` 探针参数。

只有 `enabled=true` 的注册项可被选择。新增执行器只扩展注册表及其可选能力文档，不修改 Skill 本体。修改静态能力快照仍须用户明确要求。

## MCP Broker 边界

普通委派通过插件内 `fenleng-delegation` MCP 完成。MCP Server 是当前会话的控制面代理：它在模型上下文之外持有执行器进程、过滤原始 CLI 流、维护逻辑 Session、运行候选探针，并把工作区变化压缩为路径级收据。

标准调用顺序：

```text
delegate_start → delegate_send_round → delegate_wait
  → 主编排验收 → 下一轮 send/wait → delegate_close
```

每轮只调用一次 `delegate_wait` 并让调用保持挂起。Broker 在同一次调用中通过 MCP Progress 通知推送最新活动；终态出现时直接返回收据。主编排不得用 `delegate_status` 或 Git Diff 构造轮询循环。`delegate_status` 仅供人工诊断，或在安全等待上限确实到达后恢复观察。

`delegate_start` 绑定项目 Git 根真实路径，按任务偏好和 `selectionPriority` 排序候选，并依次执行版本与最小 `OK` 探针；一个候选不可用时自动尝试下一候选。传入 `executorId` 表示主编排明确指定，此时不自动换用其他执行器。

Broker 只返回执行器摘要、探针结果码、受控终态、最多 50 个变化路径和允许路径外变化。轮次启动状态和 Progress 必须包含 `currentTask.taskType`、有界的 `currentTask.goal`、`timing.startedAt` 和持续刷新的 `timing.elapsedSeconds`；终态后耗时冻结。运行期间最多推送一条 240 字符的 `lastActivity`，并标记 `active`、`quiet` 或 `possibly-stalled`。活动摘要只允许最近的执行者文本片段、工具名称或阶段名，必须截断和脱敏，禁止携带工具参数、工具结果、完整 Diff、源码、原始 stdout/stderr 或过程日志。健康状态只帮助主编排判断是否需要诊断，不会自动杀进程。

活动变化按上限频率推送；没有新活动时使用低频心跳刷新健康判断，因此“疑似卡住”也能在挂起等待中被观察到。Progress 通知只是观察信息，不代表任务完成、验证通过或获得审批。若宿主不展示 Progress，挂起的 `delegate_wait` 仍在终态返回，不能因此退回高频拉取。

## CLI 诊断边界

```bash
BROKER_SCRIPT=.agents/skills/fl-delegate-coding-tasks/scripts/agent-broker.mjs
node "$BROKER_SCRIPT" route --task-type localized-bug-fix --risk medium
node "$BROKER_SCRIPT" probe --project "$PWD" --executor <注册项ID> --timeout 60 --attempts 2
```

CLI Broker 用于维护注册表、查询任务目录、单独诊断路由或在 MCP 不可用时显式降级。它回答哪些已启用且已安装的执行者支持当前任务、工作区是否正确、版本是否可读和最小 `OK` 请求是否可用。`route` 的排序不是自动审批；最终选择和验收仍属于当前会话主编排。探针成功缓存位于操作系统临时目录，不写项目。

只有 CLI 降级流程才在项目根目录执行以下硬门禁，并保存返回的 `workspace`：

```bash
node "$BROKER_SCRIPT" workspace --project "$PWD"
```

只有 `status=ready` 且 `cwd`、`gitRoot`、`workspace` 三个真实路径完全相等时才能创建或继续 Session。每轮发送前重新执行；宿主切换目录、项目路径是符号链接的另一落点、或 Git 根目录不同，均停止分发。

## Session 策略

- `persistent-stream`：在锁定工作区启动一次进程并保持输入流打开；每轮收到注册能力文档定义的终态后才发送下一轮。进程退出或协议损坏时，先检查工作区，只重发未完成的最小轮次。
- `native-session`：使用执行器原生的新建/恢复能力；恢复时仍绑定同一锁定工作区。Fenleng 不镜像其 Session 状态，也不实现第二套恢复协议。
- 其他策略必须先补充能力文档和验证规则，并在注册表启用前证明逻辑 Session、非交互执行、工作目录绑定和中断能力。

主编排按所选注册项的 `session` 字段拼接命令，并替换 `${PROJECT}`、`${SESSION_ID}`、`${MODEL}`、`${REASONING_EFFORT}`。不把空模型字段转成显式模型参数。

MCP Broker 在模型上下文之外通过注册项 `session.outputFilter` 指向的前台包装器启动执行者：

```bash
node scripts/session-stream-filter.mjs \
  --profile <profile> \
  --max-summary-chars <count> \
  -- <执行者命令> <启动或恢复参数>
```

包装器继承锁定工作区和环境，直接转发 stdin，不创建守护进程或仓库状态文件；它只把初始化元数据、终态、错误、流统计和严格裁剪的活动摘要交给 MCP Broker。工具调用只保留名称和阶段，不保留参数或结果；执行者文本只保留最近一条有界、脱敏片段。完整日志和无法解析的行只计数，不进入主编排上下文。过滤后没有执行者终态时视为协议失败，不得退回完整过程流。

## 每轮消息

执行者交互和终态严格遵守 [orchestrator-executor-protocol.md](orchestrator-executor-protocol.md)。执行者只与当前会话主编排者交互。

每轮至少包含：

```text
任务类型：目录中的稳定 task id
风险与模式：本轮实际值
目标：本轮唯一可验收结果
允许路径：可以修改的相对路径
禁止路径：本轮不得修改的路径
必读上下文：开始前必须读取的文件
验收：主编排将检查的行为
验证：主编排将独立运行的命令
已批准动作：执行者无需再次询问即可执行的动作
停止条件：遇到后停止并报告，不扩大范围
```

提示末尾固定要求：不要联系或等待用户，不要提交、切换分支、stash、调用 `$fl-delegate-coding-tasks`、启动其他执行者、继续分派、修改允许路径外文件或输出思考过程。需要决定或扩大范围时，以受控状态报告主编排者。

## 当前工作区执行

1. Session cwd 固定为 Broker 锁定的项目根目录。
2. MCP Broker 在首轮前记录已有 Git 状态；每轮只比较前后状态和文件摘要，区分已有修改、本轮净变化与允许路径外变化。
3. 执行器直接修改当前工作区，不创建任何 Git 隔离结构。
4. 主编排通过一次挂起等待接收进度和终态，再读取 Broker 收据；无修改也会产生明确终态，因此不需要靠 CLI 输出、状态轮询或反复 Git Diff 猜测是否完成。
5. 主编排确认没有越界修改，再运行本轮验证命令；只有高风险或证据矛盾时扩大 Diff 读取范围。
6. 验证失败时，在同一逻辑 Session 发出更窄的整改轮次；验证通过后才进入下一轮。

临时分支只是 Git 引用，在同一工作目录中仍需 checkout，既不能隔离文件，也会与用户未提交修改发生冲突，因此不作为替代通道。

## Hook 边界

当前实现不依赖“Skill 激活期间才生效”的 Hook。宿主 Hook 通常按配置或插件作用域匹配事件，并没有跨宿主通用的 Skill 生命周期作用域；把状态写入仓库或临时文件来模拟会增加残留、竞态和恢复复杂度。

责任划分如下：

- 是否进入新委派任务：由用户显式调用和宿主的隐式调用禁用策略决定，不交给 Hook 猜测。
- 选择哪个执行器：由当前会话主编排读取注册表和任务边界后决定，不交给 Hook。
- 启动前版本、连通性、启用状态和工作区检查：由 Broker 在每次显式委派流程中确定执行。
- 每轮同工作区检查：由主编排在发送前调用 Broker；持续流后续写入通常不会再次触发工具启动 Hook。
- 可选防线：未来若以插件分发，可增加 `PreToolUse` Hook，在首次启动外部命令时阻断错误 cwd 或未通过的 preflight；它只做防御，不替代 Broker 和路由判断。

## 可选临时快照

效率优先时默认不创建快照。只有主编排判断某轮回退风险较高时，才在 `mktemp -d` 创建的系统临时目录保存执行前状态、任务相关 binary diff 和必要的未跟踪文件副本。快照不得写入仓库、Git refs、stash 或分支；该轮被接受或回退完成后删除精确临时目录。

## Session 结束

当前主会话完成、用户停止委派、协议不可恢复或主编排接管时，关闭本次启动且仍存活的执行器进程，并删除本次创建的系统临时快照。仓库中不得存在委派专用目录、worktree、临时分支、refs、stash、WIP commit 或日志归档。
