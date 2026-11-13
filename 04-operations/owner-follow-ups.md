# Owner 待办 · 持续更新

本清单承接 Owner 已同意后补的正式配置，不取消其源码实现。未配置时界面必须如实展示不可用或稍后重试，不伪造平台成功。

最新预览发布：Owner已明确批准fridge.fenlengtech.com独立HTTPS开发预览和当前未加固Debug APK，站点已部署；不再把本次预览部署列为待授权事项。正式备案/正式加固发行和真实Android微信验收继续待办。Harmony工具安装及华为账号登录由Owner明确后补；iOS/Mac验证仍按交接文档接续。部署与回滚见../03-deployment/preview-website-runbook.md。

当前平台候选另包含任务崩溃恢复修复：每任务事务覆盖领取/处理/完成回写，6项新增及20项相关测试通过，源码已完成，不转成Owner开发待办。正式平台候选审阅部署时应一并包含；当前未部署，也未自动修改历史生产任务。见../02-engineering/evidence/data-request-recovery-results.json。

| 待办 | 接手时机 | 当前状态 |
| --- | --- | --- |
| 微信小程序正式 AppID、主体认证、合法域名、隐私声明 | 开发者工具正式预览/真机/提审前 | 由 Owner 后补；游客模式工程先可构建 |
| 微信订阅消息模板 ID、字段映射、服务端凭据和可用次数/规则核对 | 真机订阅及实际发送前 | 同步实现客户端/平台链路与测试，配置后补 |
| 微信开放平台移动应用、Android/iOS/鸿蒙登记、回调/Universal Link | App 微信真实授权前 | 可选登录源码先交付，未配置不伪造登录成功 |
| Apple Developer Team、显式 App ID、Sign in with Apple、Profile/签名 | iOS/macOS 真机与归档前 | 同等级 Apple 登录一并开发；macOS/Xcode 验证由 Owner 接续 |
| 本产品独立Firebase项目、逐端Firebase App ID/公开配置、Google OAuth客户端、Apple Provider及平台audience | global正式认证联调前 | 联网同意/UI/注销已装配并通过本地验证；默认关闭模板见03-deployment/config/firebase-global.example.json；当前依赖最低iOS15，真实Provider未验 |
| 鸿蒙工具安装、华为登录、正式appIdentifier及证书/Profile | 原生编译、正式HAP与真机前 | Owner已明确安装和账号登录后补；包名沿用已确认值，正式身份按平台要求登记 |
| Android 真机连接与授权 | 安装/冷启动/中国加固包运行验收 | 已用隔离模拟器验拍摄/相册/持久化；仍需实际设备及加固包验收 |
| App/网站备案、正式发行及真实微信手机验收 | 正式发行前 | 预览官网/HTTPS/固定APK下载已发布并核对完整外网SHA；正式号码待填，Debug预览不代替正式加固包 |
| Shared Platform 正式产品登记/客户端配置、变更部署 | 真实认证、反馈、遥测、订阅消息联调前 | 上游源码补齐已获授权；部署不默认执行 |
| 官方 SDK 候选范围审阅、固定不可变版本 | 最终干净消费者交付前 | 已含Flutter游客/Apple、原生微信回调、Taro游客/反馈；超出最早8文件待答复push问题，本轮未推送。mini显式候选tgz与哈希可本地构建 |
| 埋点平台版本、事件目录与权限登记 | 正式采集启用前 | 认证批次幂等为本地候选，复用24小时作用域记录；须部署后再启用客户端发送。旧平台忽略键，不能只升级SDK就称端到端去重 |
| Firebase受管产品服务端清理凭据、正式部署与既有生产删除批准 | 真正执行到期注销前 | 远程清理候选已实现并本地验证；按03-deployment/config/firebase-cleanup-server.example.json注入既有Vault/环境通道，不向App/静态站传管理私钥；真实删除未执行 |

2026-11-13 交付候选更新：App与小程序账号生命周期、global联网同意/Google/Apple及统一撤回都已接线；下方早期“尚未接入/待开发”段落为历史阶段，不再作为Owner待办。独立Android系统相册替换已验证取消、替换、重启与旧图回收；权限说明430/320已补设计稿关闭按钮并采样。当前源码候选可带三份包内Flutter SDK候选，不依赖同级工作区；正式SDK发布仍需独立审阅。最新App168、显式global26、核心17、小程序128项本地验证通过；首进协议已补安全区、20×200语言资源及原生视觉证据，官网当前下载为0b19e47a开头的Debug APK。真实Provider、微信主机、macOS/iOS/Harmony和中国加固真机检查仍须按实际范围接续。最终归档仍待更新，旧ZIP不代表最新源码；不把此段当整个Epic已完成。

Android 长期签名已由 Owner 授权生成并存入既有 SSH Vault，公开登记位于 `../05-knowledge/signinfo/application-signing-info.json`。不得为后续构建失败重建签名；恢复入口沿用四个 fenleng-fridge-android-* 稳定 Vault 名称。

iOS提醒源码与13个原生测试已准备，Windows未编译或运行；Mac/iPhone/iPad接手按 [iOS通知验证](../03-deployment/ios-notification-verification.md) 执行。重点检查同日分时归组、真实后台送达、时区/重启及60批滚动队列；当前不能称严格后台单卡合并达成。Shared Platform/AppID不是本地通知的前置条件。

