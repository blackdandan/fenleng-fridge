# Experience Manifest SDK Routing

当业务项目包含 Fenleng Experience Manifest 时，目标端与能力声明是 SDK 选择的唯一输入。使用 `adapters/sdk/experience-sdk-bindings.js` 的同等确定性映射：

| `targetPlatform` | 官方包 |
|---|---|
| `web` | `@fenleng/sdk-web` |
| `flutter` | `fenleng_sdk_flutter` |
| `taro` | `@fenleng/sdk-taro` |

每个目标端始终启用 `core`、`telemetry` 和 `featureFlag`；`capabilities.identity.enabled`、`commerce.enabled`、`ai.enabled` 分别启用 `identity`、`commerce`、`ai`。App Shell 与 Trust 属于 UI/体验层，不得据此复制网络客户端。

约束：

- 不在业务项目手写 Shared Platform Auth、Commerce、Telemetry 或 AI Proxy HTTP/SSE 客户端。
- 不为 Manifest 未声明的 Identity、Commerce 或 AI 能力引入相应模块。
- 目标端不在 Schema 范围内时阻断，不猜测相邻 SDK。
- SDK 版本必须满足 Fenlengtechbase SDK Governance 与项目 Knowledge 中的兼容矩阵。
- Provider、生产 Endpoint、Secret 和生产授权不由路由逻辑自动选择。
