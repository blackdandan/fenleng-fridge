# 小程序统一隐私撤回与法律阅读

承接已批准WP03。默认使用独立 pages/legal/index 原生小程序页面承载 WebView，保留系统返回；不在首页逻辑路由中直接放铺满页面的 WebView。正式站仍须部署并登记业务域名。FRIDGE_LEGAL_WEB_ENABLED=false 仅用于明确选择的开发离线正文预览，不能把 RichText 称为原生 WebView。

已同意且阅读隐私时，网页尾部以应用当前语言显示撤回链接。网页只发送包含本次阅读nonce的 withdraw-privacy 消息，并请求返回上一小程序页面；小程序校验当前文档、当前同意状态、nonce与动作后，仅显示二次确认。协议/同意前阅读/过期或无效消息不触发确认。普通官网不显示该入口、不加载微信JS SDK。20语言按钮资源复用共同159key真相源，不增加分析独立开关。

原生微信桥API尚未实机验收。本地协议依据[Taro 4.x WebView文档](https://docs.taro.zone/docs/components/open/web-view)：WebView铺满页面，onMessage在后退、销毁、分享等特定时机投递，因此使用独立页面和返回后确认。尝试读取微信官方组件页时连接不可用；没有用社区文章替代官方平台验证。网页JS SDK加载失败、非小程序环境显示已有本地化错误并保持按钮禁用。

确认后控制器立即离开ready并停本地到期轮询；共享身份所有者立即取消原生登录代际、暂停刷新并撤回SDK consent。先持久写入fridge.privacy.withdrawal.v1，再移除同意记录；等待旧SDK操作/反馈关闭，清理官方SDK三个确切本产品Token键，最后清除pending才返回同意页。冷启动先恢复pending，再决定是否读取库存或创建SDK。失败显示独立重试页，accept不能从清理失败状态绕过恢复。首次marker写盘本身失败时，当前进程暂停在线服务，但未持久成功的意图不能保证在强杀后恢复，需重试成功。

库存、照片、显示偏好、已落盘反馈草稿保持独立。旧反馈模型关闭后才创建新模型，防止重新同意后迟到ACK写入新会话；旧微信code被取消代际拦截，不影响新游客会话。SDK撤回使用localOnly，不新增logout HTTP。尚未实现的服务端订阅提醒取消仍须在WP06接入，不能以停止本机轮询宣称已经取消服务端发送。

验证：当前小程序70项单测一次全通过（原61项+撤回相关9项），TypeScript与domain/application边界通过，weapp成功编译3个原生页面；20语言159key与资产/编译路由检查通过。common.js约401KiB，webpack244KiB体积建议仍在。日志 .fenleng/mini-privacy-final-{full,typecheck,boundaries,build,source-check}.log。

本地Chromium桥接验证20语言窄屏按钮及6类普通页/前同意/协议/nonce/SDK失败/非小程序保护分支，通过；使用模拟微信JS SDK，仅验证网页协议，不是微信原生投递或Provider成功。报告 ../../evidence/website/mini-legal-bridge-results.json，中文与阿拉伯语320宽截图已检查。官网完整APK下载字节/SHA仍匹配既有0dea646e...调试包，本阶段不修改APK或上游SDK。

仍待Owner正式AppID、业务域名/fridge.fenlengtech.com部署及微信开发者工具/真机验证：两种返回、postMessage时序、重复打开、取消/确认、故障恢复、RTL/大字和统一同意后的在线服务。没有上传或发布小程序，未把源码/浏览器检查当作原生UI保真。

本阶段项目知识审计pass、nextAction=none，日志.fenleng/mini-privacy-knowledge-audit.log。原SDK候选与安装文件来源未更改；本阶段没有发布平台、SDK或提交推送。

后续WP06已把服务端提醒取消接入privacyCleanup并等待ACK，旧文“尚未实现取消”为本隐私阶段历史状态。取消失败保留withdrawal-error/pending，认证存储封闭后仍可重试，重启在读库存前恢复；真实SDK/控制器集成及91项消费者回归通过，见[subscription-reminders.md](subscription-reminders.md)。正式平台/微信原生仍待配置验收，不将本地停止或替身ACK称为公网取消。
