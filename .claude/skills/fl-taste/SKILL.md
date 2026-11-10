---
name: fl-taste
description: "在 Fenleng UI、Figma 设计、视觉 preview 和页面重设计中提升审美质量，抑制 AI 模板化与 slop，建立有证据的 Design Read、构图变化度、动效强度和视觉密度，同时服从 Fenleng Token、主题、组件、可访问性和端侧视觉契约。"
---

# fl-taste

为 Fenleng UI 任务提供审美校准和反模板化约束。它解决“功能完整但设计很丑、很普通、很像 AI 生成”的问题；它不是自由发挥的品牌 Skill，也不是 Figma 写入工具。

## 适用边界

- 用户说“太丑、太普通、没有设计感、AI 味重、想高级/独特/有质感”时使用。
- 新页面需要明确视觉方向、已有页面需要重设计、Figma 稿需要审美审查时使用。
- 仅做 Token、主题、组件状态或可访问性合规检查时，不单独使用本 Skill，由 `fl-ui-design-system` 负责。
- 不得用审美偏好覆盖产品目标、信息层级、已确认品牌、语义 Token、主题契约、组件目录、状态覆盖或可访问性基线。

## 规范基线

方法来源：[Taste Skill](https://github.com/Leonxlnx/taste-skill)。本适配版吸收其审美旋钮、反模板化和重设计方法，具体视觉值以 Fenleng Design System 为准。

固定来源和授权见 `references/provenance.md`、`references/upstream-license.txt`。设计或重设计前读取 `references/design-methods.md`，其中包含具体构图选择、排版校准、素材策略及验收方式。上游主 Skill 主要面向营销页/作品集；密集工作区和原生 App 只借用适用的排版与审查方法，结构交给 `fl-ux-pro` 和端侧规范。

在接入项目中，将 `skills/fl-ui-design-system/references/knowledge-loading.md` 定位到宿主已安装的同名 Skill 目录，通过 Project Knowledge MCP 读取以下规范；下文 `knowledge/` 路径指基座知识路径，不假定业务仓库有同名文件。

先读取：

1. `knowledge/design-system/README.md`、`principles.md` 和 `ai-generation.md`；
2. 当前任务相关的 `typography.md`、`layout.md`、`interaction.md`、`content.md`、`data-display.md`、`accessibility.md`；
3. 涉及实现或换肤时的 `tokens.json`、`theme-contract.md`、`page-theme-contract.yaml` 和 `component-catalog.yaml`；
4. 最终使用 `skills/fl-ui-design-system/references/visual-review.md` 验收。

`fl-ui-design-system` 是规则的上限和底线，`fl-ux-pro` 是系统化结构与产品 UX 的互补层；本 Skill 只负责审美方向、变化度和反模板化判断。

## 输入

用户审美目标、页面/预览/Figma 证据、现有内容和品牌约束，以及当前 Fenleng 主题和组件规范。

## 执行步骤

### 1. 先读语境，再谈好看

先输出一行 `Design Read`：

> 将其理解为：`<页面类型>` 面向 `<用户和场景>`，采用 `<视觉语言>`，重点实现 `<体验结果>`。

至少检查：

- 页面类型：工具、工作区、后台、内容、营销、作品集、身份确认或其他；
- 用户和场景：扫描、决策、创作、购买、阅读、配置或协作；
- 参考信号：用户给出的截图、URL、品牌、竞品或现有页面；
- 已有资产：Logo、摄影、插图、字体、主题和组件；
- 约束：监管、信任、无障碍、低端设备、动态字体或平台规范。

如果语境确实存在两个以上不同方向，只问一个最能改变结果的问题；否则不要用追问代替判断。

### 2. 设置三个审美旋钮

用以下字段记录判断，不把它们变成新的 Token：

- `DESIGN_VARIANCE`：1–10，控制构图的对称/非对称、节奏和视觉个性；
- `MOTION_INTENSITY`：1–10，控制动效是否静态、微反馈或页面级过渡；
- `VISUAL_DENSITY`：由 Fenleng 的 `Standard` 或 `Compact` Density Profile 决定，不得用旋钮绕过移动端密度契约。

默认值不是固定答案：

| 语境 | Variance | Motion | Density |
| --- | ---: | ---: | --- |
| 清晰工具、设置、公共服务、强无障碍 | 3–4 | 1–3 | Standard 或 Compact，按页面 Profile |
| 专业工作区、数据、编辑器 | 4–7 | 2–5 | Compact 仅在内容确实密集且触控仍合规时使用 |
| 品牌首页、作品集、创意产品 | 7–9 | 4–7 | Standard |
| 实验性营销或创意展示 | 8–10 | 6–8 | Standard |

旋钮只改变构图、动效目的和视觉节奏，不改变信息优先级、业务状态、触控最小尺寸、字体缩放、语义 Token 或组件职责。动效必须映射到 Fenleng `duration.*`、`easing.*` 和 Reduce Motion 规则。

### 3. 执行 anti-slop 检查

除非产品语境、参考资料和 Owner 决策明确支持，否则禁止把以下内容当作默认视觉语言：

- AI 紫色/粉色渐变、深色网格背景和无语义光晕；
- 居中大 Hero 加三个等宽功能卡片；
- 所有东西都做成胶囊、白卡、玻璃或同一圆角；
- 以阴影、渐变、玻璃和动效掩盖信息架构问题；
- 用 emoji 或临时字符充当产品图标；
- 复制竞品风格但没有产品理由；
- 用一套字号、颜色或间距表达所有层级；
- 为了“高级”压低对比度、缩小正文或隐藏必要状态；
- 用装饰性动效制造热闹感，却没有因果、空间或进度含义。

反模板化不等于强行非对称。每一次变化必须回答：它服务了哪个用户任务、层级或品牌记忆点？回答不了就删除。

### 4. 建立可执行的视觉方向

输出一份短的审美决策：

- 一个主构图命题和一个首屏焦点；
- 一个主视觉语言及其适用范围；
- 颜色、字体、表面、图像和图标如何映射到 Fenleng 主题和组件；
- 哪些区域允许有表现力，哪些区域必须克制；
- 变化度、动效强度和 Density Profile；
- 被拒绝的默认模板及理由；
- 页面必须保留的加载、空、错误、成功、禁用和权限状态。

不要把外部 Skill 的颜色、字号、间距或圆角原样带入 Fenleng。外部资料只能提供方向词、模式或检查问题，最终值必须来自当前 Design System。

### 5. 重设计审查

已有页面先审查再修改：

1. 找出最影响观感的三个问题，按结构、层级、密度、字体、颜色、状态和装饰分类；
2. 先修首屏目的、主操作和信息层级，再修表面装饰；
3. 保留仍然有效的内容、组件和用户路径，不为换风格而破坏业务；
4. 用截图或可运行 preview 比较修改前后；
5. 最多保留少量有证据的个性化偏离，并登记 `humanDecisionRequired`。

### 6. Figma 与 Fenleng 视觉闭环

如果任务涉及 Figma：

- 先形成审美决策，再让 Figma 工具创建或修改画布；
- 使用现有组件、变量、主题和页面 Profile，不用裸图层堆叠模拟系统；
- 视觉方向必须写入 Figma Prompt 的 `Visual Direction`、`Do Not Include` 和验收部分；
- 读取已有稿时以截图、节点结构和变量证据为准，不凭页面名称猜风格；
- Flutter 还原任务交给 `fl-figma-map-ui-loop` 做 node-id、数字化保真、golden 和真机门禁。

## 输出

每次设计、重设计或审美审查至少输出：

- `designRead`；
- `tasteDials`：Variance、Motion 和 Fenleng Density Profile；
- `compositionThesis`；
- `antiSlopDecisions`：拒绝了哪些默认模板，理由是什么；
- `fenlengMapping`：主题、语义 Token、Typography、组件和状态；
- `responsiveAndA11y`；
- `visualReview`：`pass`、`needs-change` 或 `humanDecisionRequired`。

## 完成标准

构图、排版、素材和动效决策有产品理由；重设计保留有效内容及主路径。实际渲染与适用状态检查通过，问题有修正后的证据；未执行的视觉检查保持待验收。

## 失败处理

- 没有产品语境或参考信号：可以输出保守方向，但必须标记视觉决策不足，不声称完成品牌设计。
- 审美方向与 Fenleng 规范冲突：保留体验目标，降低表现性或改用合法 Token/组件。
- 只剩装饰性改动而结构问题未解决：停止堆叠装饰，先回到信息层级和主路径。
- 无截图、预览或节点证据：只能做方案审查，不能声称视觉结果已经验收。
- 需要新增品牌 Token、主题身份或基础组件：标记 `humanDecisionRequired`，不自行扩展契约。
