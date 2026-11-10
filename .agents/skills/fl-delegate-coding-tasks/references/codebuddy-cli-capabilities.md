# CodeBuddy CLI 能力快照

仅在选择 CodeBuddy 执行器或用户明确要求刷新 CodeBuddy 能力时读取。

## 快照元数据

- 采集日期：2026-08-27
- 本机状态：未安装，`PATH` 中找不到 `codebuddy`
- 版本、根 help、子命令 help：未采集
- 更新策略：只在用户明确要求且本机已安装后，重新运行版本、根命令和全部可安全读取的子命令 help；不采集或保存模型列表。

## Broker 已声明能力

Broker 当前声明非交互、结构化输出、工作目录、逻辑 Session 和中断能力。以上是预期，不是本机 CLI 实证；在完成 help 遍历和最小 `OK` 探针前不得把 CodeBuddy 加入可用路由池。

连通性探针统一要求禁止工具、禁止修改并只回复 `OK`。`not_installed` 必须在外部执行器开始修改当前工作区前 fail-fast。
