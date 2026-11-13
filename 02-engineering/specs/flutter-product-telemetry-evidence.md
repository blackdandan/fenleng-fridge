# WP05 Flutter关键操作埋点阶段

承接已批准WP05/Day0埋点要求与持续实施授权。仅使用官方FlutterTelemetrySDK，不在产品中增加HTTP上报、日志转事件或独立分析选择。

## 事件真相源与接线

01-product/mvp/telemetry-events.json更新为1.1，统一同意来源与当前V0.4法律文件对齐；原8个事件保留，反馈结果新增storage_failed/submit_failed，避免将写盘或非网络错误误记为network_failed。App随包assets/telemetry-events.json逐字节复制，测试验证与产品源一致；小程序/官网事件接线尚在后续阶段。

| 事件 | 实际触发点 | 确认边界 |
| --- | --- | --- |
| fridge.home.viewed.v1 | main.dart首个可见首页帧、从PageRoute回首页 | widget重绘不重复；弹窗不是新页面计数 |
| fridge.capture.started.v1 | CaptureFlow.take/chooseAlbum | 真正开始读取之前；重试保存不重复开始事件 |
| fridge.inventory.added.v1 | CaptureFlow的私有文件/仓库提交 | 每条成功落盘一次；读取/保存失败分开；保留原区域与camera/album来源 |
| fridge.review.updated.v1 | inventory_actions.organize | 仓库提交成功后才发，取当前记录区域 |
| fridge.permission.resolved.v1 | CameraCoordinator、NotificationSession.enable | 已有授权不重复计新申请；说明取消与授权/拒绝/受限只用枚举 |
| fridge.reminder.opened.v1 | App提醒页入口、已消费通知点击 | home或notification来源，无日期/库存编号 |
| fridge.feedback.submitted.v1 | FeedbackSession.submit | 回执落盘才success；失败只报固定分类，不读正文或异常文本 |

业务侧只依赖ProductEvent回调，emitProductEvent隔离采集异常；单一实现位于lib/infrastructure/product_telemetry.dart。未知事件、属性缺失/多余、敏感键及非枚举值在进入SDK之前失败关闭。没有照片、食材、编号、路径、反馈正文或凭据；产品归属由平台认证actor决定，不在事件body提交产品ID。

公共上下文：platform取Android/iOS/ohos；appVersion默认0.1.0（FRIDGE_APP_VERSION）；buildNumber默认1（FRIDGE_BUILD_NUMBER）；releaseChannel取现有APP_RELEASE_CHANNEL；locale取当前FridgeStrings。SDK只在onlineConsent（ready且持久接受当前V0.4/渠道）成立时初始化；同意前不采集、不恢复身份或发请求。global可以进入本机首页，但此状态不等于在线同意，没有接受记录就不创建身份/反馈/遥测SDK；global针对性编译测试通过，其完整在线同意/身份入口仍属后续范围。

## 发送与生命周期

FRIDGE_TELEMETRY_ENABLED默认false，且必须有有效平台配置才允许发送；它是构建配置，不是新增用户分析开关。先使用既有游客/账号会话，无可用会话不发送、不阻塞本机库存。2秒合并采集，每次flush最多3次尝试（300/600ms间隔），普通队列100、单批50，SDK固定待重试内容/初始键，只有实际accepted数量正确才移除。SDK可能额外持有最多一批在途/待重试快照，整体有界。

App后台尝试flush，只等待2秒，不能撤回已开始的请求；前台有待发送事件时受控恢复。Flutter通用SDK的响应头与正文分别按options.timeout（默认各10秒）有界等待，正文超时取消该响应订阅，保留共享client可用。首次停滞正文测试复现为200ms外层观察超时，修复后REQUEST_TIMEOUT且取消订阅；不是以外层观察超时冒充传输取消。

