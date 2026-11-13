# mini-program

Taro + React + TypeScript + pnpm workspace，首版仅微信 weapp。

实现位于 apps/miniapp 与领域、应用、UI kit、平台契约、API client、微信 Adapter 六类 packages。遵循 [coding-guide](../../02-engineering/coding-guide.md) 与 [architecture](../../02-engineering/architecture.md)。支持本机库存/拍摄入库/整理与撤销/详情编辑/历史恢复/显示偏好/法律阅读及反馈草稿；游客与可选微信登录通过官方 SDK 接 Shared Platform。

在本目录运行 pnpm install --offline、pnpm typecheck、pnpm check:boundaries、pnpm build:weapp；编译结果在 apps/miniapp/dist。单测为 pnpm exec tsx --test packages/*/test/*.test.ts packages/platform-adapters/weapp/test/*.test.ts。

身份默认关闭。正式 AppID、request 合法域名、平台应用/客户端/游客角色及订阅模板需要后补，见 [配置交接](../../03-deployment/identity-configuration.md)。SDK 当前使用带 SHA256 和逐文件来源记录的本地候选 tgz（vendor/provenance.json），未发布固定新 Git commit；原基线包仍保留。

构建和测试不代表微信开发者工具或真机验收。视觉状态见 [Figma实施索引](../../02-engineering/mini-program/figma-map.md)，反馈阶段见 [接入证据](../../02-engineering/mini-program/pages/feedback-identity.md)。未上传或发布小程序；退出后的订阅消息闭环仍在后续范围。

法律默认通过独立原生页面的WebView访问正式站；FRIDGE_LEGAL_WEB_ENABLED=false仅供明确选择的开发离线正文预览。必须后补正式业务域名配置与网站部署，不能用开发fallback替代正式WebView。统一撤回含确认、旧会话封闭、持久pending恢复与失败重试；实现和验证范围见 [撤回证据](../../02-engineering/mini-program/pages/privacy-withdrawal.md)。

提醒SDK与微信Adapter已接入本地候选包，支持持久计划/取消能力和原生许可调用；尚未接到业务UI/OnlineRuntime，不能认为退出后的提醒已闭环。阶段证据见[mini-reminder-sdk-evidence](../../02-engineering/specs/mini-reminder-sdk-evidence.md)。

后续客户端阶段已接入业务UI/OnlineRuntime、库存日历、账号退出/切换及隐私撤回取消与消息回跳。91项测试、20语言171key、类型/边界/weapp构建通过；阶段范围与原生待验事项见[subscription-reminders](../../02-engineering/mini-program/pages/subscription-reminders.md)。上段“未接UI”为历史阶段；真实微信送达仍须正式配置与主机验收。
