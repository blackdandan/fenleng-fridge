# Flutter-OH 三端统一开发

## 唯一基线

读取 [固定基线](../assets/flutter-oh-baseline.json)。FVM管理该来源的完整commit；公共库、App、CI必须一致。不得用官方同名版本或实验custom缓存代替。预检运行 [check-flutter-oh.mjs](../scripts/check-flutter-oh.mjs)，实际SDK来源、commit、Dart和App平台目录必须通过。

## Day 1 初始化

先安装FVM并注册固定Fork，再使用基线commit安装和关联项目。命令参数从基线读取，不使用stable或dev浮动版本。

```text
fvm fork add fltech-oh https://gitcode.com/CPF-Flutter/flutter_flutter.git
fvm install fltech-oh/62357a93d653bf844f730bb1f4b7cc9e2139d14e
fvm use fltech-oh/62357a93d653bf844f730bb1f4b7cc9e2139d14e --skip-pub-get
fvm flutter create --platforms android,ios,ohos --org <真实组织标识> <app-name>
```

在Melos App成员中创建三端工程，workspace根和App成员正确继承同一SDK。不得把整个仓库覆盖生成；对已有项目只添加缺失平台并审阅差异。公共纯Dart/UI包不强制创建平台目录，原生插件必须声明并实现所需三端能力。

新工程的 Android `ndkVersion` 显式采用唯一基线 `android.newProjectNdk`，不要直接沿用模板的 `flutter.ndkVersion`。所锁定 Flutter-OH 模板默认 NDK 28.2；现有 NDK 29 已通过空白三端工程 Android Debug 构建验证。既有产品的原生插件需分别验证后迁移，不将模板默认版本当作唯一可用版本，也不将空白探针结果扩大为全部产品兼容。

创建后同时定义三端应用标识、权限、生命周期、构建渠道和平台能力清单。继续执行现有签名、iPad、国际化、隐私与埋点契约。鸿蒙原生SDK不得在隐私同意前初始化业务能力。

微信登录使用公共身份SDK的ohos实现，在隐私同意后注册并configureWechat；宿主登记weixin查询及exported/singleton回调Ability。授权state使用安全随机值，原生校验响应及非空授权码；服务端沿用统一身份交换，客户端不保存微信Token或AppSecret。明确未安装、取消、拒绝、超时及迟到回调处理；不能把支付桥接通过当作登录通过，缺少微信客户端时只记录构建及契约验证。

已有 `ohos/` 的工程执行 `fvm flutter pub get` 也会触发鸿蒙平台文件生成，需要可被所锁定 Flutter-OH 识别的 HarmonyOS SDK。只安装 Flutter-OH 不等于完整三端开发环境就绪。缺少 SDK 时，`fvm dart pub get` 可验证依赖解析和锁文件，但必须记录为依赖解析通过、平台生成未通过，不能用它代替 Flutter 命令成功证据。不得通过删除 `ohos/`、伪造 SDK 目录或忽略退出码宣称基线完成。

## 功能一致性

每个Feature共用业务实体、用例、状态流、API、权益与错误语义。权限弹窗、Provider和文件选择可因平台不同，差异写入同一功能规格，由公共Adapter装配，禁止散落平台分支或复制整套Feature。

新增依赖先检查精确版本的Android/iOS/ohos实现；纯Dart包也要验证文件、网络和FFI假设。缺少鸿蒙实现是该Feature交付项，不伪造成功，不静默隐藏业务功能。平台无需的能力明确记录不适用依据，例如Apple登录的iOS要求不自动变为鸿蒙相同Provider要求。

## 鸿蒙环境预检

采用唯一基线 `harmonyos` 字段所列的 DevEco Studio Release、SDK/API、ohpm、hvigor和hdc版本；Java/Node遵守其中最低版本要求。官方下载入口为 [DevEco Studio](https://developer.huawei.com/consumer/cn/download/deveco-studio)。记录安装包版本、来源和校验结果，升级工具链时同步修改基线并复验，不浮动使用最新包。

macOS标准安装目录为 `/Applications/DevEco-Studio.app/Contents`。将 `DEVECO_SDK_HOME` 指向其 `sdk`，`NODE_HOME` 指向 `tools/node`；PATH加入 `tools/ohpm/bin`、`tools/hvigor/bin` 和 `sdk/default/openharmony/toolchains`。环境配置应在新终端可重建；避免在消费项目提交个人绝对路径或签名材料。

运行 `node <skill-root>/scripts/check-harmonyos-environment.mjs`，确认SDK目录、Java、Node、ohpm、hvigorw和hdc实际可执行。依据所锁定Flutter-OH版本的维护方配套说明安装DevEco工具，不猜测SDK兼容版本。模拟器实名登录和签名资产由Owner完成对应授权操作；缺环境时记录not-ready，继续可完成源码工作，不声明HAP已构建。

从Day 0落实 [鸿蒙固定身份与签名](harmonyos-signing.md)，不得等到支付接入或上架才补注册身份和签名登记。

## 构建与验收

- Android使用既有 [标准打包入口](../scripts/package-flutter-android.mjs)，保持正式签名及中国渠道加固链。
- iOS验证模拟器、真机及Archive；CocoaPods产物和SwiftPM按工程真实配置接入。
- 鸿蒙按固定DevEco/SDK/JDK/Node/ohpm/hvigor/hdc工具链构建HAP，分别验证签名、安装、冷启动、生命周期、权限、回跳及恢复。构建命令经FVM。
- 每端记录build/runtime/release证据；桌面测试、目录存在或Mock不能替代原生与真机验证。
- 新视觉基线需记录SDK、字体、尺寸与语言，确认业务内容后生成，不删除旧差异证据。

## 升级与恢复

统一更新基线、FVM、公共库、所有消费成员和CI；先公共测试、再三端构建和运行。不修改共享Pub缓存来修插件。保留原SDK/lock/源码恢复入口；回退必须同时恢复源码、依赖和原生配置，不轮换签名身份。

原生插件和逐产品功能一致性按 [鸿蒙原生能力](harmonyos-native-capabilities.md) 执行；固定 SDK、签名构建与完整功能覆盖分别提供证据。
