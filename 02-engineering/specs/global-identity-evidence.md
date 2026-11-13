# 全球认证：Provider、原生初始化与客户端装配

## 2026-11-13 客户端装配增量

本节更新下方历史基础阶段的待开发状态。现已装配全球功能触发式联网同意及原生持久记录、Google/Apple 账号入口、官方 SDK 平台会话交换、FIREBASE 注销重新认证、退出及撤回。global 首页保持本机使用；账号/反馈入口共用一次默认未勾选的协议确认。配置缺失呈现可重试的真实未配置状态，不模拟成功。

`flutter-global-final-runtime.log`：26 项全部通过、无跳过，包括 10 项 Provider 控制器、8 项全球身份集成、4 项真实 Bootstrap 生命周期、3 项实际 App 同意交互、1 项覆盖 20 语言×2 主题×7 状态的 280 布局组合。Provider 原生端口与 HTTP 为明确替身，未证明真实 Google/Apple 授权。覆盖旧注销响应不能替换重新同意后的反馈实例、撤回后的迟到原生证明不能建立平台会话、协议写入失败重试及重启恢复。

`flutter-global-final-analyze.log`：18 个指定文件无问题。此前集中 App 回归 `flutter-global-stage-full.log` 为 163 通过、6 个仅 global 启用的用例跳过；该回归早于最后的旧注销响应隔离修正，不能代替上述最新定向结果。小程序新增至 199 文案键后 typecheck、架构边界检查通过，weapp 构建日志保留 common.js 574 KiB 性能警告。

数据清单见 [global-sdk-data-inventory.md](global-sdk-data-inventory.md)。法律草案已更新并同步 App 离线 WebView、小程序及静态预览正文；未正式生效。iOS URL scheme 有明确未配置默认值，实际公开配置和 Xcode/真机验证交接 Owner。Android 新构建结果另行记录，不能以旧 APK 安装成功代替本阶段源码验证。服务端 Firebase/Apple 登录与注销并发、Firebase 用户清理及最终干净消费者打包仍由 Agent 继续核验。

## 历史：原生基础阶段

属于已批准WP03/WP05的渠道隔离与账号能力，整体仍in-progress。2026-11-13本阶段完成Provider控制器、实际FlutterFire/Google驱动、配置及Android/iOS延迟注册源码。**尚未装配Bootstrap、全球账号UI、联网同意和注销gateway，不称global登录已可用。**这些仍由Agent继续开发，不能改称Owner配置待办。

新增`global_firebase_identity.dart`：默认关闭的本产品配置、明确global/Android/iOS校验、禁用或占位时不初始化SDK；只有显式动作通过已持久同意回调后初始化。使用命名Firebase App `fenleng-fridge-global`和本产品projectId，Google原生用官方google_sign_in，Apple用FlutterFire AppleAuthProvider。Firebase ID token由既有官方Fenleng FirebaseAuthIdTokenSource强制刷新取得；控制器只返回临时proof，不创建平台会话或保存Provider凭据。后续由官方FlutterAuthSDK换平台会话。

注销重新认证走currentUser.reauthenticate，不能用普通登录替代；核对重新认证前后同一Firebase UID，不把getIdToken强制刷新当用户重新确认。120秒超时结束UI等待，但保留原生授权lease直至迟到回调和本机清理结束；同命名App的新控制器不能在旧流程未清理时另开授权。撤回和关闭封闭迟到proof；本机清理失败可重试，成功关闭幂等，旧关闭不会再次清除新会话。

Android新增DeferredPluginRegistrant：local组仅相机/相册/权限/lifecycle及china微信，Firebase/Google只在plugins.initializeOnline独立入口注册。该入口要求businessAllowed、activeReleaseChannel/global、当前V0.4的持久global记录、acceptedAt且无withdrawalPending。移除FirebaseInitProvider，避免仅引入依赖就提前初始化。iOS对应FridgeDeferredPluginRegistrant已加入Xcode Sources，使用生成清单的真实类名；同样分local/global并检查原生记录。中国原生Apple直验入口不允许global调用。

依赖：官方Fenleng Firebase桥接包固定基线334611afbd9ae4be95771159a5cd00dc6f0ba31f；Firebase Core4.13.0/Auth6.5.7、google_sign_in7.2.0；锁文件记录13个新增/变化项。按实际Firebase Podspec最低要求，iOS Podfile/三个PBX部署目标同步15.0。当前新增第三个SDK本机路径覆盖，仍是未发布候选，不把干净远端消费者称已验证。Dart pub get已通过。

固定OH整套pub/平台生成会因本机没有Harmony SDK受限，新增本项目`refresh-mobile-plugins.dart`调用同一固定Flutter源码的refreshPluginsList/injectPlugins，仅生成Android/iOS元数据。未手改生成文件、伪造Harmony目录或修改共享Flutter缓存；实际generated registry用于对照，Android编译通过。

本阶段验证：10项Provider控制器定向测试、定向analyze无问题；Android `:app:compileDebugKotlin :app:processDebugMainManifest`通过，143任务。实际合并Manifest不存在FirebaseInitProvider；Android/iOS生成清单与手写分组插件集合一致。源码清单检查不是iOS编译或原生运行证据；测试用明确的原生端口替身，不是真实Firebase/Google/Apple授权。依赖包namespace弃用及既有LocalReminders空值警告保留，未修改Pub缓存。本阶段不重复执行全App回归/知识审计；完整global装配完成后集中做。

配置模板位于`03-deployment/config/firebase-global.example.json`，enabled=false且无真实配置值。正式产品Firebase项目、各端App ID、GoogleOAuth客户端、iOS反向URL scheme与Apple能力/Provider/平台audience交由Owner后补；缺配置不声称登录成功。当前官网与Owner模拟器保持上一轮预览；本阶段没有生成或安装新APK。

SDK远程知识查询对锁定ref返回REF_NOT_FOUND；本机git cat-file确认该提交存在，并以git show读取该提交的Firebase桥接源码，证据sourceMode=local-git-blob。不将远程失败记录成MCP冻结成功。

官方技术依据：[Flutter Firebase初始化](https://firebase.google.com/docs/flutter/setup)、[Google/Apple登录与重新认证](https://firebase.google.com/docs/auth/flutter/federated-auth)、[Android自动初始化Provider](https://firebase.google.com/docs/reference/android/com/google/firebase/FirebaseApp)。实际实现按本机已锁依赖源码再次核对；联网文档不是本产品真实Provider配置证据。

下一步：实现global功能触发处的联网协议确认和原生持久记录、装配唯一身份/反馈/埋点消费者、Google/Apple同等级入口、FIREBASE注销重新认证、撤回和后台互斥；然后集中渠道/布局/运行回归和新构建。Harmony没有该官方Firebase插件实现，不假设Google服务可用，继续保留本机能力与明确受限状态，并在最终能力矩阵中如实交接。
