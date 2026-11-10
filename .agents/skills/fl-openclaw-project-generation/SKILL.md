---
name: fl-openclaw-project-generation
description: "生成以入口 SKILL 触发、可部署到 OpenClaw 的完整项目包。 触发场景包含：生成 OpenClaw 工程、建设 OpenClaw 项目、生成可部署到 OpenClaw 的项目、生成入口 SKILL、用 SKILL 触发完整 OpenClaw 工程、OpenClaw 项目生成工作流、OpenClaw runnable project。"
---

# fl-openclaw-project-generation

生成以入口 SKILL 触发、可部署到 OpenClaw 的完整项目包。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`生成 OpenClaw 工程`、`建设 OpenClaw 项目`、`生成可部署到 OpenClaw 的项目`、`生成入口 SKILL`、`用 SKILL 触发完整 OpenClaw 工程`、`OpenClaw 项目生成工作流`、`OpenClaw runnable project`
- **工程信号**：`文件/目录: openclaw.project.yaml`、`文件/目录: openclaw/`、`文件/目录: skills/`、`文件/目录: taskflows/`、`文件/目录: pipelines/`

### 排除条件 (Negative Signals)
- 用户明确要求只写一个普通 Skill
- 用户明确要求只做 OpenClaw 插件开发
- 用户明确要求只分析现有 OpenClaw 文档
- 用户明确要求项目接入芬棱初始化

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

<!-- 中文注释：本 Skill 用于生成可部署到 OpenClaw 的完整项目包。入口是 OpenClaw 可识别的 SKILL，但工程本体不能退化为单个 SKILL。 -->

## 目标

将用户的 OpenClaw 项目需求生成成一个可部署、可触发、可验证、可修复、可持续进化的 OpenClaw 项目包。

本 Skill 生成的目标项目必须具备：

- 一个入口 `SKILL.md`，用于用户在 OpenClaw 对话中触发完整工程。
- 支撑入口 Skill 的脚本、任务流、配置、数据约定和存储约定；只有独立用户意图才增加平级 Skill。
- 可运行的最小 smoke test，用于证明项目不是静态蓝图。
- 失败诊断和修复回路，用于把运行问题反馈成项目资产更新。

## OpenClaw 工程定义

本 Skill 使用以下工程化定义：

```text
OpenClaw 工程
= 可部署到 OpenClaw workspace 或插件生态中的项目包
+ 入口 Skill
+ 必要时提供可独立触发的平级 Skills
+ OpenClaw 原生 Task Flow 或等价 runner
+ scripts / tools
+ config 与必要的数据契约
+ storage 约定
+ smoke test
+ repair / evolution 记录机制
```

入口 Skill 是用户触发器和完整操作指南。确定性、多阶段、可恢复逻辑下沉到 OpenClaw 原生 taskflow、脚本、工具或插件；不要拆成只服务内部步骤的 Skill。

## 适用场景

- 用户要从一个业务想法生成可部署到 OpenClaw 的 Agent、Skill 或原生任务流项目。
- 用户已有一组 Agent、Skill、Pipeline 或 Schema 蓝图，需要转成 OpenClaw 可运行形态。
- 用户要求入口为 OpenClaw Skill，并希望用户对话时触发完整工程。
- 用户要求工程具备闭环、验证、进化和修复能力。

## 不适用场景

- 只写一个孤立 `SKILL.md`。
- 只开发 OpenClaw native plugin。
- 只分析 OpenClaw 官方文档。
- 只把普通代码项目接入芬棱。

## 输入

- 用户目标、业务领域、目标用户和触发语义。
- 需要部署到 OpenClaw 的能力边界：文本、图片、音频、视频、数据、自动化等。
- 可用的 OpenClaw 工具、插件、模型、媒体 provider 和宿主权限。
- 期望的入口 Skill 名称、触发方式和最小 smoke test。
- 可选：已有 Agent/Skill/Pipeline/Schema/Storage 蓝图。

## 输出

- OpenClaw 项目目录结构。
- `openclaw.project.yaml` 或等价项目描述文件。
- 入口 Skill：`skills/<entry-skill-id>/SKILL.md`。
- 必要时提供真正可独立触发的平级 Skills。
- Task Flow 或等价编排文件。
- scripts。
- schemas 和样例输入输出。
- smoke test 输入、运行步骤和验收结果。
- repair log / evolution log 模板或记录。
- 包含生成路径、能力清单、验证结果、失败点和修复记录的结果。

## 执行步骤

1. **目标建模**
   明确项目类型、入口意图、运行边界、工具依赖、资产类型和不可做事项。

2. **工程骨架设计**
   按 `references/openclaw-project-generation.md` 设计 OpenClaw 工程结构，至少包含入口 Skill、原生 taskflow、scripts、storage、tests 或 smoke tests；只在数据确需确定性验证时增加数据契约。

3. **入口 Skill 设计**
   生成入口 `SKILL.md`。入口 Skill 必须说明触发条件、参数收集、调用编排器、状态反馈、失败处理和用户确认点。

4. **编排层设计**
   设计 OpenClaw 原生 Task Flow 或等价 runner。多阶段、可恢复、可重试的确定性逻辑不得只写成自然语言。

5. **确定性资产生成**
   使用模板生成项目 README、AGENTS、entry Skill、taskflow、项目配置和基础 schema。

6. **结构校验**
   执行 `scripts/validate_openclaw_project_spec.py`，检查入口 Skill、项目配置、taskflow、scripts、schemas、smoke test 和修复记录机制是否存在。

7. **Smoke Test 计划**
   生成最小 smoke test。若目标项目依赖外部 provider，smoke test 可以先验证 dry-run：入口 Skill 能收集 brief，runner 能生成第一阶段任务输入，并能写入结构化输出。

8. **审查与修复**
   审查验证结果。若失败，输出修复计划，回到对应步骤修复。

9. **进化闭环**
   将 smoke test 结果、失败点、修复动作写入项目的 `evolution/` 或 `repair-log.md`，并建议是否反哺对应标准 Skill、reference、asset 或 script。

## 必须遵守

- `references/openclaw-project-generation.md`
- `references/standard-skill-definition.md`
- `references/harness-human-control.md`
- `references/harness-tool-boundary.md`

## 成功标准

- 目标项目包含入口 Skill，且入口 Skill 明确“用户如何触发完整工程”。
- 目标项目包含可执行或可 dry-run 的编排层，不把完整流程塞进单个 Skill。
- 目标项目包含 deterministic validation，并能输出结构化验证结果。
- 目标项目包含 smoke test 和失败修复路径。
- 目标项目包含进化记录机制，可将运行反馈转化为资产更新建议。
- 输出字段完整，并能由生成目录和 smoke test 证明。

## 失败处理

- 如果用户只要求单个 Skill，应降级为 Skill 生成任务，并说明不满足 OpenClaw 工程定义。
- 如果目标依赖缺失的 OpenClaw provider 或宿主工具，应生成 dry-run 项目并标记阻塞项。
- 如果结构校验失败，应输出修复计划并回到资产生成步骤。
- 如果 smoke test 无法执行，应保留可复现输入、阻塞原因和下一步验证命令，不得伪装成功。
