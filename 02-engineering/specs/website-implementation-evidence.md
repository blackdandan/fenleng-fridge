# WP07 官网本地实现阶段

已承接Owner验收的06-project/prototype/website版式与素材，在06-project/web实现静态官网。通过Sites本地交付路径工作，未创建外部Site、同步源码、修改DNS或部署。完整项目目标/WP07仍进行中，最终源码归档和正式发行仍待收口。

## 页面和真实状态

首页有照片库存示意、照片入库/四状态整理/周期检查介绍、本机数据边界、各端下载状态、主体联系与底部备案；示意照片不是用户库存或首装种子。保留原批准Forest色值与PNG字节，没有引入新的视觉方向。

/terms/、/privacy/直接带同源V0.4离线HTML正文，去除重复h1，不依赖JS请求后才可阅读。界面20语言、31个新key和复用公共key，支持首次解析/选择持久化/跟随系统/RTL；法律文章本体仍中文，明确标注审阅草案/尚未生效，不能声称法律全文20语言已译完。/app/提供版本降级入口，不尝试未配置的App唤起。

Android下载为固定签名debug开发预览0.1.0（build1），不是最终完整/加固正式包。AAPT读取真实包名和版本；apksigner核对已登记证书，网站复制文件SHA与登记当前包相同。大小184867315字节，SHA-256 `c700b67354356dcc9d3b2522236a18fc7b261610b37b2648d9244c06ee4c0eee`，证书SHA-256 `844fb2a1f368a875b79bf54b8e9859120ce80f9ecc0fbc1538ff41718e3f86e5`。公开release.json和页面均显示真实元数据。

iOS/iPad、HarmonyOS NEXT、WeChat Mini Program无已发布安装入口，显示未发布。AppID不是下载本地APK的前置条件，不能反过来伪造小程序码或商店地址。微信内若无法下载，页面提供系统浏览器提示；真实微信/手机安装仍待设备验收。

官网不导入业务SDK、不创建网站账号、不提交照片/库存或分析事件。Shared Platform游客/反馈/分析仍按接入中如实说明。运营主体/邮箱与法律源一致，网站和APP备案分别占位；未借用其它产品号码。

## 已运行验证

- 构建通过，dist自包含首页、法律、版本入口、资源及经过验证的可选APK。没有真实包参数时的源码逻辑不创建下载链接；本轮浏览器运行验证覆盖含真实开发包的产物。
- scripts/check.mjs检查20语言所有页面绑定、本地链接、脚本语法、V0.4完整正文同源、原始PNG相同、发布状态及完整APK大小/SHA。
- 隔离Chromium：20语言×320/390/1440共60组，加20语言×320/字号200%共20组，合计80组通过；无横向页面溢出、空白/undefined绑定或pageerror。首次en-US、显式选择重载、跟随系统、不可用localStorage、Arabic RTL和法律正文lang/dir已验证；法律表格采用局部滚动布局。
- 键盘首Tab到可见跳过链接，邮件/电话至少44px；下载按钮实际触发浏览器下载，正确APK MIME/文件名、HEAD、206 Range和无效Range416通过。
- scripts/check-download.mjs对实际HTTP GET完整流逐块计算184867315字节和SHA，匹配release.json；不是只检查HEAD或取消后的部分文件。
- 已检查390/1440首页、320 Arabic、320英文200%文字和320法律页截图。首轮200%文字的长词溢出已修正；大字页头品牌断词也已修复。原批准照片素材保持不变。

证据：../evidence/website/browser-results.json、download-results.json及五张PNG；日志.fenleng/website-build.log、website-browser.log、website-download.log。浏览器工具为独立.fenleng/web-qa内playwright1.56.1及本机Chrome，非生产依赖。原Node REPL入口返回kernel路径缺失，使用普通本地Playwright工程测试，没有冒充工具已恢复。

从仓库根重跑：

```powershell
npm install --prefix .fenleng/web-qa --no-audit --no-fund --save-exact playwright@1.56.1
node 06-project/web/scripts/check.mjs
node 06-project/web/scripts/qa-browser.mjs --browser 'C:/Program Files/Google/Chrome/Application/chrome.exe'
node 06-project/web/scripts/check-download.mjs
```

运行浏览器和下载测试前先按web/README构建并启动serve；端口URL可用FRIDGE_WEB_URL覆盖。本地服务仅127.0.0.1:4817，不是fridge.fenlengtech.com上线证据。

## 尚未完成

正式域名/DNS/HTTPS和部署、正式备案、生效法律/翻译审阅、实际微信下载与iOS/Harmony/小程序设备验收、最终完整/加固APK及源码交付归档、网站产品分析接入。当前提供可查看与下载开发预览的官网产物；不能标整体目标完成或正式站已上线。

阶段知识审计 `fl.cmd kno audit --project . --base HEAD` 通过，nextAction=none；日志.fenleng/website-knowledge-audit.log。自有预览服务在本阶段结束前已确认运行，后续复用先检查原session77243，不因观察超时另起重复服务；整体目标结束时清理。

后续App游客/埋点阶段已更新官网本地APK下载，当前SHA/字节以implementation-status.json及evidence/website/download-results.json为准；仍是固定签名0.1.0(1)调试预览。网站CSS/结构没有变化，原80状态矩阵保留原阶段范围；新二进制另做完整HTTP GET SHA256验证，不把旧矩阵当新APK设备证据。未部署域名。
后续小程序法律阶段增加mini-legal.js及20语言桥接标签：仅带mini/withdraw/当前nonce的隐私WebView上下文显示撤回链接并加载微信JS SDK，普通官网不加载该SDK。网页只发消息并返回，实际确认在原生小程序。Chromium20语言+6保护/失败分支通过，模拟微信JS SDK，不是原生投递验证；见evidence/website/mini-legal-bridge-results.json与mini-program/pages/privacy-withdrawal.md。当前APK二进制未改，完整HTTP下载哈希继续匹配；未部署正式站。
