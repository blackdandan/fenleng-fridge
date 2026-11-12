# Shared Platform 接入核对

核对日期：2026-11-12。仅消费端产品定义，未修改上游仓库、登记真实应用或调用写接口。

## 证据来源
当前聊天原 MCP transport 已关闭，使用修复后插件的新 Node 进程调用相同 HybridProjectKnowledgeService，并显式提供本机 Roots；仍由 Manifest 根/拒绝路径约束读取。不是生产 smoke，也不是远程 HEAD 最新状态证明。

| 项目 | repository | resolvedCommit | sourceMode / 状态 |
|---|---|---|---|
| base | https://github.com/blackdandan/fenlengtechbase | 89a1617edbfd1595342b532c586e70b881098d45 | local；dirty=true（前轮 MCP 修复未提交） |
| Shared Platform | https://github.com/blackdandan/fenleng-shared-platform | 777c6ba4d87be940b3cc91d1167f173e5e25ef49 | local；dirty=false |
| Client SDK | https://github.com/blackdandan/fenleng-client-sdk | 334611afbd9ae4be95771159a5cd00dc6f0ba31f | local；dirty=false |

读取时间 2026-11-12 18:52–18:54（Asia/Shanghai）。具体 sources：
- base：`knowledge/organization/assets/工作室信息.md`（只提取运营主体、地址、对外邮箱电话；不复制账号或证件信息）；`knowledge/application-websites/README.md`、`application-website-integration-template.md`；`knowledge/design-system/` 入口、原则、布局、文字、交互、tokens、forest、AI与无障碍规范。
- Shared Platform：`docs/contracts/notification-feedback-contract.md`、`docs/contracts/v1/openapi/platform-api.json`、`docs/architecture/identity-data-dictionary.md`、`docs/spec/wp-patent-anonymous-telemetry.md`。
- SDK：`docs/spec/wp-patent-anonymous-telemetry.md`。补充只读代码核对 `packages/sdk-flutter/lib/src/notifications.dart`、`auth.dart`、`telemetry.dart`；源码核对不替代已公开契约。

追加远程核验：2026-11-12 19:00，Shared Platform `main` 解析到 `0ec42a11af95c0121784939d5cce80aa67c6d9ee`，repository同上；通过同一服务读取 `docs/contracts/v1/openapi/platform-api.json`，sourceMode=github，cacheHit=false。认证路径含密码、微信、Apple/Firebase、小程序及refresh等，仍无guest/anonymous用户会话创建路径，反馈路径存在。SDK远程 main 查询返回REF_NOT_FOUND（可能是权限或ref），故SDK结论只基于已注明的本地快照，不声称远程最新。

## 反馈：已有，消费端尚未接入
平台 `POST /api/platform/v1/feedback` / `submitUserFeedback`，要求 Idempotency-Key；全局认证边界适用，不能因没有密码输入页而匿名调用。响应201并返回受理ID/status。FlutterFeedbackSDK.submit 封装此接口，带 projectId/version/可选traceId。

本产品初版只提交文字；不增加截图/日志附件。平台已有附件显式同意和摘要30天过期规则，但这不是正文保留策略；本产品草案的180天反馈/90天分析保留期是待正式接入落实的要求，不声称平台已配置。应用登记、授权scope、生产路由和运营受理闭环仍须真实联调。原型显示本地模拟回执。

## 无账号密码登录：目标明确，上游能力不完整
按用户语境，将目标解释为无需输入账号密码、无需第三方交互的后台游客会话；不是强制微信登录，也不是客户端造账号密码。

平台数据字典与 UnifiedUser 中已有 GUEST，要求 originApplicationId。公开 OpenAPI 与 Flutter Auth SDK 核对发现账号密码、微信、Firebase/Apple等认证及 refresh/restore；未找到公开 guest/anonymous/device 会话创建端点，不能将领域模型存在当成游客登录已交付。

官网匿名 telemetry 端点明确不创建用户或session，仅Web使用。它不能为 App 反馈提供认证。正式游客会话应由 Shared Platform/官方 SDK 补齐契约与实现，应用隔离、重装身份边界和凭据恢复需一并验收；不在本轮擅自修改上游。

本轮可验收纯本地模拟体验；正式反馈与认证分析上线依赖游客会话能力，不能宣称已真实接入。无身份/断网时仍可用本机库存，反馈保留草稿后重试。

## 分析
事件源 `telemetry-events.json`，统一隐私同意前不采集；用户明确不需要独立分析开关。正式 App 使用 FlutterTelemetrySDK，官网按已登记 PUBLIC client/origin/scope 的 WebAnonymousTelemetrySDK；目录、白名单、渠道/版本上下文和平台登记缺一不能声称生产可用。当前原型不真实上报。

## 运营信息与备案
草案沿用组织资产的运营主体和公开联系方式。组织资产中现有网站备案信息不可推导为本 App 备案；本产品的 APP 号、官网域名及网站号待登记，预览明确占位，不借用其他应用或组织站点号码。
