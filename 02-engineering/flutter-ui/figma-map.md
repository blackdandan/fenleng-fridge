# Flutter 设计实施索引

沿用 Owner 已验收完整设计与持续实现授权，按 fl-figma-map-ui-loop 对齐，不重新发散方案。Figma文件b34I8tzPpU7tv1sHHdWLkq；基础来源见 ../design-system-evidence.json。

适配：430px基准，FridgeLayout用页面可用宽/430缩放几何；iPad/宽屏页面整体限宽600并居中，标题/操作同一容器。字体不因窄屏缩小，保留系统TextScaler；字号变大时卡片随内容长高、页面可滚动；触控最小44逻辑px。原生状态栏/刘海由SafeArea处理，设计内模拟10:00和边框不复制。

| 页面/状态 | node-id | 实现 | 状态 |
|---|---|---|---|
| 首页/空柜/溢出 | 2:2 | cabinet、cabinet_door、cabinet_photos，原始SVG | 🔶 Android保真采样/3宽度/Widget+golden通过；iOS/Harmony设备未验 |
| 区域/入库与整理/记录网格 | 2:44 | records | 🔶 Android采样、8条记录、golden及大字多语言通过；iOS/Harmony待验 |
| 相机全页 | 2:81 | CapturePage/CaptureScreen及controls/viewfinder | 🔶 Android430/320数字采样、真实拍摄/切区/重启/解释与拒绝、golden及20语言大字通过；iOS/Harmony待验 |
| 整理四状态 | 2:99 | ReviewScreen/review_card | 🔶 Android采样、持久化/撤销、golden及真实路由测试通过；iOS/Harmony待验 |
| 详情/永久删除 | 2:149、42:95 | RecordEditor/record_editor_fields | 🔶 Android数字采样/430与320/真实编辑删除、golden通过；iOS/Harmony待验 |
| 设置/语言/外观/备案 | 2:172 | SettingsScreen/SettingsChoices/app_routes | 🔶 Android数字采样/430与320、写盘与重启、golden和20语言大字通过；iOS/Harmony待验 |
| 提醒/部分处理/完成/空态 | 2:216 | RemindersScreen/NotificationSession/Android LocalReminders | 🔶 Android真实后台触发/回跳/合并/重启恢复、430数字采样/320设置/4golden通过；iOS源码及13个XCTest已备/未编译/同日分时为系统归组；Harmony原生适配及28项宿主端口测试已备，原生编译/设备未验，见pages/reminders.md |
| 历史/恢复 | 2:227 | HistoryScreen | 🔶 Android数字采样、真实恢复周期/空态、golden通过；iOS/Harmony待验 |
| 首进/法律/权限说明 | 2:241、2:262、2:275、2:373、4:65、4:85 | ConsentScreen/系统WebView/CameraRationale | 🔶 首进2:241已校色/居中/安全区/按钮，430/320及80组合/Insets测试通过；Android离线WebView与真实撤回重同意留存通过，第二次UIA正文树缺失单列为自动化限制。相机2:262关闭/颜色/尺寸已补，边界<=1.801px、关闭字形差2.085px另记。iOS/Harmony运行未验 |
| 反馈 | 2:289、2:303、2:317 | FeedbackScreen/FeedbackSession/官方SDK | 🔶 草稿/失败/回执逻辑与golden、Android草稿与校验采样通过；游客与公网受理/iOS/Harmony仍待验 |

各行没有完整数字覆盖、golden和设备证据前，不标✅。Android历史QA为emulator-5580；该实例现在由Owner查看。本轮另建隔离emulator-5582验证，不修改Owner预览；iOS/macOS与Harmony设备检查仍未运行。
