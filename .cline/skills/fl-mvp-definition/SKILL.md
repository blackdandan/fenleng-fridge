---
name: fl-mvp-definition
description: "通过产品经理式对话将项目想法收敛为 MVP 文档和静态视觉 preview。 触发场景包含：MVP、PRD、需求范围、功能边界、验收标准、用户故事、产品经理、产品文档。"
---

# fl-mvp-definition

通过产品经理式对话将项目想法收敛为 MVP 文档和静态视觉 preview。

## 适用与命中条件 (Routing Rules)

### 适用场景 / 意图关键词与信号
- **意图关键词**：`MVP`、`PRD`、`需求范围`、`功能边界`、`验收标准`、`用户故事`、`产品经理`、`产品文档`、`视觉 preview`、`页面预览`、`静态预览`、`帮我澄清需求`、`帮我完善产品想法`
- **工程信号**：`文件/目录: docs/mvp/`、`文件/目录: preview/mvp/`

### 排除条件 (Negative Signals)
- 用户明确要求初始化芬棱
- 用户明确要求修改本 base 结构
- 用户明确要求技术架构设计
- 用户明确要求数据库设计
- 用户明确要求 API 设计
- 用户明确要求直接写代码

## 执行方式

1. 根据本 Skill 的适用场景和排除条件确认任务边界。
2. 直接按照下方完整执行流程完成任务；只在当前步骤确实需要时读取对应 reference 或 asset。
3. 若存在 `scripts/`，优先使用其中的确定性程序，并检查其真实输出。
4. 不为内部步骤重新路由 Skill；由本 Skill 保持上下文并执行到完成。

## 完整执行流程

## 目标

本 Skill 用于通过产品经理式多轮对话，将用户的初始想法澄清、收敛并组织为可执行、可验证、可交接给后续技术规划的 MVP 产品定义。

本 Skill 的核心不是一次性生成 PRD，而是由 Agent 以资深产品经理身份持续追问、整理、反问和收敛，直到用户确认可以生成正式产物，并最终确认流程结束。

## 边界

本 Skill 负责：

- 澄清目标用户、核心问题、使用场景和价值闭环。
- 明确产品 Surface（Flutter App、Web、Taro 小程序）及每个 Surface 的页面范围、平台范围和差异边界。
- 定义 MVP 的产品目标、核心假设和成功判断。
- 收敛第一版功能范围，并明确非目标。
- 生成产品 MVP 文档和配套产品辅助文档。
- 基于 MVP 文档生成静态视觉 preview。
- 基于 MVP 文档与 Preview 生成可交付给 Figma 的版本化 Figma Prompt。
- 对 Figma Prompt 进行产品体验审查，并将 Prompt 资产归档。
- 记录关键对话、判断、范围取舍和用户确认。
- 输出本 Skill 的职责、边界、产物清单和后续建议。

本 Skill 不负责：

- 技术架构选择。
- 数据库设计。
- API 或接口契约设计。
- 代码目录规划。
- 具体开发任务拆分。
- 真实后端、真实接口或线上部署。

PRD 不是代码生成入口。MVP 定义完成后，后续应进入技术规划或方案设计流程，再进入 AI Coding Delivery。

## 适用场景

- 用户有一个产品想法，希望梳理成 MVP。
- 用户要求生成 PRD、MVP 文档、功能边界、用户故事或验收标准。
- 用户希望由 AI 作为产品经理，通过对话不断追问和完善需求。
- 用户希望得到产品文档和可打开的视觉 preview。
- 用户希望明确第一版做什么、不做什么，以及如何判断完成。

## 不适用场景

- 用户只要求判断项目机会、尚未要求定义 MVP 时，本 Skill 不启动，由宿主继续按其他 Skill 或普通对话处理。
- 用户已经要求技术架构、数据库、API 或实现计划，应进入未来技术规划流程。
- 用户要求直接写代码、修 bug 或交付工程实现，应进入 `fl-ai-coding-delivery`。
- 用户要求修改 Fenlengtechbase 标准 Skill 资产本身，应进入仓库内部的 `ai-workflow-asset-evolution`。

## 输入

- 用户的产品想法、目标、约束和已有材料。
- 对话过程中用户对问题、场景、功能、范围和视觉方向的回答。
- 可选：已有市场判断、竞品材料、用户反馈、草稿 PRD、草图或业务流程。

