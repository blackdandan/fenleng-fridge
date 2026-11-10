# 标准 Skill 工程定义

生成 OpenClaw 项目时，入口能力必须采用目标宿主能够原生发现的标准 Skill，不得增加自定义 Router、资产 Manifest 或嵌套 subskill 协议。

## Skill

- 每个可发现能力使用独立 `SKILL.md`，frontmatter 至少包含 `name` 和描述触发场景的 `description`。
- 连续内部步骤写入同一个 Skill。只有具备独立用户意图和完整价值的能力才拆成平级 Skill。
- 按需说明进入 `references/`，确定性程序进入 `scripts/`，静态资源进入 `assets/`。
- Skill 必须说明输入、输出、执行步骤、完成标准和失败处理。

## 工具与编排

- 外部工具优先使用 MCP 或目标宿主原生 Tool。
- 确定性动作由脚本实现，并由 Skill 明确参数、时机和安全边界。
- 如果 OpenClaw 自身提供标准任务流或 Agent 配置，可以使用其原生格式；不得把 Fenlengtechbase 的内部抽象复制到目标工程。

## 验证

- 验证标准 Skill 可发现、引用资源存在、脚本可运行。
- 运行目标宿主的 smoke test 和项目结构校验。
- 不为目录对称创建空 Skill、Schema、Hook 或脚本。
