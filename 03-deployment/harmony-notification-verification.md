# 鸿蒙本地提醒验证交接

当前为已接线的源码候选。28项宿主测试执行实际.ets规则/协调器/桥接/存储与生命周期源码，原生API使用明确替身，esbuild仅做类型擦除。未运行ArkTS编译器、构建HAP、签名、安装或验证实际送达；不能把这些测试称为鸿蒙原生测试通过。

固定工具链沿用Flutter-OH 62357a93d653bf844f730bb1f4b7cc9e2139d14e、DevEco26.0.0.851、SDK26.0.0.105/API26、ohpm26.0.0.630、hvigor6.26.8、hdc3.2.0f。当前Windows预检为not-ready，缺SDK和后三个命令；不是超时或构建进程仍在运行。不得删ohos目录绕过验证。构建前按既有鸿蒙签名合同完成com.fenlengtech.fridge的真实注册、appIdentifier及固定证书/Profile登记，不能用Android JKS冒充鸿蒙签名。

新增ohos/entry/src/main/ets/reminders四个文件，由BootstrapChannel合法plugins.initialize后authorize。EntryAbility保留冷/热启动日期，兼容同步和延迟engine配置；同意前只缓存日期，不查询权限、打开提醒账本或注册通知通道。主动开启沿用现有解释/OS请求流程；启动不申请通知。request、enabled、authorized状态分开。privacy.revoke立即封锁后续原生工作，取消已有请求/通知；finishRevoke在冷恢复时再次清理后才移除撤回标记。

系统采用reminderAgentManager日历代理，在应用退出后由系统接管。所有活动周期仅留私有账本，OS点击URI只有fridge://reminders/YYYY-MM-DD，不携带食材ID、照片、身份或反馈。同日同刻一批、同日分时使用同日期notificationId，内容为该时刻累计到期数量。过去未交接周期同日合为一次近期调度；毫秒向上舍入，不能提前告知未来周期。关闭/取消未来项不记成已送达；已经交给系统的到期周期按不重复策略保留，与库存历史及用户已读状态分开。

保守最多提前调度30批，扣除应用其它代理提醒占用；超出通过既有20语言notificationQueueLimited提示，前台/库存变化补齐。API26可有更高系统上限，本产品兼容窗口仍为30。不能宣称退出后无限未来保证送达。发布前先持久化intent，恢复时匹配OS日期/文案，避免publish成功但写盘失败造成双重调度；不确定且到期的交接不重放。存储损坏不覆盖，返回稳定错误。

部分处理后只更新仍存在的通知卡片，updateOnly=true、isAlertOnce=true，点击/划掉后的卡片不重新创建；所有项处理后取消日期卡片。updateOnly从API18起可用，API17发现需要更新的卡片时明确报不可用，不悄悄用有竞态的重新发布替代。华为当前权限资格规则还可能要求新申请应用使用较新OS及重新签发Profile，应在正式资格申请时复核，不伪造资格。

宿主回归：先在06-project/web执行npm ci（固定esbuild供测试转译），再从根执行：

```powershell
node --test 06-project/app/tool/harmony-reminders.test.mjs 06-project/app/tool/harmony-reminders-native.test.mjs 06-project/app/tool/harmony-entry-lifecycle.test.mjs
node .agents/skills/fl-ai-coding-delivery/scripts/check-harmonyos-environment.mjs
```

完成匹配SDK、FVM依赖生成及真实签名资产后，使用技能固定入口构建，不能把当前未执行命令写为成功：

```powershell
node .agents/skills/fl-ai-coding-delivery/scripts/package-flutter-harmonyos.mjs 06-project/app/apps/fridge debug
```

设备验收必须覆盖：首启拒绝/允许/设置返回；同意前无系统通知/账本初始化；退出应用后两批同日到期单卡数量更新；不同日期独立；处理部分/全部/撤销/改期/删除；旧通知冷/热点击只消费一次；关闭权限、重开、重启与时间/时区/夏令时变化；超过30批后打开补齐；发布或取消中撤回、杀进程重启恢复；同一notificationId的cancelReminder与已显示卡片是否互相影响；20语言大字/RTL和通用数量文案。原生桥接Map编解码、Ability生命周期签名、SDK类型及权限均须由真实编译和设备确认。

官方依据：[后台代理接口](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-reminderagentmanager/)、[容量与权限资格](https://developer.huawei.com/consumer/en/doc/harmonyos-references/errorcode-reminderagentmanager/)、[通知更新字段](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-inner-notification-notificationrequest/)、[通知查询与设置](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-notificationmanager/)。证据见../02-engineering/evidence/harmony-notification-source-results.json。
