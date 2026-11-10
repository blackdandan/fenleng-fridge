---
name: fl-ai-coding-delivery
description: "处理未明确要求外部 CLI 委派的工程编码、修复、重构、测试、实现、调试和交付请求。用户明确要求 Codex 指挥 AGY、Cline、DeepSeek 或其他 CLI、并行派发任务或减少主 Agent 上下文消耗时不使用本 Skill，改用 fl-delegate-coding-tasks。"
---

# fl-ai-coding-delivery

将工程需求交付为经审批、可验证、可审查的最小闭环；Epic 完成后复盘效率。

## 输入

- 用户目标与约束、仓库规则、代码和验证证据。

## 输出

- 分类与审批状态、必要的 Spec/Plan/Preview、代码与验证证据、交付结论；完成 Epic 额外输出效率审计。

## 执行步骤

1. **确定范围**：读取目标、Git 状态、项目规则、相关入口、直接依赖和测试；区分诊断、实现、删除、迁移、提交和发布权限。
2. **读取条件上下文**：按仓库信号读取唯一命中的 Flutter、后端、Web 或 Taro 跨端小程序规则；不得替换技术栈。新建或首次完善 APP/Web/小程序时读取 `references/day0-telemetry.md`；涉及直接面向用户的界面或账号能力时读取 `references/day0-account-channel-i18n.md`，其中二十语言要求不以账号能力为前提；含中国发布渠道的 Android/iOS/HarmonyOS NEXT APP 还必须读取 `references/day0-china-app-privacy-consent.md`。涉及共享服务时，使用带 commit/ref 的 Project Knowledge 决定边界；缺证据则标记 `UNKNOWN` 并阻断依赖该结论的实现。存在 Experience Manifest 时，按声明选择官方 SDK。
3. **分类**：先输出 `simple`、`work-package` 或 `epic`、理由、影响范围和审批状态。`simple` 仅限不改变依赖、认证/权限、公开契约、共享服务、部署或知识资产的单一局部行为；触及任一边界、跨模块或需独立验收时为 `work-package`；多个有依赖或可独立验收的 WP 为 `epic`。
4. **规划与审批**：simple 使用会话内短计划。WP 写入 `docs/spec/<wp-id>.md`；Epic 写入 `docs/plan/<epic-id>.md`；预览写入 `docs/preview/`。任何生成的 Spec、Plan 或 Preview 都处于调整阶段：用户明确回复 `spec approved` 前，只能调整规划产物，不能修改代码、测试、业务文档、配置、依赖或启动外部 Agent。该指令只批准当前展示范围；每个 Epic WP 均需独立 Spec 与批准。
5. **当前宿主执行**：由当前宿主在批准范围内实现和修复；编译、测试、lint、格式化和产物检查使用确定性命令。本 Skill 不选择、启动或监督外部 Agent。当前请求一旦明确出现外部 CLI 委派意图，应在写代码前停止本流程并改用 `fl-delegate-coding-tasks`，不得同时运行两套交付流程。
6. **实现与验证**：Flutter 移动端先执行 `references/flutter-oh-three-platforms.md` 的统一 SDK 基线、Day 1 Android/iOS/ohos 和三端功能契约，运行 `scripts/check-flutter-oh.mjs` 验证实际来源、版本及平台目录。鸿蒙从Day 0执行 `references/harmonyos-signing.md`，正式HAP使用固定签名打包入口。先改真相源，再补相称测试和必要文档；**严格执行验证粒度预算（Verification Granularity Budget）**：WP 内部微步骤（Micro-step）只运行当前改动文件或子模块的增量定向单测（如 `:domain:test`、单个 vitest/flutter test 文件），严禁每改一小步就重复执行全仓多模块构建、全量浏览器/模拟器截图或 `fl kno audit`；仅在每个 WP 完成边界（Milestone Boundary）集中执行一次全量回归构建、端到端截图矩阵与 `fl kno audit`，以消除冗余 Token 与构建耗时。编码过程中凡新增、修改，或在当前改动范围内发现直接展示给用户的字符串（含按钮、提示、错误、空态与无障碍标签），必须同一 WP 转为国际化资源 key，补齐项目声明的目标语言译文并验证变量、复数、长文本与 RTL；不得新增硬编码文案或把原始异常直接展示。发现范围外的既有文案缺口时记录后续 WP，不未经批准扩大本 WP。Flutter Android 项目初始化、debug/release 打包、官网 APK 发布或签名接入必须执行 `references/domain-flutter-architecture.md` 的 Day 1 签名与加固契约，并复用 `scripts/package-flutter-android.mjs`；SSH Vault 使用 `scripts/store-flutter-android-signing.mjs`，未获具体授权时不得追加 `--apply`。签名凭据文件始终受 Owner 明确授权控制。存在项目 Manifest 时运行 `fl kno audit --project <path> --base <ref>`；不能运行的验证记录 `not-run` 与原因。
7. **审查与交付**：核对批准范围、Diff、知识影响和验证。WP 将实际路径、命令结果、知识审计、风险和外部前置条件回写同一 Spec。代码已验证而外部配置待办时使用 `validated-with-follow-up`；缺授权、契约或验证无法继续时使用 `blocked`。
8. **Epic 收尾**：全部 WP 验收合并后，用 `assets/epic-efficiency-audit/` 在 `docs/ai-coding-audits/<epic-id>/` 生成审计资产并更新索引。跨 Epic 复盘只提出候选改进；流程资产变更须另写 Spec 并等待 `spec approved`。提交、推送和发布仅在用户明确要求时执行。

## 人类控制点

- `spec approved` 是生成的 Spec、Plan 或 Preview 的唯一执行授权。
- 破坏性删除、覆盖用户资产、数据库迁移和不可逆外部操作须单独确认。

## 按需读取

- `references/day0-ipad-basic-adaptation.md`（面向 iOS/iPadOS 的 App 新建、首次完善及相关界面修改；Day 0 默认同时支持 iPhone 与 iPad 基础适配，不以账号或第三方登录为前提，实施前必须读取）
- `references/workflow-clarification-gate.md`
- `references/design-clean-architecture.md` 与 `references/design-modular-architecture.md`
- `references/domain.md` 及命中的端侧规则
- `references/day0-account-channel-i18n.md`（新建或首次完善含账号能力的 APP/Web，或涉及直接面向用户的界面；第 3 节独立适用）
- `references/day0-china-app-privacy-consent.md`（所有含中国发布渠道的 Android/iOS/HarmonyOS NEXT APP）
- `references/day0-telemetry.md`（所有新建或首次完善的 APP/Web/小程序）
- `references/project-matrix.md`；存在 Experience Manifest 时再读 `references/experience-sdk-routing.md`
- `references/engineering-clean-code.md`、`references/engineering-karpathy-guidelines.md`、`references/testing-mocking-rules.md`
- 项目自身的 `AGENTS.md`、宿主规则和验证约定

## 完成标准

- 只有范围合规、验证证据真实、知识影响已处理且风险明确时交付；未批准的规划产物不得执行。

## 失败处理

- 目标不清时集中澄清；验证失败时定位并修复；用户改动冲突或发现超出 WP 的问题时停止扩张并记录最小阻塞条件。执行中新增外部 CLI 委派要求时，保留当前证据并切换到 `fl-delegate-coding-tasks`，不复制委派协议。