## 输出

正式产物只有在用户明确表示“可以生成”后才能落盘。

目标项目中的产品文档目录：

```text
docs/mvp/
├── MVP.md
├── discovery-log.md
├── feature-scope.md
├── user-flow.md
├── acceptance-criteria.md
├── data-and-states.md
├── audience-and-expectation.md
├── surface-scope.md
├── version-history.md
├── application-website-integration.md  # App 专用：官网、协议和工厂官网挂载登记
├── figma-prompts/
│   ├── README.md
│   ├── FigmaPrompt-App-V1.md
│   ├── FigmaPrompt-Web-V1.md
│   ├── FigmaPrompt-MiniProgram-V1.md
│   ├── FigmaPrompt-App-V{N}.md
│   ├── FigmaPrompt-Web-V{N}.md
│   └── FigmaPrompt-MiniProgram-V{N}.md
└── fl-mvp-definition-summary.md
```

目标项目中的视觉 preview 目录：

```text
preview/mvp/
├── README.md
├── package.json
├── index.html
├── styles.css
├── app.js
├── mock-data.js
├── validate_preview.js
├── plans/                    # 仿照 AI Coding 交付思路的计划与规格目录 [NEW]
│   ├── preview_epic_plan.md  # Preview 架构及 WP 拆解计划
│   └── preview_wp-XXX_spec.md # 每个 WP 的具体规格说明书
└── assets/
```

## 文档职责

- `docs/mvp/MVP.md`：唯一权威主文档，描述产品目标、目标用户、核心问题、MVP 范围、价值闭环、非目标和验收方向。
- `docs/mvp/discovery-log.md`：记录关键问题、用户回答、产品判断、范围取舍原因和用户确认。
- `docs/mvp/feature-scope.md`：用 P0、P1、Later、Out of Scope 维护功能范围。
- `docs/mvp/user-flow.md`：描述用户从进入产品到获得价值的完整路径、页面流转和关键分支。
- `docs/mvp/acceptance-criteria.md`：定义核心功能的产品验收标准，不包含技术验收标准。
- `docs/mvp/data-and-states.md`：描述页面状态、空状态、错误状态、假数据和视觉 preview 所需数据。
- `docs/mvp/audience-and-expectation.md`：记录本次产品稿件的目标读者、文档风格、Preview 风格、用户最期待看到的内容和生成前完整性 Gate。
- `docs/mvp/surface-scope.md`：声明 Flutter App、Web 和 Taro 小程序哪些属于本期范围；小程序还需声明微信、支付宝、抖音支持等级、共享页面与平台差异。
- `docs/mvp/version-history.md`：记录 MVP 本体版本、完成状态、最近变更、完成 Gate 和未完成原因；它不替代 Figma Prompt 版本归档。
- `docs/mvp/application-website-integration.md`：当本次定义的是新 App 时，按 Fenleng Knowledge 的应用官网接入模板记录应用官网、用户协议、隐私政策、第三方 SDK 说明、工厂官网入口和核验状态；它不替代法律审查或部署证据。
- `docs/mvp/figma-prompts/README.md`：记录所有 Figma Prompt 版本、生成依据、变更摘要、审查状态和当前推荐版本。
- `docs/mvp/figma-prompts/FigmaPrompt-App-V1.md`：App 端首版完整 Figma Prompt，只覆盖移动 App。
- `docs/mvp/figma-prompts/FigmaPrompt-Web-V1.md`：Web 官网端首版完整 Figma Prompt，只覆盖官网。
- `docs/mvp/figma-prompts/FigmaPrompt-MiniProgram-V1.md`：小程序端首版完整 Figma Prompt，只覆盖已确认的小程序页面，并注明平台共性和平台差异。
- `docs/mvp/figma-prompts/FigmaPrompt-{Surface}-V{N}.md`：每次对应端视觉方向、页面范围、文案禁区或产品决策变化后的新版本 Prompt；不得覆盖旧版本。
- `docs/mvp/fl-mvp-definition-summary.md`：说明本 Skill 的职责、边界、产物清单、确认状态和后续建议。
- `preview/mvp/README.md`：说明 preview 覆盖页面、状态、使用方式、本地 Node 仿真测试以及三方依赖包配置。
- `preview/mvp/package.json`：配置 Preview 开发所需依赖包（如轻量开发服务、构建工具等）及测试启动命令。
- `preview/mvp/index.html`：静态 preview 入口（直接双击或通过静态服务器可本地完美加载运行）。
- `preview/mvp/styles.css`：preview 样式表（提供磨砂玻璃、渐变、发光边框等高颜值视觉样式）。
- `preview/mvp/app.js`：本地前端逻辑，使用 Mock 数据渲染，严禁调用任何外部接口或依赖远程资源。
- `preview/mvp/mock-data.js`：集中化本地 Mock 数据字典，涵盖图表在各时间轴、指标上的真实量级。
- `preview/mvp/validate_preview.js`：高保真交互仿真回归测试脚本（运行于 Node 环境），用于检测并消除暂时性死区（TDZ）、DOM 空值、数据 key 缺失等导致的运行时报错。
- `preview/mvp/plans/preview_epic_plan.md`：原型设计开发大计划与视觉设计方案，包含页面列表、Mock 数据结构和拆分的 WorkPackage 列表。
- `preview/mvp/plans/preview_wp-XXX_spec.md`：每个子工作包的开发规格说明书，详细规范本包需要修改的文件及交互实现方法。
- `preview/mvp/assets/`：本地静态资源。

