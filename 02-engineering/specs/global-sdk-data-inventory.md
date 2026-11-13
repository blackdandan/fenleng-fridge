# App 全球认证 SDK 与数据清单

本清单记录当前源码候选，不代表真实服务已启用，也不代替正式隐私政策审核。配置默认关闭；正式配置、服务端部署和真机授权验证完成前不得把测试替身结果写成登录成功。

| 组件 | 锁定版本/来源 | 用途与数据 | 初始化时机 |
| --- | --- | --- | --- |
| Firebase Core | 4.13.0，App pubspec/工作区 lock | 初始化本产品命名 Firebase App，使用公开客户端配置 | global 用户在联网功能确认协议后，显式登录时 |
| Firebase Authentication | 6.5.7 | Google/Apple 授权后的 Firebase UID、ID token、Provider 返回的账户资料；依赖及服务可能处理网络、设备和诊断数据，实际披露以官方说明及最终配置为准 | 同上；注销证明使用同一用户重新认证 |
| google_sign_in | 7.2.0 | Google 账户选择和授权凭据；不在产品代码中另存 Provider 密码 | 同上，仅 Google 动作 |
| Fenleng Firebase identity 桥 | SDK 基线 334611afbd9ae4be95771159a5cd00dc6f0ba31f；当前本地候选覆盖 | 强制刷新 Firebase ID token，交官方认证 SDK 换 Shared Platform 会话 | 已有持久联网同意且用户触发授权后 |
| Fenleng Flutter / native identity | 同一 SDK 基线，当前本地候选覆盖 | 平台游客/认证会话、反馈、认证事件；中国渠道微信原生证明，iOS Apple 原生证明 | 受渠道与持久同意控制；global 不走中国原生 Provider 直验 |
| camera / image_picker | 0.12.0 / 1.2.4 | 用户主动拍照或选图；产品照片保存在本机，不新增业务照片上传 | 本机功能及独立系统权限允许后 |

Android Manifest 移除 FirebaseInitProvider；手写延迟注册与生成插件集合对照。iOS 有对应延迟注册源码，最低部署版本 15.0；Windows 无法提供 Xcode 编译或设备授权证据。没有接入 Firebase Analytics、广告或支付 SDK。

首次全球首页只使用本机库存能力；进入账号或反馈等联网入口才展示共享协议确认，复选框默认未选。联网同意不替代相机、相册和通知系统权限。中国渠道仍使用首次进入前的协议步骤。法律正文由现有离线 WebView 展示，联系邮箱 fenlengtech@163.com。

退出清理平台会话和已初始化 Provider 的本机缓存；普通关闭页面/应用不会被当作退出。撤回同意封闭迟到回调，并清理本机联网会话，保留库存与照片。产品账号注销与删除原 Google/Apple 账号不同：服务端七天待处理回执不代表物理删除已经完成。平台已补受管产品的 Firebase Auth 用户清理候选及并发账号锁，46项相关本地测试通过；真实服务配置、部署与实际删除尚未验证，不能把本地替身结果当成真实用户已删除。

Owner 后续配置：独立 Firebase 产品项目、Android/iOS App ID、Google OAuth 客户端及签名指纹、Apple Provider/能力、iOS URL scheme 和 Shared Platform 对应客户端。iOS `Flutter/IdentityDefaults.xcconfig` 的未配置 scheme 只是可构建占位；实际 `FRIDGE_GOOGLE_REVERSED_CLIENT_ID`、`FRIDGE_WECHAT_APP_ID` 由真实公开配置替换，不包含 AppSecret。当前未证明真实 Provider 成功，也未证明 SDK 本地覆盖移除后的远端消费者可构建。

依据：项目 pubspec/lock、实际驱动与原生注册源码；[Firebase 隐私说明](https://firebase.google.com/support/privacy)、[Firebase Android 数据披露](https://firebase.google.com/docs/android/play-data-disclosure)、[Google Play services 数据披露](https://developers.google.com/android/guides/play-data-disclosure)。正式隐私政策仍为 V0.4 草案，不能从组件存在推导服务已收集某项用户数据。
