# 提醒列表与Android系统通知阶段

依据已验收Figma b34I8tzPpU7tv1sHHdWLkq 的2:216，行为以MVP当前周期、同日合并、原始数量保留为准。规范来源沿用../../design-system-evidence.json。

RemindersScreen纯展示库存派生状态：待处理11→部分处理10/原始11→已处理0/原始11；完成移除整理按钮，空状态独立呈现。点击通知读最新库存，仅打开对应日期仍未处理项，陈旧通知不恢复旧周期。

430基准按FridgeLayout缩放几何，字体保留系统放大，宽屏限600居中。演示徽标及虚构10:00不进入正式页面，只显示真实日期。新增待处理/状态行与最小44px操作，卡片比示例高29px，不是整屏像素一致声明。

数字采样../../evidence/android/reminders-fidelity-sampling.json：页面/卡片两个平面色完全一致；卡片宽与扣除徽标后的顶部偏差≤2px；返回SVG边界≤1px；日期/标题/正文相对卡片顶部偏差≤2px，墨迹高度一致。正文/动作最近墨色一致，日期差3通道；标题差21通道，原稿YaHei与Android Noto CJK抗锯齿差异保留报告，不能称所有文字颜色完全相同。操作完整文案补齐20语言；箭头用单色north_east代替文本字形。返回SVG精确节点再次下载SHA相同，见../icon-assets.json。

## Android原生闭环

业务报告../../evidence/android/notifications-native-results.json，业务包f50ee291500a2a92caea93d52463919f3994abe56b43d21bf80779d4fa3d4c37：

- 首页不请求通知权限；先解释，取消不请求系统权限，继续后真实Android权限窗。
- 同日两条计划落盘，应用进程退出后真实AlarmManager触发一条合并通知，没有手动模拟通知。
- 点击冷启动进入001/002；部分处理原始2/待1，全部原始2/待0，不重复周期。
- 设备重启恢复003未来计划，已送达周期不重复；关闭提醒取消计划。

采用非精确定时，不申请精确闹钟权限；系统/省电可能延迟，界面说明。系统账本与站内提醒独立，看过或取消系统通知不会标记食材已处理。ABI/隐私/周期规则见../../specs/local-notification-contract.md。

最终文案视觉包c9c8e32b75ba1d706648dcf88b852ff400602eb8fb95f486c7e733d28a95fa5f固定签名构建安装通过，430四状态及320设置截图已检查，见../../evidence/android/notifications-visual-results.json。不声称此包重复业务包真实等待/重启测试。两轮恢复原3条库存、照片字节、通知开关/权限及density420。

解释Dialog独立提供FridgeLayout，实际左/右/顶部15.93逻辑px，来自业务包。此前缺布局作用域造成异常已修复，真实设置路由测试覆盖。

## 回归与未完成范围

App全量70项通过，其中通知新增13项；核心全量17项通过。提醒4张golden加既有10张共14张通过。20语言×2主题×6状态=240组，320px/文字2倍无异常。真实MethodChannel编解码测试验证三标志独立、提交失败不成功、持久化点击只消费一次。

小程序typecheck/weapp构建通过，两端150key同步。common.js343KiB超过webpack建议244KiB，保留性能警告，不声称小程序真机验收。

iOS/Harmony通知原生适配待实现，当前不是三端送达完成。剩余同意/权限视觉矩阵、相册替换、游客平台/遥测/反馈、完整小程序和官网继续推进，整体目标进行中。

阶段知识审计 `fl.cmd kno audit --project . --base HEAD` 通过，nextAction=none；日志 `.fenleng/notifications-knowledge-audit.log`。未提交、推送或部署。

后续iOS源码阶段：四文件与bootstrap/通知代理/Xcode接通，13个XCTest已备但未运行，语法/引用检查通过。共享层增加limited状态和20语言iOS分时归组/容量提示；152key同步，当前全App71/14golden加新增iPad80组1项通过。Android最新包c700b673经冷启动兼容检查，不重复宣称其已跑后台送达/重启全流程。详见../../../03-deployment/ios-notification-verification.md；iOS严格后台单卡同日合并仍未达到，Harmony适配待实现。
