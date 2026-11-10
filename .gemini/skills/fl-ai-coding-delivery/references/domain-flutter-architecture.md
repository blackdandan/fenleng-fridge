# Flutter 移动端工程架构选型与规范

> 本文件是 Fenlengtechbase 体系中移动端 (Android / iOS / HarmonyOS NEXT) 的唯一工程选型与架构规范。

账号注册、首版注销、国际化字符串目录及中国/全球构建渠道必须同时遵守 [`day0-account-channel-i18n.md`](day0-account-channel-i18n.md)，不得推迟到上架阶段。含中国发布渠道的 Android/iOS/HarmonyOS NEXT APP 必须同时遵守 [`day0-china-app-privacy-consent.md`](day0-china-app-privacy-consent.md)，在首次启动明确同意前阻断业务 SDK、网络、权限与业务数据初始化，并从 Day 1 在 Android `MainActivity`、iOS `AppDelegate`、HarmonyOS `EntryAbility` 采用 `DeferredPluginRegistrant` 延后注册非 allowlist 原生插件（避免先生成标准全量自动注册入口再中途返工）。产品埋点遵守 [`day0-telemetry.md`](day0-telemetry.md)，关键流程与事件目录随功能同时交付。

面向 Apple 平台且提供任一第三方登录的应用，Day 0 必须同时交付 Sign in with Apple。Capability、entitlement、Bundle ID、Provisioning Profile、Provider/服务端 audience 和真机回归必须按账号契约第 2.1 节闭环，不得推迟到 App Store 审核被拒后补做。

## 1. 工程拓扑选型 (Melos Monorepo)

面向 iOS/iPadOS 的 App，Day 0 默认同时支持 iPhone 与 iPad 基础适配，必须遵守 [`day0-ipad-basic-adaptation.md`](day0-ipad-basic-adaptation.md)。该要求不以账号或第三方登录为前提，不能推迟到审核被拒后补做；复杂分栏不是默认要求。

无论移动端应用规模大小，**从 Day 1 初始化起，必须采用 Melos (Monorepo) 多包隔离拓扑**，拒绝单目录混杂代码：

- `pubspec.yaml` & `melos.yaml` (根包多包管理)
- `packages/core`：通用底层工具、网络 HttpClient、本地存储与基础 Base 接口
- `packages/ui_kit`：设计系统组件库、全局视觉 Theme 主题 Token
- `packages/navigation`：全局路由桥 (Router Bridge) 与模块间解耦通信总线
- `packages/features/feature_*`：独立业务功能模块 (如 `feature_auth`, `feature_profile`)

> 🚨 **【Day 1 强制拓扑铁律】**：严禁以 MVP 阶段、快速原型验证、需求简单或项目规模较小为由，降级退回单 Package 目录结构（即直接在根目录 `lib/` 下混写所有代码）。**MVP 裁剪的是业务用例的功能数量，而绝不能裁剪底层架构标准**。即使是 MVP 的第一个版本，也必须在 Day 1 建立 `melos.yaml` 及 `packages/` 多包隔离拓扑。

---

## 2. 模块解耦与通信铁律

1. **单向依赖图 (DAG)**：
   - `features/feature_*` 只能向下依赖 `core`、`ui_kit` 和 `navigation`。
   - `features` 模块之间**绝对禁止产生直接依赖或循环引用**。
2. **路由桥依赖倒置**：
   - Feature 模块间若需要界面跳转或数据交互，必须通过 `packages/navigation` 暴露的路由协议进行依赖倒置调用。

---

## 3. 模块内部 Clean Architecture 与状态流

1. **Clean Architecture 分层**：
   - `Presentation` (Widgets / Screens) ➔ `UseCase / Notifier` (应用用例与状态) ➔ `Domain` (纯粹 Dart 实体)  `Data` (Repository / API Data Sources)。
2. **响应式单向数据流 ($UI = f(State)$)**：
   - 必须使用声明式状态管理；
   - Widgets 仅负责界面渲染与发出 User Actions，**绝对禁止在 Widget 内部编写 API 请求或本地存储逻辑**。

---

## 4. 环境隔离与 FVM 规范 (Environment & FVM)

