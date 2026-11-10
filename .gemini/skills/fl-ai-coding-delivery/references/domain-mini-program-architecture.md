# Taro 跨端小程序工程架构选型与规范

> 本文件是 Fenlengtech 小程序工程的唯一端侧选型。微信、支付宝和抖音统一使用 Taro、React、TypeScript 与 pnpm workspace，不允许业务项目另建并行技术栈。

## 1. Day-1 工程拓扑

```text
pnpm-workspace.yaml
package.json
apps/miniapp
packages/domain
packages/application
packages/api-client
packages/ui-kit
packages/platform-contracts
packages/platform-adapters/{weapp,alipay,tt}
```

MVP 只能裁剪 Feature 数量，不得降级为单包目录。`domain` 与 `application` 必须为不依赖 Taro、React 和平台全局对象的纯 TypeScript 包。

## 2. 依赖方向

- 页面和 UI 组件只渲染 Application State 并发送 User Action；
- `application` 编排用例、状态机和 Port，不调用平台 SDK；
- `domain` 只包含实体、值对象和业务规则；
- `api-client` 对齐正式服务端 Schema，不拥有领域真相；
- `platform-adapters` 实现 `platform-contracts`，禁止被 Domain 反向依赖；
- Feature 之间不得直接依赖，通过 Application Port 或路由契约协作。

## 3. 平台差异

`wx`、`my`、`tt`、Taro API、`process.env.TARO_ENV` 和平台条件文件只允许出现在 Adapter、应用组合根和平台配置中。禁止在 Feature、Domain、Application 或共享 UI 组件里散落平台判断。

所有能力先定义共享状态和结果，再实现平台 Adapter。平台缺失能力必须登记明确降级，不得静默成功或伪装成已支持。

## 4. UI 与 Design System

- `packages/ui-kit` 消费 Fenleng 小程序目标 Token，不直接复用 Web DOM 组件；
- Token 通过集中生成的 TypeScript/SCSS 目标产物映射，页面不得写 primitive 色值、任意间距或任意圆角；
- 组件职责和状态与 `component-catalog.yaml` 一致；
- 主题身份、明暗模式、Density 与文字缩放分别建模；
- 验收默认、加载、空、错误、成功、禁用、权限不足、窄屏、长中文和 Reduce Motion。

## 5. 身份、网络与平台能力

必须读取 `knowledge/mini-program/` 的身份、网络、安全、支付和认证契约。平台登录凭证只能提交给 Fenleng 后端换取统一 Session；页面不得使用平台用户标识作为业务账号，也不得保存 Secret。

## 6. 构建、测试与发布

- 锁定 Node、pnpm、Taro 和 `@tarojs/plugin-platform-weapp`、`@tarojs/plugin-platform-alipay`、`@tarojs/plugin-platform-tt` 平台插件版本；声明支持的平台必须显式安装对应插件；
- 每次变更至少运行类型检查、单元测试、架构边界检查和微信目标构建；
- 修改平台 Adapter 时增加对应支付宝/抖音构建和契约测试；
- 生产发布必须在平台开发者工具和真实设备完成应用级认证；
- `dist/`、平台私有配置、Secret 和调试日志不得作为源码提交。

## 7. 禁止事项

- 用 Web `<div>`/DOM 组件冒充小程序 UI Kit；
- 在页面调用登录、支付、存储或网络 SDK；
- 用条件编译复制整套 Feature；
- 把平台支付成功当作后端履约完成；
- 因 MVP、工期或单平台首发绕过 Monorepo、Adapter、状态和测试门禁。
