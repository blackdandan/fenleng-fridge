# WP04 本地检查提醒通道

范围沿用已批准完整计划的WP02/03/04：无每日固定Push，无后台轮询/新增服务；本地库存独立于游客身份。当前先完成公共计划/协调器及Android实现，iOS和HarmonyOS原生适配与设备验证仍在整体交付范围内，不能把Android阶段当三端完成。

## 计划、身份与状态

`notificationPlan`从当前在库记录生成完整活动周期，包含过期记录和未来记录，按到期时间/编号排序。字段只有`key`（编号/周期二元组JSON）、`day`本地自然日、`hour/minute/second/millisecond`；毫秒向上舍入，避免微秒截断提前触发。没有照片、路径、食材内容或剩余描述，不上传到共享平台。移动/只改间隔保持计划身份；整理、手动改期和历史恢复产生新身份，没了/删除排除。

本地通知投递台账独立于库存提醒历史：App内`CheckReminder`保留原始周期引用与原始数量，pending按当前在库/周期一致/到时重新计算。查看或通知点击不算整理。Native台账保留已提醒周期，撤销恢复旧周期不重复提醒；关闭开关或关闭系统权限不清投递台账。

`enabled`是应用内偏好，`authorized`是OS当前授权，`requested`记录曾主动请求。三者分开呈现，只有启用且授权才显示已开启；拒绝时仍保留App内提醒。用户主动开启，China先解释、取消不调用OS；已授权不重复解释。现有官方permissions SDK（固定334611afbd9ae4be95771159a5cd00dc6f0ba31f基线对应未改文件）没有通知枚举，本产品用原生通知能力；未擅自扩充SDK候选8文件的发布范围。

## 本地MethodChannel

通道`fenleng.fridge/notifications`，业务方法必须在合法同意/渠道初始化后调用，不在首页申请权限。

| 方法 | 输入/输出 |
| --- | --- |
| status | 返回`{enabled,authorized,requested,limited?}`，只读OS状态；limited缺失默认false，iOS表示超出当前提前调度窗口 |
| request | 用户继续解释后才调用，返回实际授权状态；不自动启用偏好 |
| enable | `{enabled:bool}`，启用要求授权；关闭取消本应用通知及闹钟，保留已提醒台账 |
| sync | `{cycles:[...],copy:{title,body,channel,locale}}`；body带`{count}`，真实保存/协调后返回true，失败抛稳定码 |
| consumeTap | 原子取出并清除pending day，返回`YYYY-MM-DD`或null |
| settings | 主动进入本应用系统通知设置，返回实际启动结果 |
| Native→openReminder | `{day}`只是队列提示；Dart经consumeTap认领，防冷启动/前台事件竞态和重复回跳 |

通知点击只带日期，不带食材ID、Provider凭据或照片。App接受点击后先刷新到期状态，再打开该日当前pending；已处理的旧通知展示完成态，无对应历史则进入提醒列表。事件在同意前不打开库存。前台Timer在下次到期或30秒刷新，后台停止；这是App内时钟刷新，不是重复系统推送。库存变化、返回前台和语言改变同步最新计划。

## Android

原生`ReminderPlan/LocalReminders/ReminderBridge/ReminderReceiver`，标准库和系统API，不新增本地通知插件依赖。计划与台账存私有SharedPreferences；worker串行化，receiver用goAsync，不启动Flutter Engine、身份SDK或网络。只挂一个下一次到期闹钟；到时合并同日当前pending、记周期并重排下一个。日期稳定notification id、onlyAlertOnce和内容签名缓存避免普通同步重复更新/置顶。原始系统通知已被点开/划掉时，不因相同周期再次同步重建。

使用`setAndAllowWhileIdle`，不申请精确闹钟特权；只会在目标时间之后投递，省电与系统限制可能延迟。依据：[Android定时任务](https://developer.android.com/develop/background-work/services/alarms)、[通知运行时权限](https://developer.android.com/develop/ui/compose/notifications/notification-permission)。应用升级、设备启动、时间/时区变化重新协调本地墙钟时间。正常退出/进程回收仍靠OS调度；Android强行停止会取消闹钟，用户再次打开后重建，不能声称绕过系统限制。

接收器再次检查授权的业务策略版本及China同意记录；撤回同意关闭本地偏好并取消本应用计划和通知。OS投递和私有台账不构成一个事务，台账表示周期已交给提醒系统，不冒称用户已看到或处理；App内pending不随投递改变。系统通知只显示通用检查文案和数量。

## 端侧限制与后续

iOS的原生本地通知由UNUserNotificationCenter负责，不能把Android广播重排实现照搬。[Apple调度说明](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)及[请求标识](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier)已核对：相同标识会替换待调度请求；后续实现须核实同日分时及OS队列上限，保留实际能力边界，不能用重复通知冒充合并成功。HarmonyOS须按reminderAgentManager真实合同、权限与数量上限实现；当前没有ohpm/SDK/hvigor环境。正式AppID不是本地通知的前置条件。

验证日志和实际完成状态在implementation-status.json及WP04阶段证据更新；当前不声称三端系统送达、iOS归档或Harmony HAP通过。微信订阅消息是独立WP06，与本地App调度不混称。

## iOS源码阶段补充

Runner新增ReminderPlan/Store/Scheduler/Bridge四文件，已接bootstrap和启动前通知代理；13个真实Swift规则/端口测试已定义，尚未在Windows运行。Tree-sitter语法/工程引用通过仅是源码证据，见evidence/ios/notification-source-results.json；不是Swift编译或系统送达证据。完整接手步骤见../../03-deployment/ios-notification-verification.md。

同刻到期归成一个一次性请求；同日分时请求共享日期threadIdentifier，同日系统卡片可能是多张归组，不能按Android单卡更新验收。站内仍一日一条。没有把全部记录推迟到当天最后一批，也没有提前宣称后续食材已到期。保持周期身份、按次向上舍入秒、只有日期payload、冷/热点击队列只消费一次。通知代理在同意前只做内存路由，业务账本/授权/权限查询延后到合法bootstrap。

本产品保守提前调度最近60批，扣除其它feature占用，窗口外只保留为待补计划；设置显示20语言容量提示，打开/变更/前台时补齐。此限制不能描述为永不打开App也保证无限未来送达。尚未验证当前OS实际容量。iOS设置明确说明同日归组及系统延迟，与Android保持真实能力表述。

账本对已交付或已经到期且不再pending的请求保存周期，表示系统已消费的handoff，不是已阅读；未知丢弃采取不重复策略。取消未来计划不把未来周期标成已送达；逐条真实add成功后记录，add失败不伪造成功。撤回时停止后续提交并取消本功能请求；损坏账本保留，报稳定错误，不当作空计划覆盖。OS与本机存储不是原子事务，交界窗口需实机复核。

当前能力矩阵：Android后台/重启/点击真实验证；iOS源码及共享层验证、原生XCTest/设备待Owner；Harmony通知适配待实现。严格的iOS后台单卡同日合并仍未达到，不计作三端完成。

后续鸿蒙源码阶段已实现原生候选与生命周期接线：reminderAgentManager按日期稳定notificationId、累计数量、私有交接账本、30批窗口/limited、原生存储与发布恢复、关闭/撤回取消、只带日期的冷/热回跳。28项宿主测试通过；不代表ArkTS/HAP或系统行为验证。API18+已存在卡片的部分处理更新使用updateOnly，避免重建已划掉卡片；API17更新限制明确报错。详细能力、权限资格和设备待验清单见../../03-deployment/harmony-notification-verification.md。上段“待实现”为历史阶段状态；三端完整验收仍未达成。
