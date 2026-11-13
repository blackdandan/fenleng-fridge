# 微信订阅发送Provider子阶段

所属已批准WP06，整体仍进行中。Shared Platform本地main/HEAD为777c6ba4d87be940b3cc91d1167f173e5e25ef49；未新建分支或发布。MCP固定同commit合同只证明普通推送/通知队列，来源元数据见../evidence/subscription-platform-knowledge.json。微信具体订阅此前缺失，不能冒称现有接口即可发送。

新增application内部MiniSubscriptionDeliveryPort与access-token端口，infrastructure实现真实微信REST调用；不在fenleng-fridge另建服务器。Token使用服务端POST stable_token、force_refresh=false，同步缓存避免并发重复取Token，按Provider有效期提前过期。只显式失效本地缓存，不强制旋转凭据。发送消息包含已验证归属的接收人、登记模板与检查所需最小字段；当前还没有公开接收任意接收人或正文的HTTP路由。

结果准确区分Provider已受理、许可不可用43101、明确拒绝、可受控重试与未确认。许可不可用无法从微信错误码独自区分拒绝或可用次数耗尽；Accepted不代表用户阅读。响应缺失、非整数ACK、非200或传输异常不猜成功、不自动重放非幂等发送。取Token失败发生在发送前，与发送结果未知分开。Java完整Future截止时间涵盖响应头和正文，取消该次响应后后续请求仍可使用客户端。

微信官方两份API文档经确定性HTTPS读取HTTP200，URL、抓取文件哈希与记录时间见../evidence/subscription-provider-sources.json；原始HTML只作本地核对，最终源码归档不分发抓取的整站文档。[订阅发送](https://developers.weixin.qq.com/miniprogram/dev/server/API/mp-message-management/subscribe-message/api_sendmessage.html)、[stable token](https://developers.weixin.qq.com/miniprogram/dev/server/API/mp-access-token/api_getstableaccesstoken.html)。前端必须在用户手势中发起请求，依据[Taro官方接口](https://docs.taro.zone/docs/apis/open-api/subscribe-message/requestSubscribeMessage)。

实际验证：platform-infrastructure:compileKotlin通过；WechatMiniSubscriptionDeliveryAdapterTest 6项+TokenProviderTest 4项，0失败0跳过。真实本地HTTP验证参数/值结构、并发缓存与过期、失效/失败恢复、许可/模板/速率错误、畸形ACK、无效消息不发送、正文卡住截止时间以及超时后后续请求。测试XML和源文件哈希见../evidence/mini-subscription-provider-results.json；命令日志.fenleng/mini-subscribe-provider-{compile,targeted}.log。测试凭据均为合成字符串，没有访问真实微信发送接口。

发送Provider未注册生产Bean或调度作业，没有公开API或SDK方法，也未改APK、小程序生产包/网站下载。后续已补可信OpenID绑定：V54表、JDBC仓库与持久Bean；Provider mini响应的AppID/OpenID在微信身份注册事务中按应用/用户/客户端归属保存，既有UnionID统一身份不变。非mini登录不写绑定，原先既有的canAuthenticate检查在事务内执行，避免失败登录更新绑定；写入失败回滚身份/成员/绑定后不签会话。原有用户数据导出/批准删除流程覆盖绑定元数据/清理，不改变生产删除审批策略。

6项真实PostgreSQL绑定测试和既有用户数据处理测试通过；首次新JDBC参数Instant无法推断，已改Timestamp；测试夹具Token摘要不符合数据库约束也已修正。V54只在隔离测试库运行，未操作生产数据库。集中回归同次31项全部通过、0跳过，涵盖Provider/原微信适配器、绑定/原有数据处理/真实Spring持久层与迁移、微信配置；证据见../evidence/mini-subscription-binding-evidence.json，XML已独立复制保存，避免后续Gradle测试覆盖阶段证据。上游与消费仓库知识审计均pass、nextAction=none，日志.fenleng/mini-subscribe-binding-{platform,fridge}-audit.log。

持久许可/计划/取消与去重、HTTP/SDK/客户端及真机仍未完成，WP06保持in-progress；上游详见docs/spec/wp-fridge-mini-subscription.md。

发布兼容复核：preflight上界从V53同步到实际V54并验证旧/未来版本边界；先前游客flag引入的runtime计数陈旧同步为总188/平台169，现有Secret、required和Owner审批条件不变。runtime schema、单机preflight和release engineering三个Node检查通过；没有运行构建发布或远程部署。
