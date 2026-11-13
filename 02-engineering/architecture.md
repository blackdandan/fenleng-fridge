# 工程架构

产品范围以 `../01-product/handoff.md` 及现有 MVP 为依据。真实代码仅进入 `06-project/`；当前只生成工程容器，后续 coding 才创建内部结构。

| 容器 | 技术与职责 | 后续内部组织要求 |
| --- | --- | --- |
| app | Flutter OH，Android/iOS/HarmonyOS NEXT | FVM 固定 SDK、Melos workspace；领域/应用/适配层隔离，三端共享库存、整理、检查周期契约 |
| mini-program | Taro + React + TypeScript，仅 weapp | pnpm workspace；apps/miniapp，domain/application/api-client/ui-kit/platform-contracts 和微信 adapter 包；领域层无 Taro/React/wx 依赖 |
| web | 独立静态官网 | 产品介绍、协议、发布状态；无库存客户端、工作台或后台 |

App 与小程序共享行为定义和验收用例，不承诺跨 Dart/TypeScript 直接共享源码。相机、图片持久化、身份、权限和通知均通过各端适配器。微信不自动获得 App 的后台本地通知能力，差异见 `integration.md`。

本地模型沿用 MVP：照片记录及稳定本地编号、存储区域、剩余状态、历史、检查周期、通知关联和待处理状态；领域规则不得依赖平台 SDK。照片存持久化文件，记录保存受管理路径；微信须验证临时文件转持久化、配额和清理行为。无需服务器数据库设计。

官网与各客户端消费同一版本协议源，经构建生成随包/静态正文；生成物不可成为第二份可编辑法律源。开发 preview 保留整体内部布局，不以复制原型代码冒充 Flutter 或微信工程。

遵守 Fenleng Design System Token、主题、组件状态、可访问性；Figma 最新页和截图逐屏核对，拍摄独立成页，真正弹窗有边距，Android 解释弹窗在顶部。主题基线和具体 Token 在编码时读取真实设计系统，本文不发明新色值。
