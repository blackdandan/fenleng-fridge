# 鸿蒙原生能力与产品功能一致性

Flutter-OH 基线只保证运行时来源一致；产品必须逐项落实插件、原生权限、同意后初始化和运行行为。构建成功不能替代功能覆盖。

## 固定插件来源

优先保持 Android/iOS 的现有插件及版本，仅新增 OH 联邦实现，在隐私同意后的应用初始化注册其 Dart 平台实现。独立插件必须声明在实际 App pubspec，原生插件注册也必须在同意后执行。Git ref 固定完整 commit，禁止浮动 master/release 分支和本地 path 作为最终交付依赖。

| 能力 | 鸿蒙实现 | 固定 commit / 路径 |
| --- | --- | --- |
| 文件目录 | CPF-Flutter/flutter_packages path_provider_ohos | d4e49daa0acbd0bc419d58b1da27d64d44fab54b / packages/path_provider/path_provider_ohos |
| SQLite | CPF-Flutter/flutter_sqflite sqflite_ohos | 5ef0761001378455e872e46d1c0620d39dcc1002 / sqflite_ohos |
| 文件选择 | CPF-Flutter/flutter_packages file_selector_ohos | 05111855c6772411f39d10aac43c8a276251c1d3 / packages/file_selector/file_selector_ohos |
| WebView | CPF-Flutter/flutter_packages webview_flutter_ohos | e0bff59d8e503c356f854181b38ac409525418fd / packages/webview_flutter/webview_flutter_ohos |
| 外部链接 | CPF-Flutter/flutter_packages url_launcher_ohos | ae4494a78db5a9e0fe760b0eba9231605ae45716 / packages/url_launcher/url_launcher_ohos |
| 权限 | CPF-Flutter/flutter_permission_handler permission_handler_ohos | c93847f008e387647311f4036bc705a4fc0b9560 / permission_handler_ohos |
| 二维码 | CPF-Flutter/fluttertpc_mobile_scanner | f5a4ff52f003e1645db1d4de743a2db0313665a8 / 根目录 |
| 系统分享 | CPF-Flutter/flutter_plus_plugins share_plus | bfd882da6893c4c8bfa1648ac637c2d557e6f4fa / packages/share_plus/share_plus |

这些固定来源在产品中的构建和运行记录必须单独保存；表格不是插件所有 API 已支持的承诺。share_plus 的传递 path_provider 指向 master，消费项目需明确统一来源；独立 path_provider_ohos 可与 hosted path_provider 配合，不能让解析器同时使用两个来源。

## 需要补充的行为

- file_selector_ohos 当前未实现 getSaveLocation：保存文件使用原生 DocumentViewPicker.save 取得 URI，再以 fileIo 写入。不能将授权 URI 当作 Dart 文件系统路径；必须处理取消、部分写入、资源关闭和写入失败。
- 文档扫描使用 VisionKit DocumentScanner（裁切、滤镜、多页、相册）；二维码库不能替代文档扫描。将输出 URI 原生复制到应用目录后返回本地路径给原业务。保留取消、并发请求和退出清理。
- 相机 CAMERA 权限必须有用途字符串及 usedScene；在用户主动进入功能时走现有用途说明和权限请求，不能在启动时主动申请。
- 必须检查数据库 CRUD/事务/重启持久化、文件导入导出再导入、法律网页与导航、分享文件、扫码取消及再次打开。原生不支持的调用不能无提示吞掉或改为空功能。
- 鸿蒙不需要 Firebase/Google/Apple 身份：不初始化、不校验其配置、不展示其入口；邮箱及微信身份按产品方案保留。
- 微信当前按 Owner 要求不人工验证；支付宝收银台成功调起即满足本阶段支付验证，不要求新增真实交易。

## 验证与交付

实现、编译验证、模拟器运行验证、人工真机验证分别记录。需要真机的相机画面、裁切效果、分享目标、打印设备等写“人工验证”，但必须先完成实际实现与构建。最终交付安装至 OH 模拟器的签名包，记录 bundleName、版本、安装结果和启动结果；不以旧 HAP 或旧安装替代新实现。

## 原平台依赖与构建时序

微信 identity/payment Android 统一 `com.tencent.mm.opensdk:wechat-sdk-android:6.8.34`，不混入 `wechat-sdk-android-without-mta` 的重复命名空间。iOS identity 使用 `OpenWeChatSDKNoPay:2.0.5` 并声明 static_framework，与既有 fluwx_no_pay 共用同一框架；iOS 订阅支付保持 StoreKit。不能通过放宽 Manifest/CocoaPods 校验消除重复 SDK。

同一产品的 Flutter pub get、Android/iOS/OH 构建串行执行：这些命令会改写各平台生成注册文件。fluwx_no_pay HAR 实际模块名为 fluwx 时，消费工程须同步修正 Hvigor node/override/dependency，并在 FlutterTask 后、CompileArkTS 前修正生成导入，不能只在初始配置时替换。最终交付以统一 Git ref 下重新构建的包为准。
