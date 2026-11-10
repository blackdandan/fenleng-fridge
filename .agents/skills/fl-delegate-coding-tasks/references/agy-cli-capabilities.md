# AGY CLI 能力快照

仅在选择 AGY 执行器或用户明确要求刷新 AGY 能力时读取。普通任务派发不得重新遍历 help、agent 或 models。

## 快照元数据

- 采集日期：2026-08-27
- 本机版本：`1.1.22`
- 可执行文件：`/Users/blackdandan/.local/bin/agy`
- 更新策略：只响应用户明确更新要求；刷新时重新运行根命令和所有可安全读取的子命令 help，不运行 `agy models`，不保存模型列表。
- 证据边界：能力来自本机 CLI help 和实际命令；认证语义补充参考 AGY 官方 Headless 文档。

## 任务执行能力

| 能力 | CLI 映射 | Broker 结论 |
|---|---|---|
| 非交互单轮 | `--print` / `--prompt` / `-p` | 支持；prompt 应使用 `--print=<text>`，避免后续选项被吞作 prompt |
| 结构化输出 | `--output-format json|stream-json` | 支持 |
| 多轮流输入 | `--input-format stream-json --output-format stream-json` | 支持；同一进程只初始化一次 |
| 恢复会话 | `--conversation <id>`、`--continue` / `-c` | 支持，conversation 按工作目录作用域管理 |
| 模型选择 | `--model <slug>` | CLI 支持，但 Broker 不传该参数，始终使用 AGY 当前默认模型 |
| 推理强度 | `--effort low|medium|high` | 支持 |
| 执行模式 | `--mode accept-edits|plan` | 支持 |
| 工作目录 | 没有专用 cwd flag | 由 Codex 在项目根目录启动进程 |
| 附加目录 | `--add-dir <path>`，可重复 | 支持 |
| Sandbox | `--sandbox` | 支持终端限制；不等同于 Git 隔离 |
| 自动跳过权限 | `--dangerously-skip-permissions` | Broker 禁止使用 |
| 日志 | `--log-file <path>` | 支持受限日志落盘 |
| Agent 选择 | `--agent <name>`、`agy agent(s)` | 支持；本次 `agy agents` 未返回可选项 |
| MCP | `agy mcp ...` | 支持 stdio、HTTP、header、env 和启停 |
| 插件 | `agy plugin ...` | 支持导入、安装、卸载、启停、校验和 marketplace link |
| 麦克风桥接 | `agy mic-serve` | 支持，仅应监听 loopback |

## 命令树

- `agent` / `agents`：列出可用 Agent。
- `changelog`：查看发布说明。
- `install`：配置 PATH 和 shell alias，可用 `--dir`、`--skip-aliases`、`--skip-path`。
- `mcp`
  - `add <name> <commandOrUrl> [args...]`：支持 `--type stdio|http`、重复 `--env`、重复 `--header`。
  - `remove <name>`、`list`、`enable <name>`、`disable <name>`。
- `mic-serve`：`--addr` 默认 `127.0.0.1:4713`。
- `models`：列出当前在线模型目录。
- `plugin` / `plugins`
  - `list`、`import [source]`、`install <target>`、`uninstall <name>`、`enable <name>`、`disable <name>`、`validate [path]`、`link <marketplace> <target>`、`help`。
- `update`：更新 CLI；当前版本的 `update --help` 没有输出参数说明。

AGY 的 plugin 子命令没有统一、安全的子命令级 `--help`：例如 `uninstall --help` 会把 `--help` 当成插件名。刷新能力时只读取 `agy plugin help`，不得对有副作用的 plugin 子命令逐个追加 `--help`。

## 认证与延迟

AGY headless 使用已缓存凭据：首次在交互式 `agy` 中完成 OAuth 登录，之后非交互调用不会每次要求重新登录；没有缓存凭据时，headless 会以 authentication required 失败而不是等待交互。每个模型请求仍需向后端携带或刷新 OAuth 凭据，因此“无需重新登录”不等于“没有网络鉴权成本”。

本机曾以显式模型诊断新 conversation 的认证延迟；该诊断不属于派发策略。正式任务使用 AGY 当前默认模型。当前 Codex 对话只启动一个 stream-json 进程，所有拆分轮次在同一 conversation 中串行执行，避免重复初始化和进程膨胀；新 Codex 对话或 Session 失败时才重建。

官方参考：<https://www.agy.dev/docs/cli/headless/>、<https://www.agy.dev/docs/cli/conversations/>。
