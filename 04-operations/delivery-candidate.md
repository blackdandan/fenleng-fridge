# 本地交付候选

状态：公开开发预览已上线，正式发行尚未完成。当前ZIP和哈希以本机.fenleng/deliveries/latest-*.json为准；旧source-delivery-candidate-results.json仅保留各自快照的消费者验证范围。

最新更新：官网候选35efd85c3910已按Owner明确授权发布为公开开发预览，https://fridge.fenlengtech.com/，固定APK下载及完整外网SHA已通过。当前实际发布结果以02-engineering/evidence/website-preview-production-results.json为准；本机最新各ZIP以.fenleng/deliveries/latest-*.json为准，旧aa706/e17d等记录只证明对应快照。发布不改变当前Debug/未加固及法律草案标识，也不代表正式发行或真实微信手机已验收。

Git交付更新：三份已验证的官方Flutter SDK候选也已纳入产品仓库的06-project/app/vendor/flsdk，workspace pubspec.yaml使用同样的相对路径override，解决克隆后缺同级工作区的问题；不再要求本机ignored pubspec_overrides.yaml。候选逐文件哈希与交付包一致，仍不冒充上游正式版本。本机旧覆盖文件保留于.fenleng/pre-commit-pubspec-overrides.yaml作为恢复记录。

| 产物 | 用途 | 限制 |
| --- | --- | --- |
| source-candidate ZIP | App Android/iOS/Harmony源工程、小程序源码、官网源码、产品/工程资料，另带三份官方Flutter SDK候选 | SDK未发布；不含签名私钥/口令、设备缓存和构建输出；正式上游固定提交仍待审阅 |
| weapp-candidate ZIP | 构建后的28文件微信开发者工具导入目录，根目录含project.config.json | AppID仍为touristappid；正式登录/订阅消息需Owner配置与真机验证 |
| website-candidate ZIP | 可独立静态托管的官网目录，含当前Debug APK下载与release.json | 35efd85c3910已发布开发预览；Debug/未加固标识保留，非正式中国发行 |
| 当前签名Debug APK | 本机安装/预览完整本地功能 | 真实Provider/后台配置默认关闭；不是正式加固发行包 |

源码候选的 `SOURCE-CANDIDATE.md` 和 `CANDIDATE-MANIFEST.json` 是入口。`06-project/app/pubspec_overrides.yaml` 仅在归档内指向 vendor/flsdk，SDK候选逐文件哈希与来源登记也在包内。当前仓库保留正式Git依赖，不自动发布SDK。首次依赖解析使用固定Flutter-OH版本的FVM/Dart；已有SDK与Pub缓存被复用，因此该验证不称“全新机器无缓存离线安装”。

独立目录验证命令：

```text
cd 06-project/app
fvm use fltech-oh/62357a93d653bf844f730bb1f4b7cc9e2139d14e --skip-pub-get --skip-setup --force
fvm dart pub get
fvm flutter test --no-pub packages/core/test
cd apps/fridge
fvm flutter test --no-pub
fvm flutter test --no-pub --dart-define=APP_RELEASE_CHANNEL=global test/global_online_bootstrap_test.dart test/global_online_consent_test.dart test/global_identity_session_test.dart test/global_firebase_identity_test.dart test/global_online_layout_test.dart
```

在本机较深的Windows候选目录，`dart test`的frontend_server_client相对可执行路径无法启动；上述固定FVM的Flutter测试入口已实际执行核心17项。未改共享SDK/Pub缓存或降级固定版本。项目`.fvmrc`关闭FVM自动改写旧Melos文件与切换后自动pub；真正的Melos7工作区仍由pubspec.yaml定义。[FVM项目配置说明](https://fvm.app/documentation/getting-started/configuration)支持这些项目级选项。

Android固定签名从既有Vault恢复，不创建第二份身份；见 `05-knowledge/signinfo/application-signing-info.json` 和现有签名脚本。中国release仍须按标准入口加固及指定真机运行门禁，不把模拟器当真机通过该门禁。iOS/Harmony的未验项与接手命令见03-deployment对应文档。正式Provider、平台部署、域名/HTTPS/备案、SDK发布与设备验证归属Owner清单；其余尚未完成的实现/归档收口继续由Agent推进。
