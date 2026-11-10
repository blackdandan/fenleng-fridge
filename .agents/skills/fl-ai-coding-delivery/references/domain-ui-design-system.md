# Fenleng UI Design System 工程规则

本文件是跨端 UI 工程实现的强制规则。完整视觉语义、Token 和组件职责以 Project Knowledge 的 `knowledge/design-system/` 为准。

## 通用规则

1. 页面只能依赖语义 Token 和已登记组件，不得散落具体颜色、间距、圆角或动效值。
2. 新组件必须先检查 `component-catalog.yaml`；确需新增时，先登记职责、状态、Token 家族和禁止行为。
3. 任何可交互页面必须覆盖适用的默认、加载、空、错误、成功、禁用和权限不足状态。
4. 主题切换只能改变主题映射，不得改变业务状态、路由、数据或权限。
5. 颜色不能成为传达状态的唯一方式；文本、图标、结构或动作反馈必须补充语义。
6. UI 组件只负责渲染和用户动作，不承担 HTTP、数据库、本地持久化或业务决策。
7. 视觉审查必须使用 `fl-ui-design-system` 的清单，并报告具体证据和未决的人类决策。

## Flutter

- 使用 `ThemeData` 和 `ThemeExtension` 承载 Fenleng 语义 Token；
- 主题 Provider/Controller 只负责主题状态和持久化，不承载业务用例；
- 业务 Feature 依赖 `packages/ui_kit` 或等价共享 UI 边界，不在 Feature 内复制基础组件；
- Widget 遵守 `$UI = f(State)`，不得在 Widget 中直接调用 API 或存储；
- 主题变体必须在根级 App Shell 注入，不能由页面各自创建平行 ThemeData。

## Web

- 使用集中 CSS variables 或等价主题适配层映射语义 Token；
- 组件必须提供键盘焦点、错误和禁用状态；
- 页面组件不得直接依赖 primitive 色值；
- 主题切换不得通过复制两套页面结构实现。

## Taro 跨端小程序

- 使用基座生成的 TypeScript Token Map 与 SCSS variables 映射语义 Token；
- 主题身份、明暗模式、Density 和文字缩放在 App 根部统一解析，页面不得各自创建主题；
- `packages/ui-kit` 是独立小程序实现，不直接导入 Web DOM 组件；组件职责和状态必须与 `component-catalog.yaml` 对齐；
- 安全区、导航栏、Tab Bar、授权弹窗和平台能力差异通过布局/平台 Adapter 处理，不得改变业务状态语义；
- 平台没有 hover 时必须提供 pressed/focus-visible 或等价反馈，关键操作必须有可见文字和足够触控目标；
- 默认、加载、空、错误、成功、禁用、权限不足、系统字体、large、extraLarge、Standard/Compact、窄屏和长中文均为发布门禁。

## 证据要求

工程交付摘要必须列出使用的主题、语义 Token、组件目录项和视觉验收结果。无法加载基座 Knowledge 时，不得声称 UI 已完成 Fenleng 规范合规。
