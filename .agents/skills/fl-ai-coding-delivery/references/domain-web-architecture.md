# React + Vite Web 前端工程架构选型与规范

> 本文件是 Fenlengtechbase 体系中 Web 前端 (Web Apps & Admin Portals) 的核心工程选型与架构规范。

面向用户的 Web 若包含账号能力，必须从首版遵守 [`day0-account-channel-i18n.md`](day0-account-channel-i18n.md) 的邮箱验证、7 天注销、标准字符串目录和中国/全球渠道隔离规则。所有 Web 同时遵守 [`day0-telemetry.md`](day0-telemetry.md)，不另建平行采集通道。

## 1. 工程拓扑选型 (pnpm workspace Monorepo)

Web 前端统一选定 **React + Vite + TypeScript** 选型，必须采用 **pnpm workspace Monorepo** 多包管理拓扑：

- `pnpm-workspace.yaml` & `package.json`
- `packages/ui`：独立解耦的 UI 组件库与主题 Style Token
- `packages/api`：数据类型与 API Hook / Client 隔离包
- `apps/web` / `apps/admin`：具体的独立前端应用

---

## 2. 模块隔离与组件规范

1. **组件化隔离**：
   - 业务页面 (Pages/Views) 负责路由与 State 绑定。
   - 展现组件 (Presentation Components) 必须抽取至 `packages/ui` 或本地 `components/`，禁止产生上万行的单文件巨型 App 组件。
2. **API 与状态分离**：
   - 数据 Fetching 与 API 逻辑必须封装在 `packages/api` 或 React Custom Hooks 中，视图层禁止硬编码 `fetch` 或 `axios` 调用。
