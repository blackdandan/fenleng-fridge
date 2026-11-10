---
name: fl-ux-pro
description: "在 Fenleng UI、Figma 视觉生成、页面重设计和 UX 审查中建立可解释的产品结构与视觉系统决策，并将产品类型、布局、Typography/Density Profile、组件状态和端侧策略映射到 Fenleng Design System。"
---

# fl-ux-pro

为 Fenleng 的 UI/UX 任务提供系统化的视觉方向、信息架构和体验决策。它是 `fl-ui-design-system` 的决策增强层，不替代 Fenleng Design System 的 Token、主题、组件、可访问性或端侧工程契约。

## 适用边界

方法来源：[UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)。完整离线数据与 BM25/设计系统生成引擎封装在 `assets/upstream.json.gz`，由 `scripts/search.py` 调用。固定版本与 MIT 授权见 `references/provenance.md` 和 `references/upstream-license.txt`。无需网络或第三方 Python 包。

- 设计新页面、完整流程、Figma Prompt、视觉 preview 或产品级视觉方向时使用。
- 进行页面重设计、UX 质量审查、布局/密度/字体/颜色策略选择时使用。
- 业务页面的代码实现仍由对应端侧工程 Skill 负责；Figma 节点到 Flutter 代码的逐块还原使用 `fl-figma-map-ui-loop`。
- 纯后端、数据库、API、非视觉性能优化和没有 UI 影响的脚本不使用本 Skill。
- `fl-ui-design-system` 是最高视觉规范；不能用本 Skill 的推荐覆盖已确认的 Fenleng Token、主题身份、页面 Profile、组件契约或无障碍要求。

## 必须先读取的规范

在当前仓库中直接读取：

1. `knowledge/design-system/README.md` 和 `knowledge/design-system/principles.md`；
2. `knowledge/design-system/ai-generation.md`；
3. 按任务读取 `typography.md`、`layout.md`、`interaction.md`、`content.md`、`data-display.md`、`accessibility.md`；
4. 涉及实现或换肤时读取 `tokens.json`、`theme-contract.md`、`component-catalog.yaml` 和 `page-theme-contract.yaml`；
5. 任何 UI 交付前读取 `skills/fl-ui-design-system/references/visual-review.md`。

如果当前不在 Fenlengtechbase，按 `skills/fl-ui-design-system/references/knowledge-loading.md` 通过 Project Knowledge MCP 读取同一组资产。无法读取时，报告证据缺失，不得把外部通用设计建议称为 Fenleng 合规结果。

## 输入

用户任务、现有页面/参考资料、目标端及可读取的 Fenleng Design System；现有内容与品牌约束优先作为检索和映射条件。

## 执行步骤

### 1. 识别任务与产品语境

先确定：

- 目标端：Flutter、Web、Taro 小程序或其他；
- 任务类型：新设计、重设计、实现、Figma 生成、审查或换肤；
- 页面/流程目标、目标用户、主任务和唯一主操作；
- 产品类型：工具、工作区、内容、营销、数据、设置、身份确认或其他；
- 已有品牌资产、参考图、同类产品和必须保留的组件。

如果任务涉及新页面或系统级视觉方向，先写一行 `Design Read`：

> 将其理解为：`<页面/流程类型>` 面向 `<用户和场景>`，采用 `<气质>`，重点优化 `<主任务和体验结果>`。

只有当两种合理方向会导致不同的信息架构或视觉系统时才提出一个澄清问题；否则基于现有证据继续，并把不确定项标为 `humanDecisionRequired`。

### 2. 检索设计依据，再建立 Fenleng 决策

读取 `references/search-and-mapping.md`。定位当前宿主安装的本 Skill 目录，以绝对路径运行 `scripts/search.py`。中文需求先提取 2–5 个英文意图关键词，不把整段需求作为查询。

- 新页面：运行 `python <skill-dir>/scripts/search.py "document scanner productivity" --design-system --json`，换成实际产品类别。检查 `source_identities`、`reasoning_default` 和类别是否吻合。
- 局部问题：使用 `--domain ux`、`chart`、`typography`、`style` 等显式领域；已知栈另跑 `--stack flutter` 或实际栈。
- 每条检索记录查询、来源和采纳/拒绝原因。无匹配或不相关时只窄化重试一次；仍失败则明确标注没有匹配，不能伪造检索证据。
- 生成器的 landing pattern 是营销结构候选，不能用于覆盖应用工作区、编辑器或业务流程。以当前页面目标筛选。
- 输出中的颜色、字体、间距和动效是候选建议；完成下面的语义映射后才用于页面。禁止直接生成第二套 MASTER/page override 规范，入口会拒绝上游持久化参数。

先使用既有规范和组件，再做新决策：

