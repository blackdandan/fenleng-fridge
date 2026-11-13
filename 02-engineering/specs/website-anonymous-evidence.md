# 官网匿名分析阶段证据

范围属于已批准的WP07与产品关键埋点要求，保持官网、App、微信小程序的原交付范围。状态validated-with-follow-up，整体目标未完成。

官网使用官方WebAnonymousTelemetrySDK与FenlengBaseClient，源码候选来自fenleng-client-sdk基线334611afbd9ae4be95771159a5cd00dc6f0ba31f。vendor/provenance.json记录两个归档SHA及候选源文件身份；不是已发布的不可变上游版本。业务不另建REST埋点或持久队列。

分析默认关闭。启用后网站有自己持久化的V0.4统一用户协议/隐私同意记录，不继承App记录，不增加独立分析开关。未同意不加载SDK；暂不同意、SDK失败或存储不可写时仍可浏览下载。撤回立即封锁采集、取消旧投递并清空SDK；清除本地同意失败会如实提示重试。跨标签页撤回与延迟SDK加载均按当前同意状态处理。mini=1法律WebView不接入官网同意或SDK。

唯一事件fridge.website.preview.opened.v1，属性target=app；真实下载点击或已同意访问/app/时记录，不回补同意前行为。无身份接口、Token读取、Session或设备标识。官方SDK保留批次与ACK语义，网络失败和错误ACK最多尝试三次，使用相同事件ID、时间、正文与幂等键。页面退出尽力flush，内存队列不承诺退出后必达。

验证命令（06-project/web）：node --test scripts/site-privacy.test.mjs scripts/anonymous-collector.test.mjs scripts/android-download.test.mjs，16通过；npm run build、npm run check通过，APK完整SHA仍为0dea646e952d9e1f34a6d0d3fff486fa5f2040f5ccf63ca2ed0bbcd061cf7235。根目录node .fenleng/check-website-anonymous.cjs使用真实Chromium与实际打包SDK，9项流程、20语言×大字1/2×媒体light/dark共80组320px布局通过。新同意区域边距16px、无横向溢出、按钮至少44px；阿拉伯语大字内容在区域内滚动。媒体模式检查不代表新增官网暗色主题。

浏览器植入合成Cookie和本地Token，拦截实际网络请求确认无Cookie、Authorization，fetch为credentials=omit/keepalive。覆盖拒绝、保存失败、SDK加载失败、跨页撤回、旧请求晚回、新同意、新事件及重试。提供者响应在本机拦截，未向生产发送统计。证据在../evidence/website-anonymous-results.json与../evidence/website/anonymous/；截图已目视检查。

后续：正式平台部署及公开客户端/CORS配置、域名TLS、真实微信设备下载/安装、SDK不可变发布、最终APK与完整源码归档。当前静态包仍默认关闭分析，已登记APK仍是预览包。没有把本地测试等同上线、微信实机或整个WP验收。

候选归档SHA和实际安装文件逐项比较通过：core12文件、web17文件。阶段知识审计fl.cmd kno audit --project . --base HEAD通过，nextAction=none，日志website/anonymous/website-anonymous-knowledge-audit.log。