App统一隐私撤回的三端源码与恢复路径已补齐，iOS/Harmony还需按 [隐私撤回设备验证](../03-deployment/privacy-withdrawal-verification.md) 完成编译和实际阅读器返回/撤回/重启验证。正式微信登录仍依赖表中本产品配置，本地模拟通道测试不替代微信真实成功回跳。

官网本地预览已在06-project/web/dist生成，含0.1.0(1)真实固定签名Android调试包；域名尚未部署。后续确认正式网站/APP备案号并更新公示项、DNS/HTTPS与正式发行入口，不能直接把当前debug包当已上架版本。真实微信内下载/系统浏览器转出及手机安装仍需设备验证。官网法律正文仍中文V0.4审阅草案，未提供20种法律全文译稿，正式发布前需核对生效文本。操作与验证见../02-engineering/specs/website-implementation-evidence.md。

小程序法律WebView现为默认实现，需正式站部署和微信后台“业务域名”登记（仅request合法域名不够）。开发离线正文预览可显式FRIDGE_LEGAL_WEB_ENABLED=false；不得当作正式WebView验收。正式配置后验证网页消息→原生返回→二次确认及撤回重启恢复。具体证据见../02-engineering/mini-program/pages/privacy-withdrawal.md。法律V0.4第8节仍为原型预览描述，最终交付前还需按真实相机/通知/在线服务状态修订并确认生效稿，不能直接当生产隐私声明。

微信订阅消息的Provider适配器和可信OpenID绑定已落入平台本地候选，包含V54迁移，31项相关测试通过；V54只运行于隔离测试库。后续平台候选审阅/部署需包含该迁移及其余待完成计划/许可/取消服务，不能只填AppID便认定订阅已可用。正式模板应核对模板字段及一次性许可限制，再做微信真机送达。当前没有发送真实消息或启用生产调度。

后续持久核心已加入V55：修订、许可观察、自然日去重、撤销标记、有限重试和结果未确认恢复，29项相关PostgreSQL回归通过。公开HTTP/周期调度/官方SDK/小程序接线仍未完成，不把内部用例当已开放服务。V54/V55均未应用生产；正式候选部署前应一并审阅。取消凭据改为客户端先持久保存随机值、服务端仅存散列，实际主机随机值与退出/撤回取消仍需接线后验证。

HTTP/runtime候选阶段已接通5项接口、独立能力撤销与可选周期调度，默认均关闭；正式部署仍需审阅平台候选及V54/V55。应用模板映射放在metadata.miniReminders，AppSecret继续使用既有服务端微信登记。客户端SDK/小程序尚待接线，不把当前接口测试当微信真实送达。

小程序提醒业务UI/计划日历/退出与隐私撤回取消/消息回跳已接线并通过本地回归。正式配置后仍需微信开发者工具和真机验证：真实模板、直接点击许可、退出后送达、旧消息回跳、离线取消及重启恢复、原生大字/RTL排版。浏览器720项只是新增卡片组件代理，不能替代原生或完整设置页验收。无IANA时区或密码学随机源支持的微信主机需明确升级/兼容验收，当前不降级为Math.random或固定偏移猜测。

小程序七类关键事件源码及官方SDK适配已接入，默认FRIDGE_TELEMETRY_ENABLED=false。正式启用前接续平台七事件/角色权限登记、候选SDK完整Git版本、真实请求/分析数据核对；本地测试不等于已有生产分析报表。隐私V0.4草案第8节已改为真实功能开放说明并补微信提醒数据/取消限制；此前“原型描述尚待改”为历史状态。正式生效日期、反馈/分析拟定保留期的服务端落实和提醒记录保存期限仍需核定。当前模拟器APK未重打，源HTML更新将在下一包体现。

官网例行重建遗漏APK的问题已修复，普通构建会自动保留passed安装包，当前本地按钮与完整HTTP/桌面浏览器下载验证通过。微信UA仅验证HTTP协议，真实Android微信安全提示/转出系统浏览器仍需上线域名和设备验收。安装包尚未包含本轮新离线法律正文/171语言key，最终重打时同步。

官网匿名SDK已接线并通过本地浏览器验收，默认FRIDGE_WEB_TELEMETRY_ENABLED=false。启用前部署正式匿名端点、登记公开FRIDGE_WEBSITE_CLIENT_ID并核对官网Origin的CORS；构建时设置公开FRIDGE_PLATFORM_URL，不向静态页注入Secret。官网统一同意与App记录独立，暂无生产采集或分析报表证据。

鸿蒙本地提醒已补原生源码并接合法同意、撤回和冷/热点击，28项宿主端口测试通过；没有原生编译或设备送达证据。需匹配DevEco/SDK工具、正式应用身份/固定签名及PUBLISH_AGENT_REMINDER资格/Profile核对。按../03-deployment/harmony-notification-verification.md接续HAP与设备验证，尤其同日单卡、部分处理、时间/时区、重启与容量窗口；不把Windows替身测试当作已交付HAP。

微信账号注销平台本地候选已补重认证与七天内登录撤销，57项相关回归通过。正式平台候选需追加审阅V56（连同既有待部署迁移），复用原物理删除审批和hold，不自行启用生产删除。官方SDK和产品账号页尚未接入，不能把平台候选称为已可在App注销；真实微信配置/跨端会话、等待期和最终处理仍需联调。

账号注销SDK已补齐并通过本地验证，新Taro候选已安装到小程序；产品账号页流程仍属开发待办。正式启用时核对自助确认头X-Action-Confirmation与管理操作头的区别，随本次平台候选部署修正后的OpenAPI；不自行改变物理删除批准开关。
