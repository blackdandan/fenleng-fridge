# 官网下载构建回归与恢复

原计划继续官网匿名分析，检查时发现实际回归：上轮法律正文刷新调用普通npm run build，原构建器只在显式--android-apk时复制APK，因而把已有下载入口改为未发布。旧check.mjs只在release.android存在时验包，却无条件打印“完整APK字节/SHA通过”。上轮该结论过度，原日志保留并在mini-product-telemetry-results.json与对应Spec中更正；不能拿它当下载证据。

本轮先用显式参数恢复原固定签名调试包，再修复默认行为：有passed APK记录时普通构建自动读取该路径；aapt由ANDROID_HOME/ANDROID_SDK_ROOT寻找，Java由JAVA_HOME或PATH提供，也保留原显式覆盖参数。版本、包名、签名与字节SHA预检在替换dist之前执行，APK不匹配或缺失不会破坏现有网站。原有固定签名核验规则保留，没有新增凭据/Owner发布审批策略。

确实只想生成无安装包页面时显式--without-android；它不能与APK覆盖同时使用。检查器默认要求已经登记的APK下载存在，明确省略时才接受无APK页面，而且会输出“下载未验证”，不再无条件成功。未曾有passed APK记录的新项目仍可无安装包预览，不要求Android工具链。

5项隔离临时文件测试通过：普通构建选择记录、版本/签名元数据、文件缺失/变化、显式省略/参数冲突、不同签名及早期无包工程。真实普通npm run build（无APK参数）与检查通过。另实际运行错误APK路径构建，确认失败且原release.json和APK仍存在且不变；只证明APK预检失败的保留行为，不声称所有构建失败都具备事务回滚。

当前本地服务http://127.0.0.1:4817/已有下载按钮。带WeChat User-Agent的真实完整HTTP下载184867411字节，SHA256=0dea646e952d9e1f34a6d0d3fff486fa5f2040f5ccf63ca2ed0bbcd061cf7235，200、application/vnd.android.package-archive、attachment文件名和Content-Length均匹配。真实Chromium点击下载再次校验完整字节/哈希，390px下载区截图已查看。伪装UA不等于真实Android微信浏览器；域名/TLS部署、微信设备的安全提示/浏览器转出/安装仍按Owner待办，不伪称完成。

本阶段未重打APK、未操作用户正在查看的模拟器。源码的新增语言key/离线法律正文已经领先此开发包，implementation-status如实标sourceAheadOfApk，待最终打包收口。官网匿名分析的SDK及服务端合同已定位，尚未接入；不得用本修复缩小整体目标。

证据：../evidence/website-download-recovery-results.json，以及website/download-recovery-http.json与当前浏览器下载报告。这里使用现有开发预览，不是最终完整/加固发行包或上线证据。
