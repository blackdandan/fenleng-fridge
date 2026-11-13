# iOS本地提醒验证交接

当前状态：原生源码、Xcode引用与13个XCTest用例已准备；Windows只执行Tree-sitter语法/引用检查、Flutter公共规则与布局测试。**尚未Swift类型检查、链接、运行XCTest、安装iPhone/iPad或Archive。** 工程不是已验收IPA。

当前共享 App 回归168项通过、默认 China 运行跳过7项 global 专项；显式 global 专项26项通过。20语言各200个key一致，首进协议新增80组布局及安全区/操作测试通过；证据见 `../02-engineering/evidence/android/consent-current/results.json`。这些结果不证明iOS原生编译或系统通知送达。早期iPad80组布局与14份golden、Android兼容检查仍是各自阶段证据，不能替代下面的Mac验证。

## 源码和工具

工程 `06-project/app/apps/fridge/ios/Runner.xcworkspace`；包名 `com.fenlengtech.fridge`，当前Podfile及Xcode配置均为iOS15起，iPhone/iPad设备族保持1,2。四个原生文件为Runner内ReminderPlan/ReminderStore/ReminderScheduler/ReminderBridge.swift，AppDelegate在启动完成前挂通知代理，只有内存路由；同意后的plugins.initialize才打开私有账本及通知业务通道。

在macOS配置Xcode及匹配模拟器、CocoaPods、FVM4.1.2，遵守固定Flutter-OH来源与commit `62357a93d653bf844f730bb1f4b7cc9e2139d14e`，不要改用官方同名版本。Flutter OH的pub原生生成还要求匹配Harmony SDK；缺SDK时记录失败，不删除ohos目录冒充三端基线通过。

SDK仍为未发布候选。源码交付ZIP在 `06-project/app/vendor/flsdk` 内带三份候选包及逐文件哈希，并以归档内的pubspec_overrides.yaml解析，不要求同级SDK仓库；规范产品仓库的正式Git依赖与本机覆盖另行保留。选用最新候选时核对 `../04-operations/delivery-candidate.md` 和候选manifest，不能把本地候选当正式SDK版本。

以下命令在macOS从仓库根执行，构建路径切换依次进行。当前Windows未执行这些命令：

```sh
cd 06-project/app
fvm install
fvm use --skip-pub-get --skip-setup --force
fvm dart pub get
# 先运行flutter --version以初始化固定SDK工具；无Harmony工具时只刷新移动端。
fvm flutter --version
FRIDGE_FLUTTER_SDK_ROOT="$(cd .fvm/flutter_sdk && pwd -P)"
fvm dart --packages="$FRIDGE_FLUTTER_SDK_ROOT/packages/flutter_tools/.dart_tool/package_config.json" \
  ../scripts/refresh-mobile-plugins.dart "$PWD/apps/fridge" "$FRIDGE_FLUTTER_SDK_ROOT"
cd apps/fridge
fvm flutter build ios --simulator --debug --no-pub --dart-define=APP_RELEASE_CHANNEL=china
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -showdestinations
```

首次安装FVM时须先按固定Flutter-OH基线登记 `fltech-oh` fork，并核对实际commit；不要把alias替换为官方Flutter。上面的移动端刷新辅助程序使用固定SDK工具生成Android/iOS插件，不伪造Harmony SDK，也不证明iOS编译成功。完整Harmony工具可用时可走正常Flutter pub流程。构建前核对 `ios/Flutter/IdentityDefaults.xcconfig` 的公开占位值；正式微信/Google回调值、Apple capability、Team及Profile按账号配置文档落实，默认未配置的真实Provider不能称已联调。

从showdestinations选择真实存在的iPhone模拟器UDID，再执行：

```sh
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination "platform=iOS Simulator,id=$FRIDGE_SIMULATOR_UDID" \
  -only-testing:RunnerTests test CODE_SIGNING_ALLOWED=NO
```

不把占位UDID直接提交执行。RunnerTests中13个测试验证分时分批/同刻合并、向上舍入、周期不重复、非法日期、夏令时、重复同步、重建账本、只取消本功能、失败重试、滚动队列、完成清卡、点击消费、损坏账本保留。它们使用最小系统端口替身，不能替代下面的真实OS检查。

## iPhone/iPad真实OS检查

1. 首装China首页不出现通知授权；设置→系统提醒→解释取消，不调用OS申请；继续后出现真实授权窗，拒绝可继续本机使用，系统设置回来刷新真实状态。
2. 开启提醒，安排同刻两条及同日稍后一条。退出App进程，实际等待系统送达。同刻合为一个请求；稍后一批不能提前。点击冷启动进入当前pending，部分/全部处理及陈旧通知不复活周期。
3. 反复前后台、切语言、划掉通知、重新启动，不重复已交付周期；修改日期/整理产生新周期可以重新提醒；永久删除、没了取消尚未触发的请求。
4. 关闭应用内提醒、撤回同意、关闭OS权限后，核对只取消本功能请求/卡片，账本保留。撤回中有异步add返回时也应停止剩余批次。
5. 设备重启、时区变化、手工改时间、夏令时边界、非公历系统日期均检查实际本地时刻。特别核实浮动Calendar trigger在App关闭后的时区行为；源码语法与规则用例不能证明系统行为。
6. 超过60个分时批次时仅提前注册最近窗口，并显示容量提示；重新打开补齐余下计划。检查系统实际接受数量，不能将App未打开时窗口以外的记录描述为已调度。
7. iPhone和iPad横竖屏/大字/键盘/浅深主题检查设置和权限、拍摄与协议WebView；归档另核对Team/Profile、Capabilities与账号真实配置。

## 必须保留的能力边界

iOS按实际到期批次注册一次性本地请求，并以threadIdentifier按日期归组。**同日不同时间可能有组内多张系统卡片，不能声称与Android后台更新单张卡片完全相同。** 站内列表仍严格按日一条、保留原始数量和最新待处理量。队列上限是本产品采用的保守60窗口，已为其它本地请求留余量；不是对当前iOS无限后台调度能力的承诺。

私有seen账本记录已被OS消费/交付的周期，不代表用户实际看过。系统请求消失且到期后采取不重复策略；无法把OS操作与UserDefaults写入做原子事务。后台投递、系统归组、时间变化和崩溃交界仍必须实机验证。当前不把同日归组算作严格单卡合并验收完成。

依据：[Apple本地调度](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)、[请求标识替换待调度请求](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier)、[日期归组](https://developer.apple.com/documentation/usernotifications/unnotificationcontent/threadidentifier)、[代理必须在启动完成前设置](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)。旧UILocalNotification文档说明过64项限制，本实现保守留余量，**不把旧类文档当现代API容量实测**。
