# 微信提醒 SDK 与微信 Adapter 阶段

承接已批准 WP06 和平台/SDK 联动范围。在 main 的本地 SDK 候选增加 TaroMiniReminderSDK/TaroMiniReminderPlan，未提交、推送或部署。消费本轮新命名 tgz，保留原 Git archive 与上一候选；来源/逐文件哈希见06-project/mini-program/vendor/provenance.json。

SDK覆盖配置/计划/观察/状态/撤销5项接口。单所有者协调器在PUT前保存32字节随机取消能力、安装标识和不可变快照/revision；相同快照和响应不确定重试复用同一版本。许可观察outbox先持久保存grantId，再POST，ACK后落盘失败继续复用原grantId，不虚增许可。取消同步阻止后续队列写入，保存cancelling后调用无JWT撤销，只有服务端ACK且本机提交成功才清除能力；重启遇待取消状态不创建新计划。

TaroPlatformClient新增authentication:none路径，完全跳过认证存储并删除大小写形式的Authorization；测试验证认证存储封闭后仍能取消。只有最小日期/时间/数量进入请求，不发送食材/照片/ID/OpenID。响应验证保留ACCEPTED与UNCONFIRMED差别，许可计数只是client-observation，不能宣称微信核验配额或已读。

消费端新增API-client工厂和微信Adapter。能力存储使用fridge.reminders.v1:plan，独立于fridge.platform.v1认证键；复用现有token，不隐式登录。随机源使用Taro.getRandomValues，订阅调用直接发生于点击所在调用栈，之前没有await。Taro4.3.2声明误将支付宝entityIds同时设为必填，微信端仅对该调用进行类型收窄，实际仅发送tmplIds；未额外加入支付宝字段。Adapter目前尚未接入OnlineRuntime/设置按钮，因此不能宣称小程序完整提醒闭环。

平台候选契约单独冻结为SDK contract/fridge-mini-reminder-candidate.json（带平台基线及OpenAPI/schema SHA），4项契约测试包含新5路由和请求字段一致性。没有把该候选覆盖成SDK已发布1.8.0的生成目录。

发现并修复既有Windows构建检查问题：Git把契约JSON转成CRLF，生成器以原字节计算SHA/逐字比较生成文件导致未改代码也报stale。现按LF规范化输入/比较，维持Git原始契约SHA及126项已发布操作不变；跨换行测试通过。

验证：Taro SDK55项、契约4项共59项通过；小程序完整74项通过；tsc、层边界、weapp构建、候选archive/安装后逐文件校验通过。common.js401KiB及无异步chunk为已有性能警告，不记为构建失败。首次消费者全集命令被pnpm PowerShell包装器合成单个路径，实际未运行；改为4个明确glob后74项全通过。首次Taro Option类型错误也已修正后重跑类型检查。日志/哈希/审计集中在../evidence/mini-reminder-sdk-results.json。

尚待接入：本机库存→自然日计划、前台预备配置/计划、真实订阅按钮、账号切换/退出及隐私撤回（含启动恢复）的撤销、回跳整理页、许可/同步/撤销失败提示及20语言。需要遵守现有同意门禁和单所有者生命周期。正式AppID/模板/域名、官方SDK固定完整Git commit及微信主机验证仍为既有交付事项。本阶段未更换APK或操作Owner正在查看的模拟器。

API来源：[Taro随机数](https://docs.taro.zone/en/docs/apis/base/crypto/getRandomValues)、[Taro订阅消息](https://docs.taro.zone/docs/apis/open-api/subscribe-message/requestSubscribeMessage)，以及本机固定Taro4.3.2的types/api/base/crypto.d.ts和types/api/open-api/subscribe-message.d.ts。
