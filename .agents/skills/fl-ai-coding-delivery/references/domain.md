# Domain-Specific Coder Rules Map (领域开发规则地图索引)

本文件是 Fenlengtech 自有项目矩阵各特定技术领域开发规约的权威入口。这里的技术栈不是外部项目兼容建议，而是 Fenlengtech 自有工程的强制工程选型；新建、重构或维护 Fenlengtech 项目时，不得替换技术栈、降级为单目录结构，或绕过已声明的分层与模块边界。

开发 Agent 必须先识别当前任务涉及的项目类型，再按条件加载本 Skill 的对应 reference。未命中特定端侧规则时，仍必须遵守 `design-clean-architecture.md`、`design-modular-architecture.md`、`engineering-clean-code.md` 和 `testing-mocking-rules.md`。

---

## Fenlengtech 端侧工程强制映射

| 项目类型 / 识别信号 | 必读规则文件 |
| :--- | :--- |
| Flutter 移动端，包含 iOS App 与 Android App；存在 `melos.yaml`、Flutter `pubspec.yaml` 或 `packages/features/feature_*` | `domain-flutter-architecture.md` |
| Kotlin / Java 后端服务；存在 `:gateway-service`、`:service-*`、Spring Boot、Ktor、gRPC 服务或后端 DDD 模块 | `domain-backend-architecture.md` |
| React + Vite Web / Admin；存在 `pnpm-workspace.yaml`、`vite.config.*`、`apps/web` 或 `apps/admin` | `domain-web-architecture.md` |
| Taro 跨端小程序；存在 `config/index.ts`、`app.config.ts`、`@tarojs/taro`、`apps/miniapp` 或 `platform-adapters/weapp` | `domain-mini-program-architecture.md` |

如果 Work Package 涉及 UI 设计、页面实现、组件、视觉审查、主题或换肤，额外读取 `domain-ui-design-system.md`；它与上面的端侧架构规则同时生效，不替代端侧架构规则。

## 条件加载门禁

1. 静态匹配：只允许根据当前 Work Package 的真实职责和仓库信号加载匹配的端侧规则。
2. 禁止闲读：禁止无目的、习惯性地一次性加载全套领域规则。
3. 强制执行：一旦命中某个 Fenlengtech 端侧类型，其规则就是交付审查门禁，不得作为可选建议处理。
4. Android App 统一归入 Flutter 移动端规则，不建立原生 Android App 工程规则或 Compose App 选型。
5. 小程序统一归入 Taro 跨端规则；微信、支付宝和抖音的差异由平台 Adapter 承担，不建立三套业务工程规则。
6. 已有项目维护：即使维护已有 Fenlengtech 项目，也不得通过“局部小改”引入违反目标技术栈、分层或模块边界的新代码；历史债务只能在当前边界内隔离，并在需要时登记。
