---
name: fl-project-mcp-onboarding
description: "将宿主项目接入 Fenlengtech Project Knowledge MCP，并建立可验证的知识维护契约。 触发场景包含：接入 MCP 体系、接入项目知识 MCP、创建项目知识清单、维护 MCP 知识、校验项目知识。"
---

# fl-project-mcp-onboarding

将宿主项目接入 Fenlengtech Project Knowledge MCP，并建立可验证的知识维护契约。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`接入 MCP 体系`、`接入项目知识 MCP`、`创建项目知识清单`、`维护 MCP 知识`、`校验项目知识`
- **工程信号**：`文件/目录: fenleng.project.yaml`、`文件/目录: .fenleng/meta.json`

### 排除条件 (Negative Signals)
- 用户只要求查询其他项目
- 用户要求实现 Project Knowledge MCP Server

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

## 目标

把已接入或准备接入 Fenlengtech 的业务宿主转换为可被 Project Knowledge MCP 安全发现和查询的知识节点，同时保证项目仓库继续拥有知识真相源。

## 输入

- 宿主项目根目录和 Fenlengtech 接入状态。
- GitHub 仓库身份、默认 ref、项目类型和生命周期。
- 项目知识目录、关键入口、Owner 和消费者范围。

## 输出

- 位于宿主项目根目录的 `fenleng.project.yaml`。
- 资产暴露盘点和确定性校验结果。
- 校验通过后的中央 Registry 登记请求建议。
- 包含项目身份、知识入口、暴露边界、校验结果和中央登记状态的接入结果。

## 执行步骤

1. 读取宿主仓库和 `.fenleng/meta.json`，确认 Fenlengtech 接入状态，不覆盖已有宿主资产。
2.  盘点身份、知识、权限、Owner 和生命周期。
3. 使用 `assets/project-knowledge/fenleng.project.yaml.template` 创建或修订项目 Manifest。
4. 按 `references/project-knowledge-project-knowledge-exposure.md` 排除敏感路径和仓库根目录。
5. 运行 `fl kno --project <path>`，修复所有阻断项。
6. 输出结构化接入结果；只有状态为 `ready` 时才建议提交中央 Registry 审查。
7. 中央登记由后续人类授权的变更完成，本 Skill 不直接写入 Registry 或远程仓库。

## 必须遵守

- `references/project-knowledge-project-knowledge-exposure.md`

## 成功标准

- 项目身份、仓库、知识根、入口、权限、Owner 和生命周期完整。
- Manifest 通过确定性校验。
- 入口文件真实存在且没有越过知识根或拒绝路径。
- 没有复制其他仓库知识，也没有执行远程写操作。
- 输出字段完整且能由实际文件和校验结果证明。

## 失败处理

- 缺少项目身份、Owner 或 GitHub 仓库时保持 `blocked`，请求最小必要信息。
- 发现绝对路径、路径穿越、仓库根或敏感入口时阻断接入。
- Manifest 已存在且与计划冲突时保留原文件，报告冲突而不覆盖。
- Registry 或远程 GitHub 不可用时保留本地校验结果，不伪报已经登记。
