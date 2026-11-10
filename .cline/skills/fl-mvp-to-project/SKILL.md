---
name: fl-mvp-to-project
description: "承接已确认 MVP，生成或迁移标准项目资产目录，并形成工程指导文件。 触发场景包含：MVP 转项目、fl-mvp-to-project、根据 MVP 创建项目、创建项目资产目录、迁移当前项目目录结构、标准项目目录、项目骨架搭建、首次创建项目前。"
---

# fl-mvp-to-project

承接已确认 MVP，生成或迁移标准项目资产目录，并形成工程指导文件。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`MVP 转项目`、`fl-mvp-to-project`、`根据 MVP 创建项目`、`创建项目资产目录`、`迁移当前项目目录结构`、`标准项目目录`、`项目骨架搭建`、`首次创建项目前`
- **工程信号**：`文件/目录: docs/mvp/`、`文件/目录: preview/mvp/`、`文件/目录: 01-product/`、`文件/目录: 06-project/`

### 排除条件 (Negative Signals)
- 用户明确要求继续定义 MVP
- 用户明确要求直接写业务代码
- 用户明确要求只做代码修复
- 用户明确要求初始化芬棱接入

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

## 目标

本 Skill 用于承接已经确认的 MVP 结果，将其转换为确定的项目资产目录和工程指导文件。

它既支持新项目创建，也支持将历史项目迁移为标准项目资产结构。完成后，项目应具备清晰的产品依据、工程指导、部署入口、运营资料边界、知识沉淀位置和真实代码工程容器。

## 上下游边界

上游是 `fl-mvp-definition`。本 Skill 只接受已经确认的 MVP 结果，不重新发散产品范围。

下游不强绑定任何能力。用户可以在完成后自行选择继续编码、部署、整理资料或进入其他流程。

## 模式

### create-new-project

用于从已确认 MVP 创建标准项目资产目录。

默认创建以下顶层结构：

```text
00-context/
01-product/
02-engineering/
03-deployment/
04-operations/
05-references/knowledge/
06-project/
```

每个目录默认使用 `README.md` 作为指导性文件和 Git 保留文件，不默认使用 `.gitkeep`。

`06-project/` 可以根据技术栈创建更高一级工程容器，例如 `server/`、`web/`、`android/`。本 Skill 不展开真实代码工程内部结构，不创建 `src/`、`components/`、`modules/` 等 coding 阶段目录。

### migrate-existing-project

用于将当前历史项目迁移为标准项目资产结构。

迁移只处理顶层目录、文档类目录和项目资产类文件，不改动 coding 工程内部结构。

迁移必须采用强映射：每个顶层路径都必须得到明确动作。

```text
move
merge
keep
ignore
manual-review
```

实际迁移前必须先生成 `00-context/migration-report.md`，经用户确认后才能执行移动或合并。

## 标准项目资产结构

```text
00-context/
01-product/
02-engineering/
03-deployment/
04-operations/
05-references/knowledge/
06-project/
```

### 00-context

项目上下文入口，记录项目身份、关键决策、约束、术语和外部链接。

默认文件：

```text
README.md
project.yaml
decisions.md
constraints.md
glossary.md
links.md
migration-report.md
```

`migration-report.md` 仅在迁移模式中生成。

### 01-product

产品与 MVP 确定性产物。默认承接 MVP、需求范围、用户流程和验收标准。

市场调研、竞品分析不默认生成；如果上游已有产物或迁移中存在对应资料，才进入本目录。

### 02-engineering

工程指导目录，不存放真实代码。

默认文件：

```text
README.md
engineering-guide.md
architecture.md
coding-guide.md
```

如果项目需要，可以生成：

```text
data-model.md
api-design.md
integration.md
```

### 03-deployment

部署指导和线上状态目录，记录环境、服务器、域名、证书、发布记录和线上状态。macOS 向 Linux 打包发布时使用 `COPYFILE_DISABLE=1` 并排除 `._*` 与 `.DS_Store`。

### 04-operations

运营、账号、合规、上架、知识产权和项目管理增强资料目录。默认不展开复杂子目录；迁移已有资料时可按资料类型展开。

### 05-knowledge

经验沉淀、排障记录、复盘和参考资料目录。它不保存当前交付的源需求或源设计。

### 06-project

真实代码工程容器。只允许存放工程代码、工程脚本和工程内 README。

本 Skill 可创建工程容器级目录，但不展开代码内部结构。

## 输入

- 已确认 MVP 结果
- 项目名称、项目类型和技术栈
- 当前工作目录
- 可选：现有项目目录结构
- 可选：用户确认的工程容器级目录

## 输出

