# MVP Preview Generation Rule

## 适用场景

当 `fl-mvp-definition` Skill 基于 MVP 文档生成视觉 preview 时，必须遵守本文件。

## 核心定义

MVP preview 是产品视觉和交互意图表达，不是最终工程实现。

preview 必须帮助用户确认页面范围、信息结构、关键状态和基础交互，而不是替代技术方案或生产代码。

Figma Prompt 是交付给 Figma 或设计工具的视觉生成输入资产。它不是最终设计稿，也不是代码实现方案；它必须把已确认的产品范围、页面、组件、状态、视觉风格和禁止项表达为设计工具可执行的说明。

MVP Version History 是 MVP 本体的版本与完成状态记录。它记录 `docs/mvp/` 与 `preview/mvp/` 产物的范围变化、状态变化、完成 Gate 和用户确认情况；它不替代 Figma Prompt 版本归档。

## 目录与工程化规则

preview 必须生成在：

```text
preview/mvp/
```

在工程化架构下，必须拆分为：

```text
preview/mvp/
├── README.md             # 覆盖页面与交互指引，需提供 Node 运行测试说明
├── package.json          # 管理本地开发服务器（如 Vite 等）及依赖包
├── index.html            # 静态页面入口
├── styles.css            # 独立样式表
├── app.js                # 前端交互与绘图渲染逻辑
├── mock-data.js          # 本地假数据字典
├── validate_preview.js   # 本地高精度交互仿真回归测试脚本 (Node.js 运行)
├── plans/                # AI Coding 思路的规划与规格说明存放目录 [NEW]
│   ├── preview_epic_plan.md  # Preview 开发大计划（包含视觉设定与 WP 状态看板）
│   └── preview_wp-XXX_spec.md # 每个 WP 的具体开发规格说明书
└── assets/               # 本地静态资源 (Icons、图片等)
```

不得使用单文件实现。必须在本地配置 Node.js 运行环境以管理包依赖及进行回归测试。

## 开发与 Subagent 分工规则

- **智能体协同分工**：主产品 Agent 不应直接手写复杂的 preview 代码。主 Agent 负责定义原型草案，编写 `preview_epic_plan.md`，审查最终交付质量与代码 Diff。必须委派一个精通前端工程化的 `PreviewDeveloper` 辅助子智能体，由其负责编写各 WP 的 `_spec.md` 说明书，并在开发分支上完成编码、npm 包配置和本地仿真测试。
- **开发入口门禁**：子智能体或任何外部开发 Agent 必须遵守顶层 `SKILL.md` 的 Preview 步骤与本文件约束，不得创建额外入口或重新路由内部阶段。
- **允许三方包安装**：为了在预览中展现高颜值交互（Rich Aesthetics）与动效，允许在 `package.json` 中安装和配置第三方 npm 包（如打包编译工具、精美图形库等），以提效和提高 preview 的表现力。

## Preview AI Coding 规划与交付规范

- **Epic 大计划拆解**：开始编写代码前，必须先在 `preview/mvp/plans/preview_epic_plan.md` 中拆解出清晰的 WorkPackages (WPs)。任务应当是增量式的，如样式体系搭建 -> 假数据接入 -> 页面实现 -> 交互仿真验证。
- **防守清理与 Spec 生成**：在领取新的 WP 开发时，必须先在 `plans/` 下物理删除不相关的旧 Spec 文件。然后为当前 WP 独立生成 `preview_wp-XXX_spec.md`。
- **高颜值视觉设计 (Rich Aesthetics)**：前端开发应避免通用平淡的设计，应采用高颜值的 CSS，如磨砂玻璃 (Glassmorphism)、流畅渐变色、微动效 (Micro-animations) 等，以向用户传达极致产品质感。

## 覆盖规则

- preview 必须覆盖 MVP 中所有有视觉呈现的页面。
- preview 必须覆盖关键状态，包括默认状态、空状态、错误状态和核心成功状态。
- 如果某个功能无视觉界面，应在 `preview/mvp/README.md` 中说明不覆盖原因。
- preview 页面范围必须来自用户确认过的 MVP 文档，不得自行新增未确认页面。

## 数据和网络规则 (零接口调用约束)

