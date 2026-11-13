# Project Knowledge 远程请求可靠性修复

状态：validated-with-follow-up；用户已批准；分类：work-package（共享 MCP 工具行为）。

## 实施与验证结果
- base 源码 `mcp/project-knowledge/github-adapter.js` 增加每次 15 秒超时（含响应体）、最多 3 次尝试与 250/500ms 退避；认证/权限/404 保留原分类且不重试。
- 最终网络错误提供安全 causeCode、headers/body 阶段和尝试次数，不回显底层异常正文或 Token。
- 新增 `tests/github-request-reliability.test.js`；与 remote/MCP 测试合计 25 项通过。
- 已重新生成五端与插件产物；本机部署生成的 adapter，与源码 SHA256 一致。
- 安装目录的新进程成功读取远程 commit，并完成组织资产查询；commit 为 069718f51642df16e5c80c757943ce03621fd4a0。本机配置已更新 generation 触发长驻 MCP 重启；当前会话重连情况另核实。
- 全量测试 294 项：287 通过、3 失败，其余跳过；失败位于 vivo 资产验证、Flutter SDK 基线和 Windows 文件模式测试，与本次修改路径无交叉，未扩大范围修复。
- 未修改代理、Token、权限策略，未提交或发布。原始间歇失败的确切底层 cause 无历史日志可追溯；修复后新失败会提供诊断码。
- 发布清单重新生成后 `release:validate` 通过。generation 变更已关闭旧 MCP 进程；当前聊天未自动重连，调用返回 Transport closed，需要重新加载插件或重启 Codex 才能在当前聊天继续使用工具。新进程组织资产查询验证已通过，不能将此表述为当前聊天已恢复。

## 证据
- 组织资产搜索多次返回 INTERNAL_ERROR / fetch failed，之后相同搜索成功。
- 独立 Node.js v25 fetch GitHub API 返回 200。
- MCP status 为 available/cache；成功搜索固定 commit 为 069718f51642df16e5c80c757943ce03621fd4a0。
- 插件 0.7.34 github-adapter.js 直接调用 fetch，无请求超时及重试；hybrid-service.js 串行读取搜索候选文件，任一读取失败终止搜索。
- 尚未取得原失败请求的 cause；不能将具体网络根因断言为代理端口、认证或 DNS 错误。

## 修改范围
在 fenlengtechbase 源仓库修复远程只读请求，并按现有插件分发机制使本机生效；不直接以修改插件缓存作为永久修复，不改变凭据、权限或安全策略。

## 预期行为
- 单次远程请求有有限超时；可恢复的网络失败与暂时性服务错误采用有限重试及退避。
- 认证/无权限/资源不存在等确定性错误不盲目重试，保持原有错误分类。
- 最终失败提供不含凭据的底层错误码、请求阶段和尝试次数，避免只输出 fetch failed。
- 不将失败搜索伪装为完整结果，不破坏 commit 固定和不可变缓存。
- 代理是否需要额外配置由带 cause 的复现证据决定，不预先修改全局代理。

## 验证
- 定向测试网络失败后恢复、重试耗尽、超时、确定性错误不重试与凭据不泄漏。
- 运行源码已有相关 MCP 测试。
- 本机插件重新加载后，通过组织资产搜索和文件读取验证；若重启需用户操作，明确记录尚未完成，不能宣称修复已生效。