IdentitySession在主动账号切换、退出及已知旧会话失效时清未发送队列；Bootstrap.decline/reconsider/dispose亦清理。ProductTelemetry.withdraw提供统一撤回清理，旧响应不能移除重新同意后的新事件。**完整“设置→隐私政策→撤回”原生入口仍属WP03待完成，当前不声称端到端隐私撤回流程已验收。**

平台幂等候选/SDK来源见telemetry-delivery-foundation.md及上游wp-fridge-telemetry-delivery.md。新平台尚未部署，正式事件目录/游客权限未登记，不把本地事件采集或受控HTTP当生产产品分析。

## 验证与APK

最终App95项与所选SDK25项（身份17、遥测7、正文超时1）合计120项一次运行通过，保留全部14个golden回归；新增产品模型8、操作钩子7、实际App路由1、在线同意门禁1共17项。另官方Flutter SDK全集71项、global渠道同意定向1项通过。Dart对App lib/test及修改SDK文件分析无问题。http1.6.0仅列为dev_dependency用于MockClient验证，线上请求仍由官方SDK完成。

真实本机HTTP测试在既有游客反馈→重启refresh→微信交换之后，实际发送Bearer与Idempotency-Key埋点批次并验证ACK、上下文字段及原本机文件不变；测试Provider/本机服务不代表微信或生产平台验收。

最新固定签名china debug APK SHA256为88fcdb076e3eb9fe8e1f40af5d20237bcde4998081bcd09a88132c01102d6639，签名仍844fb2a1f368a875b79bf54b8e9859120ce80f9ecc0fbc1538ff41718e3f86e5。自己的API35模拟器安装哈希一致、冷启动首页无权限弹出、原3条库存/照片字节/通知标志/OS授权不变；APK内事件目录与源一致，debug kernel含ProductTelemetry/首页观察器/正文超时实现。报告../evidence/android/product-telemetry-smoke.json。它仍是未加固预览包，真实网络配置默认关闭。

日志：.fenleng/flutter-product-telemetry-full.log、flutter-sdk-response-full.log、flutter-product-telemetry-analyze.log、flutter-response-timeout-before.log、android-build-product-telemetry.log、android-product-telemetry-smoke.log。官网将同一最新APK作为本地预览下载，再验完整HTTP字节/SHA；没有重新执行未改UI的80状态网站矩阵，也不把旧矩阵当新APK原生证据。

QA证据路径事故：本轮派生脚本曾覆盖iOS-adapter阶段Android兼容截图/XML和JSON，已改为product-telemetry专属路径；旧JSON从原成功命令日志恢复，并明确标注原PNG/XML不可恢复，未伪造旧截图。当前APK截图独立保存并查看。用户库存、照片与权限没有因此改变；历史iOS原生测试仍未在Windows执行。

阶段收口：项目与SDK知识审计均pass、nextAction为none，日志 .fenleng/flutter-product-telemetry-knowledge-audit.log、flutter-response-sdk-knowledge-audit.log。官网完整HTTP GET的184867411字节与最新APK SHA88fcdb076e3eb9fe8e1f40af5d20237bcde4998081bcd09a88132c01102d6639一致；最新截图以APK哈希前缀固定文件名，避免跨阶段覆盖和图像缓存混淆。

截图就绪补充：Android可访问性树可能先返回旧首页语义，而新帧仍在启动加载。验收脚本已同时等待首页语义及实际柜体底色，并保存同一次检查的截图字节；最新report的paintedCabinetVisible=true，最终-painted.png检查副本人工查看为真实首页，不将加载截图当完成态。

## 剩余

完整统一隐私撤回入口、mini/官网埋点、订阅消息、global身份、注销及Harmony通知仍在整体范围；iOS原生编译/真机、真实微信授权/下载和Android真机/加固包待相应配置与交接。官方SDK仍为本地候选override，不是干净不可变消费者交付。本阶段不提交、推送或部署，WP05与整体目标保持in-progress。
