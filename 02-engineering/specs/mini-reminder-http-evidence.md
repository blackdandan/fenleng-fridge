# 微信提醒 HTTP 与周期调度阶段

承接已批准 WP06 与 Shared Platform/官方 SDK 联动授权。本阶段增加平台候选源码，不改 APK、小程序或官网产物，不运行生产迁移、部署或真实微信发送。WP06 与整体交付仍为 in-progress。

已接入配置查询、计划 PUT、原生许可观察、按计划查询发送状态，以及无会话取消。前四项在既有 SelfService bearer 边界内，同时要求 API 和 self-service 开关；撤销使用预先保存在客户端的随机能力凭据，在会话过期/清理后仍可调用。HTTP 返回最小 DTO、no-store，不返回 owner、OpenID、取消凭据和内部散列。跨账号查询统一404；取消限流复用平台已有实现。

增加可选周期调度与真实 Provider 工厂，复用既有服务端微信 MINI_PROGRAM_CODE 登记，按应用code/client精确匹配元数据模板映射，复用每App的token缓存。两项开关均默认关闭，只有实际开启调度并配置有效映射才报告configured=true。取消API不依赖调度开启。仅本地验收，没有发出微信公网消息。

附带修复：同一天已过时刻支持补发；新快照不接收历史自然日，但既有快照跨日重放仍是幂等确认。同内容提高revision不重置失败重试，fresh唯一原生accept观察允许用户重新发起有限重试，重复观察不重置。新的取消凭据仍共享同安装/用户/自然日发送槽，状态查询显示已发送槽而非隐藏它。

OpenAPI新增5项操作及mini-reminder.schema.json，契约验证与兼容检查通过；runtime变量由188增至190（Platform171/Edge19），Secret分类与Owner SSH/审批条件未变，runtime与release-engineering验证通过。具体命令、XML和最终源码哈希统一记录在../evidence/mini-reminder-http-results.json。

验证中首次Spring policy单测失败，原因是Mockito调用的Kotlin ApplicationId值类型参数及方法名已经被编译器展开；夹具按实际value/方法名前缀修正，未绕过生产匹配。初次失败日志保留，不作为通过证据。现有其他模块弃用/参数名警告保留。

后续仍需官方SDK的持久随机取消凭据与接口、Taro原生用户点击许可/库存日历同步、退出和隐私撤回撤销、消息deep link，以及客户端构建/运行验收。正式AppID、模板、域名和提供者验收由既有Owner待办承接；完整源码交付还需要完成本地SDK不可变版本收口。