统一工具链采用 [Flutter-OH 固定基线](../assets/flutter-oh-baseline.json)。所有 FL Flutter 消费项目、公共 SDK、UI Kit 和 CI 必须使用相同 SDK 来源与完整 commit，不得仅用同名 Flutter 版本代替来源核验。新产品 Day 1 必须建立 `android/`、`ios/`、`ohos/` 三个平台工程，保留一套 Dart 业务与 UI；每个功能同步定义三端业务规则、状态、错误和权益语义，平台能力由公共 Adapter 实现并随功能交付。原功能零退化必须有回归证据；构建成功不等于运行或三端完整支持。

编码、构建和 CI 前运行 `node <skill-root>/scripts/check-flutter-oh.mjs <project-root>`，核对配置、实际 Git 来源/commit、Dart 与 App 三端目录；失败必须修复，不能用预检成功替代能力验收。

FVM 使用 `fltech-oh` Fork 别名及固定 commit 管理适配 SDK；不得把实验 `/tmp` custom 缓存或全局 PATH 切换作为正式接入。SDK 升级必须更新统一基线与所有消费者及 CI，并重新验证三端。

1. **版本锁定 (.fvmrc)**：
   - 移动端项目根目录必须提交 `.fvmrc` 或 `.fvm/fvm_config.json`，显式锁定团队、AI Agent 与 CI/CD 共同遵守的 Flutter SDK 版本。
2. **Pre-flight 环境检测与极速补全**：
   - 编码与构建前必须执行 FVM 环境预检：
     - **检测 FVM 命令行**：未安装时执行 `dart pub global activate fvm`；
     - **补全与切换**：运行 `fvm install` 自动下载缺失 SDK，运行 `fvm use` 关联项目环境。
3. **命令代理执行铁律**：
   - 所有在本地、CI/CD 及 AI Agent 会话中执行的工具链命令，必须前缀 `fvm`（如 `fvm flutter test`、`fvm exec melos bs`），**严禁直接调用系统全局 `flutter`**，防止版本污染。

---

## 5. Android 签名凭据的人类控制边界

1. `android/key.properties`、`android/signing/credentials.properties` 以及它们引用的 keystore 都是 Owner 控制的签名凭据资产。AI 默认只允许检查文件是否存在、权限是否合理、必需字段名是否齐全以及证书指纹是否匹配；检查不得输出任何凭据值。
2. **禁止 AI 自动创建、修改、覆盖、迁移、删除或轮换 `key.properties`、`credentials.properties` 及 keystore**，也不得因为日志暴露、格式不统一、路径迁移、构建失败或安全建议而自行“修复”。只有 Owner 对具体项目和本次具体动作作出明确授权后才能执行；安全风险只报告，不把风险判断当作修改授权。
3. 新项目 Day 1 需要签名资产时，AI 先生成不含秘密的路径、字段和 SSH/Vault 操作预览，等待 Owner 明确批准后再创建或物化。已有应用必须保留原证书身份，不能以初始化模板为由重新生成。
4. Android debug、profile 与 release 必须引用同一份项目签名配置；构建和加固脚本只能读取凭据，不得回写凭据文件。

5. 生成或复核签名信息时，必须在 App 仓库的 `05-knowledge/signinfo/application-signing-info.json` 保存并 Git 跟踪公开登记元数据：应用名称、后台域名、Android 包名、iOS Bundle ID、Android/iOS 证书指纹、公钥和签名定位。iOS 同时记录 Team ID、证书 ID 与证书名称。该文件不得包含密码、私钥、AppSecret、Token、keystore 内容或私钥导出路径；缺失信息使用 `null` 并标记待 Owner 补充。

6. iOS 项目在 Day 1 固定 Team ID、正式 Bundle ID 和 Apple Distribution 身份；同一 Team 的 Distribution 证书可以供多个 App 使用，但每个 App 必须有独立的显式 App ID 和 App Store Provisioning Profile，并把 Profile ID、名称及到期日写入签名登记。开发构建使用 Apple Development，归档/发布使用 Apple Distribution，不要求也不能把两者合并成同一证书。

7. Owner 已明确采用私人 Git 保存签名身份时，每个 iOS App 固定 Git 跟踪 `<ios-root>/signing/apple-distribution.p12`，并在签名登记中保存路径、钥匙串身份和归档密码模式。该例外只改变 Owner 已授权的私钥存储位置，不授权 AI 自行轮换、删除或扩大仓库访问权限。

---

鸿蒙App从Day 0执行 [HarmonyOS固定签名契约](harmonyos-signing.md)，与Android/iOS同级登记正式应用身份和签名路径；debug/release使用同一正式应用身份与长期密钥，证书/Profile按华为官方类型配对。

