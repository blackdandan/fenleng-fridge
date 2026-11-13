# WP05 埋点交付基础阶段

本阶段修复接关键事件之前发现的实际交付缺口，承接已批准WP05和平台/SDK联动授权；没有新建产品上报HTTP通道、改变Owner凭据策略、提交/推送或部署。

## 已实现

平台认证埋点此前忽略Idempotency-Key，网络结果未知后重试会重复入库。候选 IngestTelemetryBatches 复用现有事务、作用域锁和24小时幂等记录，将入库与accepted回执原子提交；应用/用户/客户端隔离，相同请求重放计数，不同请求同键409，旧无键兼容。无数据库迁移。记录仅是非凭据的计数字符串，未改变现有加密快照。

Flutter/JS官方SDK此前失败后会重建批次、可换键混入新事件，且仅凭HTTP成功就清队列。候选现在固定失败批次/时间戳/初始键，实际accepted整数等于该批数量才确认；新事件等待下批。撤回清队列及待重试快照，旧响应不影响重新同意后的事件；现有溢出对象身份确认仍保留。默认队列100、批量50，在途/待重试另保留最多一批快照；SDK没有无限自动重试。

Flutter采集时深快照属性，JS去除对structuredClone的依赖并拒绝非JSON/循环值；JS返回独立副本，调用方不能修改已经采集的事件。公共上下文按平台schema的长度约束校验，保留敏感字段拒绝。

公开平台基线777c6ba4d87be940b3cc91d1167f173e5e25ef49，MCP合同/schema来源见 ../telemetry-delivery-contract-evidence.json；SDK基线334611afbd9ae4be95771159a5cd00dc6f0ba31f，sourceMode local-git。新增幂等合同是未发布本地候选，不冒称已有公网能力。提供方文档 docs/contracts/v1/authenticated-telemetry.md；两上游各自 docs/spec/wp-fridge-telemetry-delivery.md 记录变更。

## 验证

- 平台应用5项、真实临时PostgreSQL3项、MockMvc HTTP3项，失败/错误/跳过均0。覆盖同键重放、变化冲突、属性顺序、作用域隔离、无键兼容、非法内容/键、双线程并发只入库一次、回执失败回滚整批、HTTP键绑定及嵌套校验；既有HTTP上下文1项也通过。Bootstrap编译通过。
- 官方JS SDK完整 npm test：80项全部通过。Flutter遥测7项全部通过，新增固定重试、无效ACK与深快照回归。不是正式客户端关键点触发或提供者验收。
- 平台合同127个operation、兼容性及30文件release manifest通过。新增契约为候选，未部署或正式启用。
- 日志 .fenleng/platform-telemetry-atomicity.log、platform-telemetry-http.log、sdk-telemetry-stage-full.log、flutter-telemetry-sdk-targeted.log；知识审计在本阶段收口执行并回写状态。

收口知识审计：项目、官方SDK、Shared Platform均pass、nextAction为none，分别记录于 .fenleng/telemetry-foundation-knowledge-audit.log、telemetry-sdk-knowledge-audit.log、telemetry-platform-knowledge-audit.log。无发布或生产采集。

## 仍待实现

本产品尚未接关键事件调用。后续从01-product/mvp/telemetry-events.json接入严格事件/属性枚举、V0.4统一同意、公共上下文、退出/撤回清理、受控重试及前后台flush；不增加独立分析开关，不采集食材/照片/编号/正文。官网使用既有官方匿名SDK，不用游客认证接口取代官网合同。

小程序当前core仍是原基线vendor，不能声称已消费本次core遥测修复；接入时需显式新增core候选归档及SHA证据，保留旧恢复入口。SDK最终不可变版本、去掉Flutter临时override、平台部署/事件目录/权限登记和真实产品分析均未完成。App/官网现有APK本轮未重建，不代表本阶段SDK源码运行证据；整体目标与WP05保持in-progress。
