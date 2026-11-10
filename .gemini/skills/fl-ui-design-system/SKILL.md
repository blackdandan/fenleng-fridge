---
name: fl-ui-design-system
description: "按 Fenleng Design System 设计、实现、审查或换肤 UI，并让 AI 生成的页面遵守版本化 Token、主题、组件和可访问性规范；新页面可结合 fl-ux-pro 做系统化 UX 决策，审美升级可结合 fl-taste 做反模板化校准。触发场景包含：UI 设计、视觉规范、页面设计、界面整改、组件设计、换肤、暗色模式、主题、视觉审查、设计 Token、Design System。"
---

# fl-ui-design-system

按 Fenleng Design System 完成 UI 设计、实现、主题和视觉审查任务。

## 适用边界

- 设计新页面、修改页面视觉、建设组件、增加主题或审查 UI 时使用。
- 业务项目的页面代码仍由对应项目 Skill 负责；本 Skill 提供规范路由和验收协议，不代替业务用例实现。
- 不凭空创建应用品牌规范；应用特有决策必须由用户确认并映射到 Fenleng 语义 Token。

## 视觉决策协同

- 本 Skill 是 Fenleng Token、主题、组件、状态和可访问性的最高规范入口。
- 新页面、完整流程或系统级视觉方向可在本 Skill 基础上使用 `fl-ux-pro`，由它整理产品语境、信息架构、Typography/Density Profile 和页面策略。
- 用户要求“更好看”、高级、独特、反 AI 模板或已有页面重设计时可再使用 `fl-taste`，由它校准构图变化度、动效强度、视觉密度和 anti-slop 决策。
- 协同顺序为：Fenleng 规范基线 → UX/结构决策 → 审美校准 → 组件/Token 实现 → 视觉验收；任何增强层不得绕过本 Skill 的规范和失败处理。

## 输入

- UI 设计、实现、审查或换肤任务；
- 当前项目的端侧信号和已有组件边界；
- 可读取的 Fenleng Design System Project Knowledge。

## 输出

- 遵守规范的页面、组件或主题方案；
- 使用的 Token、主题和组件目录证据；
- 状态覆盖、视觉审查结果和未决人类决策点。

## 执行步骤

1. 确认目标端（Flutter、Web、Taro 小程序或其他）、任务类型（设计、实现、审查、换肤）和当前项目。
2. 读取 Fenleng Design System Project Knowledge 的 `knowledge/design-system/README.md`、`principles.md`、`typography.md`、`layout.md` 和 `interaction.md`。
3. 按任务读取 `tokens.json`、目标主题、`theme-contract.md`、`text-scale-contract.md`、`component-catalog.yaml`、`content.md`、`data-display.md`、`accessibility.md` 和 `ai-generation.md`。
4. 如果任务涉及工程实现，读取 `fl-ai-coding-delivery` 中匹配的端侧架构规则和 `domain-ui-design-system.md`；Taro 小程序还必须读取 `knowledge/mini-program/README.md`、平台能力矩阵和相关接入契约。
5. **Contract-First UI 门禁（先读 SDK 真实契约再画图/生成 Preview）**：凡涉及登录、注册、第三方 OAuth 回调、支付收银台、账号注销或权限门禁的 UI 设计与 Figma 状态稿，必须先核对消费项目锁定的 `fenleng-client-sdk` 与 `fenleng-shared-platform` 真实接口字段及平台最新文档（如注册是否返回原子 `TokenPair`、Web 微信回调是否采用跳转前 `sessionStorage` 绑定 OAuth `state` 无感登录、抖音小程序是否采用通用交易系统 3.0 `requestOrder`/`getOrderPayment`）。若 MVP 体验高于当前 SDK 契约，必须在 `WP01` 直接触发同机跨仓升级或标记决策点，严禁先按臆测或降级妥协画图、待编码阶段发现不匹配后再多次返工重绘 Figma。
6. 先输出页面目标、信息层级、组件状态、主题 Token 和未决人类决策点，再实现或修改内容。
7. 对所有适用状态进行验收：默认、加载、空、错误、成功、禁用、权限不足和主题切换。
   主题验收必须覆盖：显式浅色、显式深色、跟随系统，以及固定暗色主题身份（如“深夜工作”）；显式模式优先于系统模式，固定暗色身份不得渲染为浅色。文字验收必须覆盖系统缩放、标准、大字版、超大字版和窄屏。
8. 完成后报告使用的规范资产、验证结果、视觉风险和剩余决策。

## Project Knowledge 读取协议

当基座仓库不是当前工作目录时，通过 `fenleng-project-knowledge` MCP 读取项目 `fenlengtechbase` 的以下路径：

- `knowledge/design-system/README.md`
- `knowledge/design-system/principles.md`
- `knowledge/design-system/typography.md`
- `knowledge/design-system/layout.md`
- `knowledge/design-system/interaction.md`
- `knowledge/design-system/tokens.json`
- `knowledge/design-system/theme-contract.md`
- `knowledge/design-system/component-catalog.yaml`
- `knowledge/design-system/content.md`
- `knowledge/design-system/data-display.md`
- `knowledge/design-system/accessibility.md`
- `knowledge/design-system/ai-generation.md`
- `knowledge/mini-program/README.md`（Taro 小程序任务）
- `knowledge/mini-program/platform-capability-matrix.json`（Taro 小程序任务）

如果 MCP 不可用，必须明确说明规范无法验证，不得伪造已加载基座规范；可以继续做结构性分析，但不得声称完成视觉合规。

## 成功标准

- UI 方案使用语义 Token 和已登记组件；
- 主题切换不改变业务状态和页面结构；
- 适用的状态和可访问性行为已覆盖；
- 视觉结果可通过人工截图或组件预览验收；
- 所有未确定的品牌或产品决策都被明确列出。

## 失败处理

- 缺少目标端规则：停止实现并要求确认端侧技术栈；
- 缺少品牌决策：标记 `humanDecisionRequired`，不自行发明 Token；
- Token、主题或组件 Schema 校验失败：停止声称完成，先修复资产；
- 无法读取 Project Knowledge：报告证据缺失和具体路径，不把通用 UI 经验当作 Fenleng 规范。

## 必须读取

- `references/knowledge-loading.md`
- `references/visual-review.md`
- `assets/token.schema.json`
- `assets/component.schema.json`
