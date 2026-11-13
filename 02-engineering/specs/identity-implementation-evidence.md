# WP05 身份子阶段证据（2026-11-13）

当前后续：游客/微信账号衔接及最新95项验证见 [guest-session-implementation-evidence.md](guest-session-implementation-evidence.md)。本文件以下保留分阶段记录；原8文件 SDK 补丁属于当时快照，共享源码已经演进，不能再当作最新候选的完整补丁。

Owner 追加「微信登录也实现一下」，承接完整 Epic 持续执行授权及平台/SDK 联动专项授权。保留游客本机使用，无邮箱密码注册，无支付，不改变库存归属或做隐式云同步。此文件记录阶段实现，WP05 和整体 Epic 均未完成。

## 当前实现

- Flutter：设置 → 账号 → 微信登录；iOS 同屏同级 Apple 登录。`IdentitySession` 串行化授权、交换与退出；关闭/撤回时拒绝迟到授权，交换已完成则清理迟到会话。成功只由官方 SDK 的平台响应和持久化结果决定。
- Android：本项目包名下 `wxapi.WXEntryActivity` 经官方 OpenSDK `handleIntent` 校验再交给官方 Client SDK dispatcher；AppID 从同一 Dart 编译参数进入 manifest。SDK 的 `state` 校验、取消/拒绝处理保留，补充 120 秒超时和过期回调隔离。
- iOS：官方 SDK 微信 callback/Scene delegate；URL scheme、Associated Domains 和 Apple entitlement 已加入源码。系统 AuthenticationServices 获取 Apple identity token，通过官方 SDK 新增交换方法交 Shared Platform 验证；不索取姓名/邮箱。Windows 未做 Xcode 编译或真实授权。
- HarmonyOS：消费官方 SDK 已有 OHPM 1.0.23 原生授权实现；宿主补 `weixin` queryScheme 和 singleton EntryAbility。当前无 SDK/ohpm/hvigor，不声称 HAP 或真机登录通过。
- 微信小程序：官方 Taro SDK 配合 `Taro.login` 一次性 code，平台会话独立持久化，重复点击共用一次授权；页面关闭后迟到 code 不交换。账号页面已构建，完整设置/库存导航仍待接入。
- 20 语言新增 12 个身份 key；当前 68 个核心 key 的两端副本、变量一致性检查通过。

## 契约来源

平台 MCP：repository `https://github.com/blackdandan/fenleng-shared-platform`，resolvedCommit `0ec42a11af95c0121784939d5cce80aa67c6d9ee`；`docs/contracts/v1/mini-program-identity.md`，sourceMode `github`；另核对同一仓库 OpenAPI 的 `/auth/wechat/login` 和 `/auth/federated/apple/login` 及 identity schema。

SDK MCP 对 main 和指定 commit 均返回 `REF_NOT_FOUND`。使用本机真实 Git 仓库核对，不冒称 MCP 已读取成功：repository `https://github.com/blackdandan/fenleng-client-sdk.git`，基线完整 commit `334611afbd9ae4be95771159a5cd00dc6f0ba31f`，sourceMode `local-git`；公开 `FlutterAuthSDK`、native-identity、TaroAuthSDK/TaroSessionCoordinator 源码。小程序不可变 tgz 来自该 commit 的 `git archive`，SHA-256 见 `06-project/mini-program/vendor/provenance.json`。

必要 SDK 候选修改位于同级 `fenleng-client-sdk`，包括 Apple 交换 API、TokenPair 空值/部分写入处理、Android/iOS 微信超时及迟到回调清理。尚未发布固定新 commit；App 当前通过被忽略的 `06-project/app/pubspec_overrides.yaml` 消费本地候选，**不是清洁消费者最终交付**。须在源变更提交发布后把 SDK 包统一固定到一个完整 commit 并移除覆盖，再重新验证。未擅自推送或部署。

## 已运行验证

- Flutter 身份控制器 6 项、会话文件持久化/损坏恢复 1 项、同意/离线 WebView 通道 4 项通过。
- 官方 SDK 微信交换 1 项、Apple/TokenPair 异常 3 项、既有认证回归 6 项通过（在消费 App 测试环境中执行公开 SDK 测试）。
- 新账号页 20 语言 × 浅/深主题，320px 窄屏、2 倍文字：通过，无布局异常。
- 小程序身份适配器 4 项、TypeScript typecheck、weapp 构建通过；无开发者工具/真机证据。
- Android 固定签名 debug APK 构建通过，哈希及实际安装证据见 implementation-status；未配置入口在隔离模拟器明确显示「登录暂未配置，可继续免登录使用」，没有虚假成功。

## 仍待完成

正式 AppID/服务端客户端登记、真正微信授权及账号关联、Apple capability/profile 和 macOS 验证；账号注销完整生命周期、global Firebase 分支、游客平台会话/反馈/遥测接入、mini 完整导航与后续订阅消息。配置未齐不触发伪造身份，不把构建/夹具当平台成功。

