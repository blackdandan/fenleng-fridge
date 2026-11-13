# 平台接入与能力差异

仅消费 Shared Platform 和官方 Client SDK。现有证据详见 [平台契约核查](../01-product/mvp/shared-platform-integration.md)，源文件已迁移至 `01-product/mvp/`。不在本产品复制账户、反馈、遥测后端。

| 能力 | 当前依据 | 工程处理 |
| --- | --- | --- |
| App 无感身份 | 有 GUEST 模型及会话恢复；公开创建游客会话的入口尚未确认 | 初始化真实接入前核实契约；失败不阻断本地库存，反馈保留草稿，不伪造会话 |
| 微信身份 | 平台有小程序 code 换统一会话能力 | 以微信 AppID 对应的实际接口、官方 SDK 和应用隔离配置为准；不假定用户已授权手机号 |
| 反馈 | `POST /api/platform/v1/feedback`，认证及 `Idempotency-Key` | 官方 SDK；重复点击合并，失败保留草稿，重试沿用标识，响应确认才报成功 |
| 遥测 | 官方 Client SDK | 事件白名单、统一同意门禁、应用/版本/端/渠道上下文；队列最多 100，单批最多 50，有限重试 |
| 照片/库存 | 本地业务数据 | App 使用本地持久化；微信验证文件留存和容量；不新增 OSS、bytea 或云端备份 |
| 检查提醒 | 共享周期与待处理状态 | App 三端本地通知适配；微信外部提醒另核能力，不以后台定时器冒充可达通知 |
| 官网 | 静态内容与协议 | 不建立业务会话；匿名遥测不能用于 App 登录 |

权限使用端侧统一适配层；Android 优先核对官方 `fenleng_sdk_flutter_china_permissions` 接入，禁止页面散落直接权限调用。HarmonyOS 插件、通知、存储能力必须实测，不因 Dart 代码可编译而声明三端通过。

现有远程缓存证据：base repository `https://github.com/blackdandan/fenlengtechbase`，resolvedCommit `069718f51642df16e5c80c757943ce03621fd4a0`；Shared Platform repository `https://github.com/blackdandan/fenleng-shared-platform`，resolvedCommit `0ec42a11af95c0121784939d5cce80aa67c6d9ee`；source `@git-tree`，sourceMode `cache`，查询日期 2026-11-13。搜索结果有截断，不能以未命中证明不存在游客 API；SDK 远程读取遇到 REF_NOT_FOUND，现有本地快照与具体文件证据保留在上游核查文档中。正式编码重新锁定真实契约与依赖版本。

Owner 于 2026-11-13 已授权必要的 Shared Platform/官方 SDK 联动补齐并登记变更；仍须先核对具体契约，不在产品另建后端，不擅自部署上游。中央矩阵条目源位于 `00-context/registry-entry.json`，已依据 Owner 确认写入本地基座 `knowledge/project-matrix/projects.json`，尚未提交推送。