1. 选择 `page-theme-contract.yaml` 中的页面 Profile；
2. 声明 Typography profile 和 Density profile，移动端至少说明 `Standard` 或 `Compact`；
3. 从 `component-catalog.yaml` 选择组件，并列出 default、loading、empty、error、success、disabled、permission-denied 等适用状态；
4. 使用语义 Token 和主题映射，不在页面中生成裸十六进制颜色、任意间距、任意圆角、页面私有字号或新的动效常量；
5. 若产品品牌或核心 CTA 没有确认，不替用户发明品牌 Token；输出 `humanDecisionRequired`。

### 3. 选择视觉方向，而不是套模板

视觉方向必须说明“为什么适合当前产品”，至少包含：

- 页面构图和首屏焦点；
- 信息层级、内容密度和分组节奏；
- 主操作与次操作的对比关系；
- 表面层级、边界和留白策略；
- 图片、插图、图标或数据可视化的职责；
- 主题、Typography、Density 和响应式重排的映射；
- 哪些常见模板化选择被拒绝，以及拒绝理由。

不要默认使用居中 Hero、三张等宽卡片、满屏玻璃、紫蓝渐变、无意义阴影、所有元素同样圆角或装饰性动效。只有当产品语境、参考资产和 Fenleng Token 共同支持时才采用；不得用装饰掩盖信息架构问题。

### 4. 端侧与状态设计

对每个页面或核心组件给出：

- 桌面/平板/移动端的结构重排，而不是全局缩小；
- 长中文、动态字体、窄屏、键盘和辅助技术下的文本行为；
- 默认、加载、空、错误、成功、禁用和权限不足状态；
- 操作反馈、焦点回收、错误恢复和 Reduce Motion 行为；
- 列表、表格、搜索、筛选、仪表盘或编辑工作区的对应模式。

数据页面必须保留单位、时间范围、更新时间和异常解释；图表不得只靠颜色传达系列或状态。危险操作不得与主保存动作混淆。

### 5. Figma、Preview 与实现交接

如果输出给 Figma 或视觉 preview，按单端边界组织：页面清单、组件清单、状态、视觉方向、禁止项、响应式和验收标准必须独立可交接，并遵守 `fl-mvp-definition/assets/prd/figma-prompt.md.template` 的版本化 Prompt 契约。

进入 Figma 写入路径前，必须先执行 **Contract-First UI 门禁**：核对项目中锁定的 `fenleng-client-sdk` 与 `fenleng-shared-platform` 认证/注册/支付/注销契约（如邮箱验证码注册返回原子 Session、Web 微信跳转前 `sessionStorage` 绑定 `state` 无感回调、三端小程序支付载荷），确保 Figma 状态节点与真实 SDK 契约 1:1 吻合，避免编码阶段因契约不一致返工重画 Figma。先完成结构、组件、Token 和状态决策，再由 Figma 工具执行；不要用 Figma 图层数量代替设计系统证据。

如果进入 Flutter Figma 还原路径，交给 `fl-figma-map-ui-loop` 建立 node-id、spec、widget 和数字化保真证据映射。

### 6. 视觉验收

按 `skills/fl-ui-design-system/references/visual-review.md` 输出：

- `pass`：有规范资产和截图/预览证据支撑；
- `needs-change`：存在具体页面、组件、状态或 Token 问题；
- `humanDecisionRequired`：产品品牌、主操作、参考风格或范围仍需 Owner 决定。

不得以“看起来不错”替代证据。至少检查首屏目的、唯一主操作、层级、密度、状态、主题、长文案、窄屏、可访问性和动效克制。

## 输出

完成设计或审查时至少输出：

1. `designRead`：产品语境、用户、主任务和视觉方向；
2. `surfaceProfile`：目标端、页面 Profile、Typography/Density Profile 和主题；
3. `hierarchy`：页面结构、首屏焦点、主/次操作和内容密度；
4. `componentsAndStates`：组件目录项与状态覆盖；
5. `tokenEvidence`：检索来源、候选值到既有 Token/主题/组件的映射，以及拒绝项；
6. `responsiveAndA11y`：端侧重排、动态字体、输入方式、对比度和 Reduce Motion；
7. `visualReview`：`pass`、`needs-change` 或 `humanDecisionRequired` 及具体证据。

## 完成标准

实际检索来源可追溯，候选设计映射到已有主题/组件；目标页面覆盖适用状态，并具备与交付范围相称的截图/操作证据。仅完成规范检查时不能声称视觉通过。

## 失败处理

- 目标端不明确：停止实现，先确认端侧技术栈。
- Design System Knowledge 不可读：继续只能做结构性分析，并显式标记规范证据缺失。
- 缺少品牌、核心 CTA 或内容优先级：标记 `humanDecisionRequired`，不自行生成 Token。
- 组件目录没有合适组件：说明复用失败原因、状态集合和新增组件边界，不能直接复制局部基础组件。
- 视觉方向与 Fenleng 规范冲突：保留产品目标，调整方向以服从 Token、主题、组件、可访问性和反馈契约。
