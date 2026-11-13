# Flutter账号注销实施记录

归属已批准WP05，2026-11-13开始消费者实现。微信登录追加需求有效；继续沿用官方平台五分钟本人确认、七天等待/登录撤销和真实响应契约。当前194键共享语言资源覆盖20语言；以下模型阶段描述保留为历史，以末尾最新阶段为准。

本轮新增`apps/fridge/lib/application/account_deletion.dart`，模型不触发自动登录，不把退出/401当成功。确认取消不生成挑战或取新proof，提交前落盘submitting；真实有效七天回执先落盘再本机清理。写盘失败保留内存ACK，重试不再DELETE；未知结果保留原key，显式新登录结束旧未知意图后才生成新key。按owner保留旧账号记录，页面freeze/隐私close封闭迟到证明与响应；并发401不丢弃仍处有效同意内的真实原请求ACK。

新增`infrastructure/deletion_storage.dart`，使用独立account-deletion.json、版本化owner列表、受限字段和临时文件flush/rename，不访问库存/照片。校验scope/重复owner/申请键/阶段/真实七天日期；损坏文件报错保留，不能被空列表或新申请覆盖；未完成pending不代替原提交记录。原始UTC纳秒时间保留，计算由严格字段校验后的DateTime完成。

定向13项模型、4项真实临时磁盘测试通过；四文件静态分析无问题。覆盖取消、真实ACK顺序、写盘/清理失败重试、未知同key、重新登录新key、重启submitting、身份隔离、页面退出、撤回迟到ACK、并发401、重复提交、日期规范化拒绝、损坏/重复owner/pending与库存不变。模型驱动为测试端口，不能代替官方SDK/原生Provider或账号页运行证据。

未完成开发：真实官方SDK gateway、当前人类身份和revision/Provider选择、主动重新授权（微信/Apple及global通道）、本机身份清理防护、OnlineSessions/隐私/前后台互斥装配、账号页确认/回执与大字RTL验证。没有重新构建APK；不能宣称App注销已交付。下一步优先完成gateway及运行时，再页面、定向/阶段回归和安装包。

证据：`02-engineering/evidence/flutter-account-deletion-foundation-results.json`。小程序对应账号页阶段已完成本地验证，参见`mini-account-deletion-ui-results.json`；正式Provider配置、不可变SDK发布、平台部署和设备验收仍待后续。

## SDK、运行时与账号页最新阶段

新增PlatformDeletionGateway，官方FlutterAuthSDK读取当前HUMAN/ACTIVE用户，按环境/客户端/用户确定owner；原身份/同意/revision有效时创建挑战，重新取微信或Apple原生证明，核对确认ID、原幂等键和有效期，再以X-Action-Confirmation调用原DELETE。真实ACK验证userId/type/status/id/服务器日期后才映射回执。授权不调用普通登录、不替换Token；当前请求已受理时并发旧会话失效也不丢弃真实ACK。

SDK新增只读typed currentUser及logout(localOnly:true)。IdentitySession增加身份revision和本机退出接口，旧回执不能清除新登录会话；清理失败可只重试自己的代际。完成的身份操作及时释放Future引用，避免关闭时保留已结束操作的异步上下文。OnlineSessions装配真实gateway和FileDeletionStorage，注销期间暂停反馈/清除待发送遥测并阻止自动刷新/新游客。受理但回执未落盘或清理未完时，显式登录也等待本机恢复；撤回立即关闭注销模型并封闭迟到ACK。App提醒只依赖保留的本机库存，因此不注销本机提醒；小程序账号绑定订阅仍由原小程序gateway撤销。

账号页已接入口、左右16px确认弹窗、主动重新授权说明、iOS可选微信/Apple方式、服务器年份/日期、七天等待和登录撤销提示、未知/写盘/本机清理重试，以及页面退出围栏。待登录文案改为通用账号，避免Apple用户看到必须微信登录；20语言补齐新说明。使用既有FridgePage、Dialog、Card、Button、FridgeSpace和主题语义error色，未新增品牌Token。页面观察人类身份revision，恢复或新登录后对齐当前owner。

验证：新gateway10项、实际AccountPage+官方SDK（mock传输/原生proof）5条、实际Bootstrap3条运行时、20语言×两主题×10状态在320px/文字2倍的400组组件布局通过；模型/磁盘17项仍包含于App全量144项回归，原14张golden通过。SDK全量75项通过。Flutter Widget测试不是原生Provider/设备证据，400组是注销组件/弹窗矩阵，不是400次完整原生App运行。完整阶段证据见`02-engineering/evidence/flutter-account-deletion-results.json`。

新的China Debug APK已编译并核对com.fenlengtech.fridge/0.1.0+1及原固定证书。SHA256为4348a6d3ced06e09df21f29d0d8671aece7ee00b9740b63605fde6ab23fb2f50。实际ZIP内194键和kernel中的PlatformDeletionGateway/AccountDeletionSection/新文案均确认存在，避免把旧缓存产物当新包。标准打包脚本自动pub阶段受缺少HMOS SDK影响；复用已解析依赖以同固定Flutter执行Android --no-pub，单次GRADLE_OPTS指定Java17后成功，未改全局设置/SDK缓存/签名。构建、签名日志和payload检查归档在同一证据目录。

官网本地dist已更新为此APK，构建/静态检查及实际Chromium下载完整184867411字节/SHA256一致。仍是debug-preview，不称正式加固交付或微信主机下载验证。尚未重新安装Owner正在查看的模拟器，其已安装包仍是此前0dea646e...版本。

待继续：新页面原生截图复核、正式Provider/AppID和实际授权、global Firebase认证分支、不可变SDK发布替换本机路径、iOS/macOS及Harmony工具链验证。不将本地测试称为真实微信/Apple授权或生产注销已上线。