## 执行步骤

1. **启动对话澄清**
   以资深产品经理视角进入对话，确认用户的产品想法、目标用户、核心问题、业务场景和当前替代方案。

2. **覆盖必要问题域**
   对话必须覆盖目标用户、核心痛点、现有替代方案、MVP 核心假设、最小价值闭环、功能边界、角色权限、数据状态、可视化图表高精确规格、目标 Surface 和成功判断。涉及小程序时必须确认微信、支付宝、抖音哪些属于 P0/P1/Later，并区分统一产品契约与平台授权、支付、分享等差异。
   * 如果本次定义的是新的 App，必须同时读取 Fenleng Project Knowledge 中的 `application-websites` 知识，并确认应用官网 Owner、域名、用户协议、隐私政策、必要的第三方 SDK / 数据处理说明、App 级 canonical Universal Link（默认 `https://{app-domain}/app/`）、Associated Domains、AASA Team ID + Bundle ID 与 `/app/*`，以及接入芬棱软件工厂官网的计划。

3. **确认产品稿件期待**
   在进入正式草案前，必须确认本次 PRD 和 Preview 的使用场景：
   * **目标读者**：默认同时面向研发团队和客户/业务方。研发读者需要可执行、可验收、可交接；客户/业务方需要看懂产品价值、主流程和体验效果。
   * **文档风格**：默认采用可执行版，避免空泛愿景，必须明确功能范围、页面路径、状态、验收标准、数据口径和非目标。
   * **Preview 风格**：默认面向最终用户体验，而不是内部线框图。Preview 应表达真实用户看到的产品界面、信息层级、核心 CTA、主路径和关键反馈。
   * **用户最期待内容**：必须记录用户最在意的是逻辑完整、可开发落地、客户可理解、视觉可信或其他明确标准。

4. **持续范围收敛**
   将用户想法拆入功能池，并区分 P0、P1、Later 和 Out of Scope。Agent 必须主动识别需求膨胀、伪核心功能和第一版不必要复杂度。

5. **形成 MVP 草案摘要与完整性 Gate**
   在正式落盘前，先用对话摘要让用户确认 MVP 目标、功能范围、页面范围、数据图表指标/轴向范围、视觉 preview 范围和已知未决问题。随后执行 PRD 完整性 Gate，未通过时必须继续追问，不得硬生成正式文件。
   * 用户、问题、场景和当前替代方案是否明确。
   * P0 是否足够小，Out of Scope 是否明确。
   * 主用户路径是否从进入到获得价值闭环。
   * 页面范围、默认/空/错误/成功状态是否齐全。
   * 数据、图表口径和 Mock 数据是否足以支撑 Preview。
   * 产品验收标准是否可判断，成功/失败信号是否可复盘。
   * 新 App 是否已经规划应用官网、用户协议、隐私政策、必要的数据处理说明、可由官网交付和验证的 App 级 Universal Link / AASA，以及芬棱软件工厂官网入口。
   * PRD 是否能让研发理解如何拆解开发，客户/业务方理解产品价值。
   * Preview 是否能让最终用户看懂核心价值、核心 CTA 和主路径。
   * `surface-scope.md` 是否明确每个端的页面范围、共享状态、平台差异和不支持声明；小程序是否避免把“可编译”误写为“已生产认证”。

