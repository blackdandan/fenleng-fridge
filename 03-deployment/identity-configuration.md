# 身份配置与验证交接

2026-11-13 当前状态更新：下方保留接入阶段的历史说明。global 的联网协议、Google/Apple UI、平台会话交换、FIREBASE 注销证明、退出和撤回已装配并在独立源码候选中通过26项验证；真实Provider成功仍待正式配置。Flutter/小程序的七类埋点、游客、反馈和账号生命周期源码已接线，默认不启用生产请求。Firebase远程用户清理候选也已装配，46项相关本地验证通过；仅登记到受管集合的产品才调用，正式服务器凭据参见 config/firebase-cleanup-server.example.json。软件已实现部分不得继续记为Owner开发待办。

交付候选现在可随源码附带三份官方Flutter SDK候选，并用归档专用override解析包内vendor，无需同级SDK工作区。候选基线与逐文件哈希见归档内 candidate-provenance.json；它不等于SDK已正式发布，当前项目正式Git依赖及生产部署保持独立。独立目录依赖解析、App165项（默认渠道另7项跳过）、显式global26项与核心17项通过，范围和归档哈希由交付候选证据记录。

所有值均属于 fenleng-fridge。本文件无 Secret；AppSecret 仅进入 Shared Platform 服务端与既有 Vault，不能传给 Flutter/Taro 编译器。当前所有真实登录配置默认关闭、空值，不借用其他产品 AppID。

| 参数 | App | 微信小程序 |
| --- | --- | --- |
| `FRIDGE_IDENTITY_ENABLED` | Dart bool define；默认 false | 构建环境字面 `true` 才启用 |
| `FRIDGE_GUEST_ENABLED` | Dart bool define；默认 false；同时需 identity enabled 与有效平台配置 | 构建环境字面 true 才启用；同时需 identity enabled、正式平台部署/登记 |
| `FRIDGE_TELEMETRY_ENABLED` | Dart bool define；默认false；仅在平台幂等候选部署、事件目录及权限登记后启用 | 尚未接产品遥测，不启用 |
| `FRIDGE_PLATFORM_URL` | 已登记 Shared Platform HTTPS 基址，待确认 | 同左，需列入 request 合法域名 |
| `FRIDGE_PLATFORM_CLIENT_ID` | 逐端登记 `fenleng-fridge-android` / `fenleng-fridge-ios` / `fenleng-fridge-ohos` | `fenleng-fridge-miniapp` |
| `FRIDGE_WECHAT_APP_ID` | 微信开放平台本产品移动应用 AppID | 在 project.config.json 配本产品小程序 AppID |
| `FRIDGE_WECHAT_UNIVERSAL_LINK` | iOS 登记 `https://fridge.fenlengtech.com/app/` 后使用；待 AASA/TeamID 校验 | 不适用 |

applicationCode 固定 `fenleng-fridge`，须由平台登记落实，客户端字符串本身不构成已登记证据。移动应用与小程序分别登记 Provider/clientId/AppID，不能仅因使用同一产品就混用授权码或 Secret。

游客本地候选还需平台部署 `/auth/guest/login` 并显式启用 HTTP 开关，ACTIVE 应用登记 guestLoginEnabled、专门 ACTIVE guestRoleCode，以及同应用 ACTIVE PUBLIC 客户端；不要直接授予默认成员角色。按现有平台恢复/注销契约工作。游客失败保留本机使用；微信账号切换不隐式合并游客或云同步库存。配置步骤本身不代表平台已经完成登记。

Android 的 manifest AppID 从 Dart define 同源生成；正式签名公开指纹见 `../05-knowledge/signinfo/application-signing-info.json`，禁止重建签名来绕过后台不匹配。回调为 `com.fenlengtech.fridge.wxapi.WXEntryActivity`。

iOS Bundle ID 为 `com.fenlengtech.fridge`；Xcode 的 `FRIDGE_WECHAT_APP_ID` build setting 必须与 Dart define 一致，Owner 后补 Team/Profile、微信 URL scheme、Universal Link/AASA 和 Apple Sign in Capability。China Apple proof 由平台直验，不依赖 Firebase；global 的 Firebase 分支尚未完成，不可当成该渠道可用证据。

App 源码当前消费同级 SDK 候选路径；最终构建前须按 WP05 证据固定发布 commit，移除临时 overrides，执行干净依赖解析。部署平台、发布 SDK、申请开放平台应用均保留为独立动作，当前未执行。

App埋点版本上下文使用FRIDGE_APP_VERSION（默认0.1.0）、FRIDGE_BUILD_NUMBER（默认1），应与pubspec/打包版本一致；发布渠道沿用APP_RELEASE_CHANNEL，语言取当前应用设置。当前APK所有生产身份/遥测配置默认关闭。后台仅等待2秒flush，已开始请求可能继续到SDK超时；不能声称撤回能撤销平台已经接收的数据。

onlineConsent要求业务ready且已持久接受当前V0.4/渠道；global本机首页ready本身不表示联网同意，未接受时不创建身份/反馈/遥测SDK。global完整在线同意/身份UI仍未交付，不能仅打开构建flag就称global登录和分析可用。App中国隐私政策撤回入口及pending恢复已实现，阶段证据见../02-engineering/specs/privacy-withdrawal-evidence.md；mini/global完整撤回仍未完成。

global Provider基础阶段现已补FlutterFire/Google驱动与Android/iOS独立延迟注册，10项定向控制器、Android Kotlin/合并Manifest及源码清单检查通过；仍未接Bootstrap/全球联网同意/账号UI和注销，不能仅打开flag声称可用。配置模板见`config/firebase-global.example.json`，默认关闭。Firebase项目须本产品独立`fenleng-fridge-*`命名；逐端APP_ID、API_KEY、MESSAGING_SENDER_ID、Google server/iOS client ID均为客户端公开配置，服务端私钥仍不进客户端。iOS正式Google反向URL scheme和Firebase/Apple Provider/audience需同时落实。实际锁定Firebase SDK要求最低iOS15，工程已同步；Xcode/设备交接仍由Owner验证。详见`../02-engineering/specs/global-identity-evidence.md`。

真实联调依次验证：未配置提示、微信未安装、成功回跳、取消/拒绝/120秒超时可重试、服务端拒绝/断网、退出与重启会话恢复、本机库存不变。iOS/iPad 另验 Apple 及微信两入口。测试 code、虚构 token 和模拟器不可替代真实 Provider 成功证据。
小程序法律阅读：FRIDGE_LEGAL_WEB_ENABLED默认true，使用独立pages/legal/index载入https://fridge.fenlengtech.com/terms/或/privacy/；须部署当前web/dist并在正式微信后台登记业务域名（不是仅request域名）。false仅为开发离线正文预览。网页发回本次阅读nonce和请求动作后，小程序仅弹二次确认，不直接撤回。微信JS SDK消息/返回时序须开发者工具和真机验证，当前本地浏览器使用模拟SDK。正式配置后按../02-engineering/mini-program/pages/privacy-withdrawal.md验收。

小程序产品埋点：FRIDGE_TELEMETRY_ENABLED=true且FRIDGE_IDENTITY_ENABLED=true时才允许官方SDK上报；默认关闭，不是独立用户分析开关。须在平台登记MVP七事件及游客/账号权限，使用统一隐私V0.4门禁。离线/未知ACK复用同批同键，401不会以新游客重放。消费SDK现分别锁定core/Taro本地候选SHA，最终仍需完整Git commit收口。
