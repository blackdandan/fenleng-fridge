# 微信提醒持久核心阶段

已批准WP06的延续，整体仍in-progress。在同级Shared Platform application/persistence实现版本快照、许可观察、日期任务、撤销标记与派发用例，新增V55；不新增本产品服务器。详细内部合同见上游docs/contracts/v1/mini-reminder-ledger-candidate.md，尚无公开HTTP或SDK接口。

只保存检查时刻/时区/自然日/数量，照片和食材正文不上云。相同修订/许可事件幂等，冲突和旧版本拒绝；同安装范围自然日去重跨修订和重新启用保持。发送前再次核对数据，协调保留许可后的删除、延期、数量与模板改变。只在已核验小程序绑定和当前账号/应用/客户端/成员资格允许时发送。

发送先持久写SENDING并保留观测预算，之后有界调用Provider，取消与派发按用户/计划/安装锁排序。数据库在Provider受理后失败时，不会因事务回滚重新发送；崩溃或未知结果保持UNCONFIRMED。确定忙碌等拒绝有限重试、确定失败归还预算；43101不猜拒绝/耗尽，而是等待新的主动授权。跨计划自然日后仍未发送标过期，不把旧数量跨天推送；站内本地检查独立可用。

此前取消凭据建议由服务端签发，现细化为客户端先生成并持久保存32字节随机凭据，再开始HTTP；服务端只存散列派生ID。取消先到也会留下撤销标记，迟到PUT不能重新开启。该动作在清空账号Token后仍可重试，API后续不能只接成依赖旧JWT的取消请求。客户端/SDK尚未接线，不能伪称原生随机值或实际取消HTTP已验收。

当前新核心21项真实隔离PostgreSQL测试通过；集中29项包含原可信绑定6、用户数据处理1、持久配置1也全通过，Bootstrap编译通过。随后去除任意未来年限上界并补较远日期断言，相关计划7项定向重跑通过。日志.fenleng/mini-reminder-ledger-milestone.log、mini-reminder-horizon-targeted.log。原始测试夹具构造参数编译失败已修正；有效结果只取最终成功运行。

新增数据已纳入原账号导出/批准删除：日程数组可读导出，任务与许可观察可导出；只有既有删除审批通过才清理，保留无用户字段的散列撤销标记防迟到写入。删除与工作器使用同一用户锁，竞态测试验证不会重建已删除的计划。无Owner治理/Secret策略变更。预检上界V55与runtime/release-engineering三个Node检查通过。

证据及源码哈希：../evidence/mini-reminder-ledger-results.json。Provider在这些核心测试中模拟，先前真实本地HTTP适配器测试单独保留；不是微信公网送达或完整小程序验收。本阶段未改APK/官网/小程序产物，没有部署或应用生产迁移。下一步仍是HTTP、周期调度配置、官方SDK与客户端，再按Owner后补的AppID/模板做原生验证。

平台与消费仓库知识审计均pass、nextAction=none；日志.fenleng/mini-reminder-ledger-{platform,fridge}-audit.log。整体产品目标仍未完成。