6. **等待生成确认**
   只有用户明确表示“可以生成”“生成正式文件”或等价确认后，才能写入 `docs/mvp/` 和 `preview/mvp/`。

7. **生成产品文档**
   基于模板生成 `docs/mvp/` 下所有文档。`MVP.md` 是权威主文档，其他文档不得引入未被用户确认的新需求。
   同时生成或更新 `docs/mvp/version-history.md`，记录当前 MVP 版本、状态、完成 Gate、最近变更和未完成原因。
   如果本次定义的是新的 App，必须根据 `knowledge/application-websites/application-website-integration-template.md` 生成 `docs/mvp/application-website-integration.md`，并将官网、用户协议、隐私政策、App 级 Universal Link / AASA 和工厂官网入口作为 MVP 的产品验收条件。

8. **工程化生成视觉 preview (AI Coding 模式交付)**
   基于确认的 `MVP.md` 页面范围与数据设计，先读取 Fenleng Design System 的 `knowledge/design-system/README.md`、`principles.md`、`ai-generation.md` 和当前端侧规则，再采用仿 AI Coding 交付流的子步骤。Preview、页面草图和 Figma Prompt 不得自建一套与 Fenleng 冲突的颜色、间距、组件或状态规则。
   * **8.1 Preview 架构与大计划拆解 (Decomposition)**：主 Agent 编写 `preview/mvp/plans/preview_epic_plan.md`（参考 `assets/prd/preview-epic-plan.md.template`），将开发任务拆解为多个串行的 WPs（例如：通用样式脚手架、Mock数据层、主功能页面、弹窗交互、仿真测试脚本）。
   * **8.2 WP Spec 生成与防守清理 (Spec Generation)**：按顺序领取 `Pending` 的 WP，在写入前物理清理多余旧 Spec。调用子智能体生成 `preview/mvp/plans/preview_wp-XXX_spec.md`（参考 `assets/prd/preview-wp-spec.md.template`），精确定义要实现的页面或交互。
   * **8.3 静态 Mock 实现 (Mock Implementation)**：由当前 Agent 或获得明确授权的子智能体按照本 Skill 的 Preview 约束进行纯前端 Mock 开发，保持高颜值与简洁实现，不增加额外路由入口。
   * **8.4 自动化仿真回归验证 (Simulation Verification)**：在本地运行 `node validate_preview.js` 仿真测试，模拟用户各项核心操作，确保无 JavaScript 运行时报错。
   * **8.5 状态回流与循环推进 (Archiving & Loop)**：核对 Preview 渲染的 Diff，更新 Epic Plan 中对应 WP 状态为 `Completed`，物理删除临时的 Spec 文件，并继续流转至下一个 WP，直到所有计划完成。

9. **生成并归档 Figma Prompt**
   基于已确认的 `MVP.md`、`surface-scope.md`、`page-specs.md`、`user-flow.md`、`data-and-states.md`、`audience-and-expectation.md` 和 Preview 范围，为每个已确认 Surface 分别生成版本化 Prompt，例如 `FigmaPrompt-App-V1.md`、`FigmaPrompt-Web-V1.md`、`FigmaPrompt-MiniProgram-V1.md`。
   * Prompt 必须包含产品定位、目标用户、页面清单、每页核心元素、组件与状态、视觉风格、文案要求、禁止出现内容、交付格式和设计工具输出要求。
   * Prompt 必须按端拆成独立文件：App 使用 `FigmaPrompt-App-V{N}.md`，Web 使用 `FigmaPrompt-Web-V{N}.md`，小程序使用 `FigmaPrompt-MiniProgram-V{N}.md`；不得把不同端混写进同一个 Prompt。
   * 小程序 Prompt 必须覆盖 320–599 单列、系统字体、Standard/Compact、默认/加载/空/错误/成功/禁用/权限不足，并明确平台导航、授权、支付与分享差异，不得伪造平台系统弹窗样式。
   * 如果用户反馈只影响某个端，只新增该端新版本；如果跨端影响，同时新增对应端新版本。
   * 每次新增版本后，必须更新 `docs/mvp/figma-prompts/README.md`，记录版本、日期、依据、变更摘要、审查状态和当前推荐版本。