## 6. Android Day 1 签名与打包契约

1. 含 Android 的 Flutter App 在 Day 1 必须声明以下固定位置；新建文件仍受上一节的 Owner 明确授权约束：

   ```text
   <flutter-app-root>/android/signing/
   ├── application-release.jks
   └── credentials.properties
   ```

   `credentials.properties` 只包含 `storeFile=signing/application-release.jks`、`storePassword`、`keyAlias`、`keyPassword` 四项。已有项目使用 `android/key.properties` 时允许继续读取，不得为了路径统一自动迁移。
2. 每个 App 使用独立签名身份。Vault 稳定名称为 `<project-id>-android-keystore`、`<project-id>-android-store-password`、`<project-id>-android-key-alias`、`<project-id>-android-key-password`；只通过 `ssh root@121.199.10.6 fl-secret ...` 既有通道存取。使用 [`../scripts/store-flutter-android-signing.mjs`](../scripts/store-flutter-android-signing.mjs) 默认只读预检，只有 Owner 对具体项目明确批准后才能追加 `--apply`；脚本只创建缺失条目，发现已有条目绝不覆盖，并在不回显值的情况下逐项比对。不得猜测、轮换或把值带入命令、日志、聊天和 Git diff。
3. Gradle 只定义一个项目签名配置，并让 `debug`、`profile`、`release` 全部引用它；禁止 Android 默认 debug keystore 回退。构建开始前必须验证凭据文件、keystore、alias 和证书可用，并且不回写任何签名资产。
4. 标准打包入口为 [`../scripts/package-flutter-android.mjs`](../scripts/package-flutter-android.mjs)：

   ```bash
   node <skill-root>/scripts/package-flutter-android.mjs --project <flutter-app-root> --mode debug --channel china
   node <skill-root>/scripts/package-flutter-android.mjs --project <flutter-app-root> --mode release --channel china --device <adb-serial>
   node <skill-root>/scripts/package-flutter-android.mjs --project <flutter-app-root> --mode release --channel global
   ```

   渠道必须显式传入，禁止默认猜测。debug 只生成同证书签名的 `app-debug.apk`；`release --channel china` 必须先由 FVM 构建正式签名 APK，再自动执行固定版本 Mocika Shield 加壳、用同一项目 keystore 重新签名、比较加壳前后证书摘要，并通过 `--device <adb-serial>`（自动化环境也可设置 `ANDROID_SERIAL`）在指定真机完成覆盖安装、至少 10 秒冷启动存活以及 Java/native fatal 日志检查，最终才写出 `app-release-hardened.apk`。`release --channel global` 只输出并验证同项目正式签名的普通 `app-release.apk`，不得下载或运行 Mocika；Apple App Store 与 Google Play 分发不进入中国 Android 加固链。Mocika 对应用 DEX 做压缩加密并注入四 ABI Native 恢复壳；Flutter/Dart Native 代码不属于当前保护目标。生成文件、签名通过或可安装都不能替代中国渠道运行验证。
5. Mocika 的 tag、完整 commit、源码归档 SHA-256、官方平台发行包 SHA-256、运行资源 SHA-256、apktool SHA-256 与工具包 apksigner SHA-256 都固化在标准脚本中。macOS 或 Windows 首次使用从固定上游下载并校验源码与对应平台官方发行资源，以 `cargo build --release --locked` 编译 CLI 后写入用户缓存；Windows 需要 Rust/Cargo 与 Visual C++ Build Tools，脚本检测 FVM 并加载 MSVC 环境；后续每次复核缓存文件。校验失败、Mocika 未明确报告完成、产物缺失/过小、签名不一致、加壳前后字节相同、未提供指定真机或冷启动进程未持续存活时必须失败关闭，并在开始时删除同路径旧加固产物，禁止误用遗留文件。签名口令只通过子进程环境变量传递，不写临时配置、不进入命令行参数，并捕获脱敏工具输出。
6. 官网存在 Android 下载入口时，常规 staging 只能读取通过指定真机冷启动门禁后生成的 `app-release-hardened.apk`，不得静默回退到普通 `app-release.apk` 或磁盘遗留 APK；官网构建与 APK 构建必须属于同一发布 HEAD，并按产品官网下载契约完成哈希与线上 smoke。已上线加固产物被真机证明确认不可运行时，Owner 可明确批准应急恢复为同签名、真机验证通过的普通 release；登记必须如实标注 `hardener: none`，不得继续宣称已加固，待新加固方案通过同一门禁后再恢复常规路径。