原生 API 依据：[Apple 授权流程](https://developer.apple.com/documentation/authenticationservices/implementing-user-authentication-with-sign-in-with-apple)。SDK 实现和渠道配置仅为工程证据，实际提供者验收另列。

SDK 知识审计：`fl.cmd kno audit --project ../fenleng-client-sdk --base 334611afbd9ae4be95771159a5cd00dc6f0ba31f` 返回 pass；8个候选文件，未检测到平台 HTTP 契约敏感变更。可审补丁：`../upstream-changes/client-sdk-identity.patch`，反向 apply --check 验证与当前候选一致。SDK push 已单独询问，等待 Owner 回答，其间继续产品工作。

## 微信入口收口补充

小程序首页设置入口已连接账号页，账号页改用全局语言、主题与统一组件；保留用户协议/隐私政策访问。设置页其余业务项仍待 WP03 完成，不把当前精简入口当完整设置验收。

小程序登录等待初始会话恢复，避免抢跑；退出使待返回的原生 code 失效；授权交换失败后重试重新获取 code。新增测试验证重新构造适配器后走平台 refresh 而非再次 wx.login，并核对 logout 清令牌。错误只映射已有本地化 key。Flutter 补齐恢复途中撤回/关闭时清理迟到会话。

本次验证：小程序身份 9 项通过，TypeScript typecheck、平台边界检查、20语言80key校验通过；weapp 构建成功，既有公共样式有 postcss-calc/rpx 警告，未冒称原生视觉验收。Flutter 身份 7 项和账号 20语言/2主题/320px/2倍文字布局 1 项通过。Android APK 尚未因本次源码更新重打；此前 APK 不能作为新增逻辑的运行证据。真实 AppID、平台登记与提供者授权仍待配置后联调。

## 当前收口验证

以上分阶段数字和 APK 状态是当时记录，当前以本节及 implementation-status.json 为准：

- App 全部 27 项测试通过，包括身份控制器 7 项、身份持久化和账号多语言布局；UI kit、inventory、App lib/test 的 Dart analyze 无问题。
- 官方 SDK 的 wechat_auth、apple_auth、auth 三份测试共 10 项通过；小程序身份测试 9 项通过。
- 最新 weapp 构建成功，日志 `.fenleng/mini-build-inventory-ui.log`；公共样式警告已在后续阶段修复。
- 最新 Android debug APK SHA-256 为 `295f31b91285fa7301f386ccef8c23b46f38222dfeba70c841274c35406bb16b`，包含当前身份代码。隔离模拟器运行可证明未配置入口和本机业务可用，不能证明微信真实授权成功。
- 当前两端共用 20 语言、90 key 真相源。配置步骤见 `../../03-deployment/identity-configuration.md`，正式配置后按其清单验收 Provider。

状态：身份源码与本地自动化已验证；正式微信授权联调及官方 SDK 不可变版本收口待完成。没有部署平台或推送 SDK。

本阶段知识审计 `fl.cmd kno audit --project . --base HEAD` 通过，nextAction为none；日志 `.fenleng/identity-ui-knowledge-audit.log`。

## 追加请求复核

针对 Owner「微信登录也实现一下」再次核对当前入口与真实交换路径：App 设置账号页调用官方原生身份 SDK，再由 FlutterAuthSDK 交换平台会话；小程序账号页使用 Taro.login 和 TaroAuthSDK。Android WXEntryActivity、iOS URL scheme 和 HarmonyOS weixin queryScheme 均在工程中。保持免登录本机使用，不因登录迁移或清理库存。

本次定向复核：Flutter identity_session、identity_storage、account_layout、bootstrap 四份测试共 13 项全部通过；小程序 identity 9 项全部通过，TypeScript typecheck 通过。首次 Flutter 命令误填不存在的 account_page_test.dart，已改为实际 account_layout_test.dart 后完整重跑通过。此记录不替代正式 Provider 联调或三端设备验收，也不把此前各阶段 APK 哈希称为本次新构建。

源码登录链路已具备，正式移动应用/小程序 AppID、平台客户端登记和 iOS Universal Link 等仍待配置；按身份配置交接文档启用后，再验证真正微信回跳及平台响应。当前配置关闭时显示本地化提示，不能宣称真实微信登录已验收。SDK 候选尚未固定发布版本，最终交付仍需完成该依赖收口。

追加原生边界复核：wechat_authorization_test.dart 新增4项通过，直接使用官方MethodChannel身份SDK验证配置→可用性→一次性授权码顺序、空配置不调用原生、未安装不发起授权、取消/拒绝/超时本地化错误及再次尝试；定向Dart analyze无问题。它使用模拟原生通道，不能替代实际微信客户端/平台会话验证。统一撤回对迟到微信回调的封闭与会话文件保护见privacy-withdrawal-evidence.md。
