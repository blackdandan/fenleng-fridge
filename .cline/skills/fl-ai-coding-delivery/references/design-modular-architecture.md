# 多端工程 Day 1 多模块拓扑与解耦准则

> 本文件是 Fenlengtechbase 体系中针对多端工程模块化管理、依赖解耦与 Day 1 多模块拓扑的通用设计准则。

---

## 1. Day 1 物理级多模块拓扑法则

工程严禁采用无结构的单目录混杂代码。**即使最开始只有一个业务功能，工程在初始化 (Day 1) 时也必须设计为标准的工业级多模块拓扑**：

- **Flutter 移动端**：统一覆盖 iOS App 与 Android App，使用 **Melos (Monorepo)** 多包形态 (`packages/core`, `packages/ui_kit`, `packages/features/feature_*`, `packages/navigation` 路由桥)；
- **后端 (Backend)**：统一使用 **DDD 限界上下文 / 模块化单体 (Modular Monolith)**；
- **Web 前端 (React + Vite)**：统一使用 **pnpm workspace Monorepo** (`packages/ui`, `packages/api`, `apps/*`)。
- **跨端小程序 (Taro + React + TypeScript)**：统一使用 **pnpm workspace Monorepo** (`packages/domain`, `packages/application`, `packages/api-client`, `packages/ui-kit`, `packages/platform-contracts`, `packages/platform-adapters/*`, `apps/miniapp`)；微信、支付宝和抖音差异只进入 Adapter。

---

## 2. 单向依赖图 (DAG) 与路由桥解耦

1. **严格向下依赖**：
   - Feature 业务模块只能向下依赖底层 `core` 和 `ui_kit` 模块。
2. **模块绝对隔离**：
   - Feature 模块之间**绝对禁止直接产生依赖或循环引用**。
3. **路由桥依赖倒置**：
   - 若 Feature A 需要与 Feature B 通信或跳转，必须通过全局 App 宿主提供的统一消息总线或路由桥 (Router Bridge) 进行依赖倒置通信。
