# 工程交接指导

本阶段已承接产品并生成标准资产与三类工程容器，尚未初始化业务工程、下载 SDK、打包、部署或发布。已按 Owner 确认的 `../00-context/migration-report.md` 完成资产移动。

App 唯一 SDK 基线来自 `.agents/skills/fl-ai-coding-delivery/assets/flutter-oh-baseline.json`：FVM 4.1.2，fork `fltech-oh`，Flutter `3.41.9+ohos-1.0.2`，commit `62357a93d653bf844f730bb1f4b7cc9e2139d14e`，Dart 3.11.5；Android 新项目 NDK `29.0.14206865`。SDK 仓库 `https://gitcode.com/CPF-Flutter/flutter_flutter.git`。Flutter/Dart 命令通过 FVM 执行，禁止因鸿蒙兼容问题切换到另一套未锁定 SDK。

HarmonyOS NEXT 同期初始化：DevEco Studio 26.0.0.851，SDK 26.0.0.105/API 26，Java >=17、Node >=22，ohpm 26.0.0.630、hvigorw 6.26.8、hdc 3.2.0f。工具版本、环境和构建可用性留给 coding 验证，不把此声明视为安装证据。

微信锁定 Node、pnpm、Taro、React、TypeScript 与 weapp 插件版本后初始化 monorepo；支付宝/抖音不在首版，不为其增加产品验收承诺。

接入依赖与缺口见 `integration.md`，域名/应用 ID/备案见 `../03-deployment/domain-and-ssl.md`。先解决必要平台契约，再按独立本地领域与客户端垂直功能推进；不以 SDK 接入为由新增服务端或云库存。

中国渠道首版必须随包携带协议，在同意前仅允许渲染、同意记录、离线协议及无障碍展示状态。三端原生 DeferredPluginRegistrant 隔离业务/文件/设备插件，统一 post-consent bootstrap 幂等启动身份/反馈/采集。不能只在 Dart 页面挡一层提示而任由原生插件提前启动。

首版三端/微信/官网均规划 20 种界面语言和语言切换：zh-CN、zh-TW、en、es、fr、de、pt-BR、it、ja、ko、ar、hi、id、ru、tr、vi、th、nl、pl、uk。遵循用户选择优先于设备语言并覆盖 RTL/长文本。实际字符串目录由 coding 创建，当前配置为空，不声称翻译已交付。china/global 为显式构建渠道，不自动改变 Owner 已确认的中国首进流程。

无注册页，不照搬模板添加邮箱注册或强制社交登录。注销与注册规则按平台身份实际适用，详情见运营交接。APP 备案未知时从首版预置“备案号待补充”与查询入口。