- **100% 纯静态前端产物**：无论在 Node.js 中使用何种构建工具或三方库，最终生成的必须是可以在本地直接静态打开的页面。
- **本地 Mock 数据机制**：必须纯依赖本地假数据，所有假数据集中存放在 `mock-data.js` 中。
- **严禁外部接口调用**：前端页面和运行脚本绝对不得发起任何网络请求（如 `fetch`, `axios`, `XMLHttpRequest`），严禁依赖任何远程图片、远程字体、外部 API、CDN 或线上资源，确保在断网环境下完全可用。

## 交互规则

- preview 可以包含本地状态切换、筛选、tab、弹窗、表单模拟和页面切换。
- preview 不得承诺真实保存、真实登录、真实支付或真实消息发送。
- 所有模拟行为必须能在本地静态文件中运行。
- preview 默认面向最终用户体验，同时让客户/业务方能快速理解产品价值。不得只做内部线框图或纯组件堆叠。
- preview 必须明确首屏价值、核心 CTA、主用户路径、关键反馈、空状态去向和错误恢复去向。

## 验收规则

- `index.html` 能在本地无服务器或通过本地静态服务直接打开，无任何网络依赖。
- 页面和状态覆盖清单、本地 Node 环境配置方法写入 `preview/mvp/README.md`。
- `preview/mvp/README.md` 必须包含用户体验验收清单，说明首屏价值、核心 CTA、主路径、空状态、错误状态和成功反馈。
- **必须通过自动化交互回归测试**：在交付前，必须在 Node.js 环境下成功运行 `node validate_preview.js`（或等价的仿真测试脚本），模拟关键交互流程（如 Tab 切换、对比渲染、数据状态切换等），确保没有发生暂时性死区（TDZ）或空指针等任何 JavaScript 运行时错误，且脚本正常退出。
- preview 与 `docs/mvp/MVP.md`、`docs/mvp/user-flow.md`、`docs/mvp/data-and-states.md` 完全一致。
- preview 通过产品体验验收：目标用户能理解首屏价值，主路径可走通，核心 CTA 明确，关键状态均有下一步去向。

## Figma Prompt 归档规则

- Figma Prompt 必须生成在 `docs/mvp/figma-prompts/`。
- 首版必须按端命名，例如 `FigmaPrompt-App-V1.md`、`FigmaPrompt-Web-V1.md`、`FigmaPrompt-MiniProgram-V1.md`。
- 任何更新必须新增对应端版本文件，例如 `FigmaPrompt-App-V2.md`、`FigmaPrompt-Web-V2.md`、`FigmaPrompt-MiniProgram-V2.md`，不得覆盖旧版本。
- `docs/mvp/figma-prompts/README.md` 必须记录每个端、每个版本的生成依据、变更摘要、审查状态和当前推荐版本。
- Figma Prompt 必须包含：产品定位、目标用户、页面清单、每页核心元素、组件和状态、视觉风格、文案素材、禁止出现内容、响应式要求、输出格式和验收标准。
- Figma Prompt 必须按端拆成独立文件：`FigmaPrompt-App-V{N}.md` 只包含移动 App，`FigmaPrompt-Web-V{N}.md` 只包含 Web，`FigmaPrompt-MiniProgram-V{N}.md` 只包含 Taro 小程序；不得把不同端的页面与状态混写。
- 小程序 Prompt 和 Preview 必须遵守 Fenleng 小程序端的 Token、组件、状态、字体和 Density 契约，并把平台系统授权/支付弹窗标记为平台控制界面，不仿造其视觉。
- Figma Prompt 必须经过 `ProductUxReviewer` 审查；未通过时必须新增修订版本。

## MVP 版本与完成状态归档规则

- MVP 本体版本记录必须生成在 `docs/mvp/version-history.md`。
- 每次 MVP 范围、页面、文案禁区、Preview 覆盖、Figma Prompt 推荐版本或完成状态变化，都必须更新 `version-history.md`。
- `version-history.md` 必须包含当前版本、当前状态、是否完成、最后更新时间、变更记录和完成 Gate。
- 用户未明确确认“流程结束”“MVP 定稿”或等价表达时，不得把当前状态标记为 `completed`，也不得把 Completed 写为 `Yes`。