- 标准项目资产目录
- 顶层目录 README 指导文件
- `00-context/project.yaml`
- `02-engineering/engineering-guide.md`
- `02-engineering/architecture.md`
- `02-engineering/coding-guide.md`
- 可选工程容器目录
- 迁移模式下的 `00-context/migration-report.md`
- 结构化执行结果 JSON

## 执行步骤

1. 确认模式：`create-new-project` 或 `migrate-existing-project`。
2. 读取已确认 MVP 结果和项目上下文，并执行 **Day 0 基础设施与授权一次性预检单（Day 0 Pre-flight Checklist）**：在进入后续编码前，集中向 Owner 确认或写入 `00-context/project.yaml` 与 `00-context/decisions.md`：
   - **生产域名矩阵**：官网域名、Web 工作台域名、API 域名；
   - **对象存储（OSS）与凭据模式**：独立或复用的 OSS Bucket 名称、地域、ECS 实例 RAM Role 与独立最小权限 Policy（严禁因未前置确认 OSS 而先用 PostgreSQL `bytea` 存业务文件再事后迁移返工）；
   - **应用标识与中央登记**：Android `applicationId`、iOS `bundleId`、HarmonyOS `bundleName`（统一 `com.fenlengtech.<id>` 规范），同步生成仓库根 `fenleng.project.yaml` 与 `product-core-openapi.json` 骨架，并登记到 `fenlengtechbase/knowledge/project-matrix/projects.json`（避免后期 `fl kno audit` 或 `fl operator` 报 `CROSS_PROJECT_DENIED`）；
   - **同机跨仓联动授权**：确认当 MVP 体验或接口需求超出当前锁定版 `fenleng-shared-platform` / `fenleng-client-sdk` 时，是否授权在本机直接联动升级上游基座并同步登记 `TD`（避免先写大量缺口文档与前端降级分支再推倒返工）。
3. 确定标准顶层目录是否需要创建或迁移。
4. 根据技术栈确定 `06-project/` 下的工程容器级目录。
5. 生成或更新各目录指导性 `README.md`。
6. 生成 `00-context/project.yaml` 和 `02-engineering` 的指导文件。Flutter App 必须从 Day 1 声明 Android、iOS、HarmonyOS NEXT 三端、共享功能契约以及 `fl-ai-coding-delivery/references/flutter-oh-three-platforms.md` 的固定 SDK 基线；本阶段生成工程指导，真实三端平台目录在 coding 初始化时同时建立，不允许将鸿蒙标为未来产品。Android/iOS/HarmonyOS NEXT APP 首次创建时，按 `fl-ai-coding-delivery/references/domain-flutter-architecture.md` 的“APP Day 1 备案展示”要求预置备案配置与显著查询入口；未备案显示“备案号待补充”，不等到上架阶段才补入口。APP/Web 含账号能力时，同时按 `fl-ai-coding-delivery/references/day0-account-channel-i18n.md` 从首版预置邮箱验证、7 天注销、标准字符串目录，以及显式隔离的 `china`/`global` 构建渠道。直接面向用户的界面即使没有账号能力，也须按该契约第 3 节预置至少二十种界面语言与语言切换。含中国发布渠道的 Android/iOS/HarmonyOS NEXT APP 还必须按 `fl-ai-coding-delivery/references/day0-china-app-privacy-consent.md` 预置首启明确同意、随包离线协议、pre-consent allowlist、post-consent SDK bootstrap 以及三端原生 `DeferredPluginRegistrant`（禁止冷启动入口在同意隐私前自动注册业务/文件/设备插件）。所有 APP/Web/小程序按 `fl-ai-coding-delivery/references/day0-telemetry.md` 预置统一 SDK、事件目录、同意门禁和公共上下文路径。
7. 迁移模式下，为每个顶层路径生成强映射迁移报告。
8. 用户确认迁移报告后，执行顶层目录和文档类资产迁移。
9. 验证目录结构、指导文件、工程容器和执行结果 JSON。

## 必须遵守

- `references/mvp-to-project-project-asset-structure.md`

## 成功标准

- 标准顶层目录齐全。
- 每个保留目录都有 `README.md`，不依赖默认 `.gitkeep`。
- `02-engineering` 至少包含 `engineering-guide.md`、`architecture.md`、`coding-guide.md`。
- `06-project/` 只包含工程容器级目录或真实代码工程，不被本文档类资产污染。
- 迁移模式下每个顶层路径都有明确动作，且不移动 coding 工程内部结构。
- 输出包含生成路径、模式、文件清单、验证结果和后续建议。

## 失败处理

- 如果缺少已确认 MVP 结果，应停止并要求先完成 MVP 定义。
- 如果迁移计划存在冲突路径，应标记为 `manual-review`，不得强行覆盖。
- 如果用户未确认迁移报告，不得执行实际迁移。
