# web

静态官网 `fridge.fenlengtech.com`，保留已验收预览的版式、Forest色彩和原始照片素材，不含业务Web客户端或自建后端。当前是本地开发预览，未部署该域名。

源码在src，构建/预览脚本在scripts，独立静态产物在dist。首次构建先执行npm ci，使用仓库内固定SHA的官方SDK候选包和锁定的esbuild；部署dist不需要Node或服务端依赖。遵循 [coding-guide](../../02-engineering/coding-guide.md) 与 [architecture](../../02-engineering/architecture.md)。

从本目录执行 `npm run build` 自动保留已登记并通过核验的APK。显式指定工具路径时，从仓库根执行：

```powershell
node 06-project/web/scripts/build.mjs --android-apk 06-project/app/apps/fridge/build/app/outputs/flutter-apk/app-debug.apk --aapt D:/Documents/Android/Sdk/build-tools/36.0.0/aapt.exe --java 'D:/Development/Program Files/Java/jdk-17/bin/java.exe'
node 06-project/web/scripts/check.mjs
node 06-project/web/scripts/serve.mjs
```

工具路径按机器实际安装调整。安装包构建必须沿用项目标准打包入口；网站脚本只读取并核对APK，不创建或轮换签名。提供APK时校验其登记SHA、真实manifest包名/版本及注册固定签名。版本、字节数与SHA进入release.json和页面，明确标识debug-preview，不能视为正式加固发行包。

本地预览默认 [http://127.0.0.1:4817/](http://127.0.0.1:4817/)，只绑定本机；可设置FRIDGE_WEB_PORT。预览服务支持HEAD、Range和APK正确MIME。下载未在微信内启动时，页面提示改用系统浏览器；没有微信设备验证证据，不保证各微信版本内部下载行为。

首页、/terms/、/privacy/、/app/为静态页面；/app/只作版本入口，不假装已配置Universal Link。iOS/iPad、HarmonyOS NEXT、WeChat Mini Program尚未发布，均无安装链接。

界面20语言：src/locales含34个官网专有key，另复用产品公共文案。设备语言首次解析，用户选择持久化，可回到系统语言；Arabic启用RTL。法律正文保留同一V0.4中文草案并标明语言/未生效，不冒称已完成20语言法律全文翻译。匿名分析默认关闭；启用后先取得独立于App记录的统一协议/隐私同意，再懒加载官方匿名SDK。没有独立分析开关，不调用身份接口。

网站/APP备案号目前均为待登记占位，不复制其它产品号码。运营主体和联系信息来自既有组织资产，邮箱fenlengtech@163.com。正式发布前按实际SDK、服务及生效日期复核法律正文和备案，不把当前预览当线上状态。

浏览器QA使用独立临时工具依赖，运行步骤见 [官网阶段证据](../../02-engineering/specs/website-implementation-evidence.md)。80组语言/宽度/大字检查、5张截图及完整HTTP下载SHA检查已通过；这不是移动系统安装或微信实机证据。

普通npm run build现自动使用implementation-status中已验证APK，按ANDROID_HOME/ANDROID_SDK_ROOT与JAVA_HOME寻找aapt/Java，重新核验版本、固定签名和SHA后才替换dist。仍可显式传--android-apk/--aapt/--java；有意只构建无安装包页面时使用npm run build -- --without-android及npm run check -- --without-android。没有APK时检查会明确写未验证下载，不再无条件报告APK校验成功。

匿名分析构建配置：FRIDGE_WEB_TELEMETRY_ENABLED=true、FRIDGE_PLATFORM_URL=https://实际平台地址、FRIDGE_WEBSITE_CLIENT_ID=已登记的公开官网客户端ID。只传公开配置，不能传AppSecret或登录Token。缺有效地址时启用构建失败；默认关闭不加载SDK。正式启用仍需平台服务、匿名客户端及CORS部署验证。

同意入口在启用分析的官网首次访问显示，暂不同意仍能浏览/下载；页脚可重新打开统一条款并撤回。不会继承App同意或在同意前补记历史点击。小程序法律WebView的?mini=1不显示官网同意组件、不加载官网分析。事件仅fridge.website.preview.opened.v1，属性target=app；实际请求credentials=omit，无Cookie、Authorization、会话或设备标识。SDK故障不阻断下载。详见[匿名分析阶段证据](../../02-engineering/specs/website-anonymous-evidence.md)。
