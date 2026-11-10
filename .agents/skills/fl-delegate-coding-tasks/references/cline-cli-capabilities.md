# Cline CLI 能力快照

仅在选择 Cline 执行器或用户明确要求刷新 Cline 能力时读取。普通任务派发不得重新遍历 help，也不得读取内置模型目录。

## 快照元数据

- 采集日期：2026-08-27
- 本机版本：`3.0.55`
- 可执行文件：`/opt/homebrew/bin/cline`
- 更新策略：只响应用户明确更新要求；刷新时重新运行根命令和所有 help 可发现的子命令 help，不读取或保存模型列表。

## 任务执行能力

| 能力 | CLI 映射 | Broker 结论 |
|---|---|---|
| 非交互任务 | prompt 参数；`--json` 触发 headless | 支持 |
| 结构化输出 | `--json` NDJSON | 支持，包含事件、usage、最终模型元数据 |
| 工作目录 | `--cwd <path>` | 支持 |
| 独立状态 | `--data-dir <path>` | 支持，可隔离本地状态 |
| 原生 worktree | `--worktree` | CLI 支持，但 Fenleng 不使用 |
| 恢复 Session | `--id <session-id>` | 支持 |
| Provider / 模型 | `--provider <id>`、`--model <model-id>` | CLI 支持，但 Broker 不传这两个参数，始终使用 Cline 当前默认配置 |
| 推理强度 | `--thinking none|low|medium|high|xhigh` | 支持 |
| 上下文压缩 | `--compaction agentic|basic|off` | 支持 |
| 权限 | `--auto-approve true|false`、`CLINE_COMMAND_PERMISSIONS` | 支持；探针使用 false，正式任务由 Codex按当前授权决定 |
| 后台 Hub | `--zen` | 支持 |
| ACP | `--acp` | 支持编辑器集成 |
| Hooks | `--hooks-dir`、`hook` | 支持 |
| MCP / Plugin / Skill | `mcp`、`plugin`、`skill` | 支持 |
| 定时任务 | `schedule` | 支持 Hub 持久化调度 |
| 外部渠道 | `connect` | 支持 Telegram、Slack、Discord、Google Chat、WhatsApp |

## 命令树

- `auth [provider]`：配置 Provider、API key、model、base URL、Azure API version、config 和 data-dir。
- `config`：查看配置；本机在非 TTY 管道中执行 `config --json` 仍报 interactive mode requires a TTY，不能用于派发探针。
- `plugin`
  - `install|i <source>`：npm、git、URL、本地路径、强制替换、JSON 输出、项目 cwd。
  - `uninstall|remove <name>`：JSON 输出、项目 cwd。
- `skill [args...]`：转发到 `npx skills`，提供 add/install/list/remove/uninstall。
- `connect [channel]`：启停或恢复 connector；channel 级 help 已覆盖 `telegram`、`slack`、`discord`、`gchat`、`whatsapp`。
- `mcp`
  - `install|add <name> [targetArgs...]`：stdio、SSE、HTTP、streamable HTTP；`--yes` 可非交互安装。
  - `uninstall|remove <name>`。
- `doctor`：`fix` 清理运行进程，`log` 打开日志。
- `history|h`：分页和 JSON；`delete`、`update`、`export`。
- `hook`：从 stdin 处理 hook payload。
- `schedule`
  - `active`、`create`、`delete`、`get`、`history`、`list`、`pause`、`resume`、`stats`、`trigger`、`upcoming`、`export`、`import`、`update`。
  - create/update 支持 cron、prompt、workspace、mode、provider、model、timeout、并发、delivery 和 autonomous 参数。
- `hub`：管理本地 Hub daemon；当前根 help 未公开更深子命令。
- `dashboard`：启动 Hub Dashboard，支持 host、port、public URL、room secret 和 no-open。
- `update`、`version`、`kanban`。

## 默认模型策略

Cline 3.0.55 没有独立的非交互 `models` 命令，模型目录还会随 Provider 和内置 SDK 动态变化。Fenleng 不采集、不保存该目录，也不根据模型名称做路由；探针和正式任务均省略 `--provider` 与 `--model`，直接使用 Cline 当前默认配置。

## Session 策略

Cline 使用其原生 Session 能力。Fenleng 不创建常驻守护进程、不复制 Session 数据，也不维护另一套恢复状态；Codex在当前对话中复用同一个 Cline Session，等待一轮结束后再发送下一轮，只有原生 Session 明确失败时才新建。

官方参考：<https://docs.cline.bot/cli/cli-reference>、<https://docs.cline.bot/cli/scheduling>。