---

## 7. MVP 演进与零退化铁律 (Zero-Degradation in MVP)

1. **架构与业务范围解耦**：MVP 只允许对功能列表（Feature List）进行精简，严禁降级物理架构标准。
2. **AI Agent 初始化约束**：在初始化或生成工程结构时，AI Agent 必须默认拉起 Melos 多包结构。严禁 AI 在工程架构文档中伪造“MVP 阶段暂用单体”的妥协决策。
3. **自动化 Guardrail 断言**：预检 Hook 及诊断命令将扫描 `melos.yaml` 与 `packages/` 结构，若缺失多包拓扑直接标为 `blocked`。

## 7.1 移动支付 SDK 身份与 Universal Link Gate

需要将 App 支付打通 Shared Platform、补齐原生 SDK 或验收付款后权益时，读取 [fl-app-payment-integration](../../fl-app-payment-integration/SKILL.md)，保留本节身份资料要求；数字权益订阅同时执行唯一真相源 [数字订阅渠道矩阵](../../fl-app-payment-integration/references/digital-subscription-channel-policy.md)。

1. 首次接入或更换支付宝、微信支付及其他会回跳 App 的支付 SDK 时，必须先从项目 Knowledge 读取并确认：中文/英文应用名称、应用图标、应用简介、移动应用类型、目标平台、Android 正式包名、正式签名证书 MD5、iOS Bundle ID、Apple Team ID、Associated Domains、AASA App ID、canonical Universal Link 和线上 AASA 状态。不得从仓库名、debug 签名或候选 URL猜测。
2. 每个 App 只维护一条 Provider 无关的 canonical Universal Link，默认 `https://{app-domain}/app/`；微信和支付宝复用该链接。SDK/provider 差异由原生回调 Adapter 处理，不为新 Provider 新建 `/wechat/`、`/alipay/` 路径。遗留专用路径可以兼容，但必须同时保留 canonical `/app/`。
3. 支付 SDK 实现前必须在项目 Manifest 暴露的 Knowledge 根内生成平台申请资料，至少包含支付宝创建应用所需的应用名称（不超过 32 个字）、待绑定商家账号、320×320 PNG 图标、应用简介、移动应用类型、所选平台、Android 应用签名/包名、iOS Bundle ID/Universal Links、字段证据和最后复核时间。商家账号等 Owner 专属选择未知时必须标记待填写，禁止伪造。创建支付宝应用时执行 [支付接入规则](../../fl-app-payment-integration/references/alipay-app.md) 的公钥准备、后台填写与下载交接，不能只生成申请资料就结束。
4. AASA、entitlements、SDK 参数和平台后台填写值必须一致。仓库测试至少验证 AASA JSON、构建复制、`/app/*`、Team ID + Bundle ID、HTTPS 尾斜杠和 SDK 配置；公网发布与真实设备回跳未验证时状态只能是 `source-ready` 或 `validated-with-follow-up`。
5. Android “应用签名”使用正式发布证书的 MD5（32 位小写、无冒号），并通过最终 APK/AAB 的签名证书复核；不得使用 SHA-1、debug keystore 或签名口令。应用图标和签名摘要属于可提交资料，keystore、密码、AppSecret、支付宝私钥和 Token 不得进入申请文档或日志。


## 8. APP Day 1 备案展示

1. 首次创建 Android/iOS/HarmonyOS NEXT APP 时，在“我的”或介绍等显著页面预置 **APP备案号** 及查询入口，游客和登录态均可访问。使用“设置”路径时必须在两级菜单以内（设置为第一级，设置-关于为第二级）；若置于第三级，第三级必须是“ICP备案编号”或“APP备案编号”专用菜单。
2. 编号链接到 `https://beian.miit.gov.cn`，或在编号下方提供该查询链接；移动端点击拉起外部浏览器。启动失败给出可读的短时提示。
3. 有 APP 备案号时展示真实编号；尚未备案时显示“备案号待补充”，保留查询入口。不得编造编号或拿网站备案号替代 APP 备案号。
4. 在项目配置中建立 `appRegistration.number` 和 `appRegistration.queryUrl`；空编号使用占位文案。工程指导文件写明运行时配置位置与后续补充步骤，双端读取同一来源。验收游客/登录、待补充/已备案、外部打开失败、窄屏与大字体状态。