10. **Product UX Review**
   审查 Preview 与 Figma Prompt：
   * 是否符合 MVP 目标与用户场景。
   * 是否把 P0/P1/Later/Out of Scope 边界表达清楚。
   * 首页、设置页、官网等关键入口是否符合用户心智。
   * 是否包含用户明确禁止的文案或入口。
   * 是否足以让 Figma 生成可用高保真视觉稿。
   未通过时必须生成新的 Prompt 版本并记录修订原因。

11. **用户审阅与修订**
   用户查看文档和 preview 后，可以继续反馈。Agent 根据反馈修订相关产物，并记录到 `discovery-log.md` 或 `fl-mvp-definition-summary.md`。
   每次用户反馈导致 MVP 范围、页面、文案、Preview、Figma Prompt 或完成状态变化时，必须同步更新 `docs/mvp/version-history.md`。用户未确认流程结束时，不得将当前状态写为 `completed`。

12. **用户确认结束**
   只有用户明确确认“流程结束”“MVP 定稿”或等价表达后，Skill 才能结束，并输出包含范围、产物、确认状态和后续建议的结果。

## 必须遵守

- `references/mvp-conversational-definition.md`
- `references/mvp-preview-generation.md`
- `references/mvp-pm-closed-loop.md`

## 成功标准

- 用户确认了 MVP 范围和流程结束。
- `docs/mvp/MVP.md` 作为唯一权威主文档存在。
- 所有辅助文档都有明确职责，且不引入未确认的新需求。
- `docs/mvp/audience-and-expectation.md` 明确目标读者、可执行文档风格、面向最终用户的 Preview 期待和完整性 Gate 结果。
- `docs/mvp/version-history.md` 存在，记录当前 MVP 版本、完成状态、最近变更、完成 Gate 和未完成原因。
- 新 App 存在 `docs/mvp/application-website-integration.md`，并明确官网、用户协议、隐私政策、工厂官网入口和核验状态。
- `docs/mvp/surface-scope.md` 存在，并与 MVP、Preview 和 Prompt 的端型范围一致。
- `docs/mvp/figma-prompts/` 存在，包含 `README.md` 和每个已确认 Surface 的首版 Prompt；选择小程序时必须包含 `FigmaPrompt-MiniProgram-V1.md`。
- 每次 Prompt 更新均以 `FigmaPrompt-{Surface}-V{N}.md` 新版本归档，且 README 标明每个端的当前推荐版本。
- `preview/mvp/` 覆盖所有有视觉呈现的页面和关键状态。
- preview 采用 AI Coding 流程交付，其目录下包含完整的 `plans/preview_epic_plan.md` 且所有规划的 WP 均处于 `Completed` 状态。
- preview 拆文件实现，使用本地假数据，不发网络请求，并通过 `validate_preview.js` 自动化仿真测试。
- preview 通过用户体验验收：最终用户能在首屏理解价值，主路径清晰，核心 CTA 明确，异常/空状态有去向。
- Figma Prompt 已完成产品体验审查，能独立指导 Figma 生成视觉稿。
- `fl-mvp-definition-summary.md` 明确本 Skill 的职责、边界、产物清单和后续建议。
- 输出字段完整，MVP 范围、产物和确认状态可由生成文件证明。

## 失败处理

- 如果用户没有确认“可以生成”，不得落正式文件，只能继续对话澄清或输出草案摘要。
- 如果用户要求技术架构、数据库、API 或实现计划，应说明本 Skill 边界，并建议进入后续技术规划流程。
- 如果 preview 页面范围不清晰，应回到对话澄清阶段，而不是自行脑补完整产品。
- 如果 Figma Prompt 缺少页面清单、组件状态、视觉风格、禁止项或版本记录，不得标记为可交付给 Figma。
- 如果用户未确认流程结束，不得宣称 Skill 完成。
- 如果 `docs/mvp/version-history.md` 缺失，或当前状态/完成 Gate 与实际用户确认不一致，不得输出 `completed`。
- 如果新 App 缺少官网、用户协议、隐私政策或工厂官网入口计划，必须保持 MVP 定义未完成，并列出阻断项。
