# 账号生命周期：SDK候选阶段

沿用已批准WP05。SDK基线334611afbd9ae4be95771159a5cd00dc6f0ba31f及平台777c6ba4d87be940b3cc91d1167f173e5e25ef49本地候选，不发布、不推送、不部署。Flutter/Web原联合注销方法接受WECHAT；TaroAuthSDK新增挑战、确认、数据请求列表与EXPORT/DELETE提交，仍使用现有原生TaroPlatformClient和当前会话。

原生Taro传输确定发送当前Authorization、Idempotency-Key及X-Action-Confirmation，不因请求成功清除会话，不把注销受理当物理完成；网络失败/401/取消不自动重放。显式选项的幂等键/确认值不能被不同大小写自定义同名头误覆盖。DELETE缺确认、非法意图或challenge/proof参数不发送。注入其它传输时其自身重试政策仍适用，产品本轮使用原生Taro传输。

跨端核对发现自助注销OpenAPI原先错误引用管理操作Action-Confirmation-Id参数，而真实控制器和Flutter使用X-Action-Confirmation。已添加SelfDataActionConfirmation专属参数，管理接口保持原头不变；Spring实际HTTP控制器测试证明正确头被读取、管理头不能替代。没有改权限/生产删除审批。SDK候选fixture与平台操作/请求schema冻结快照一致，并在真实本机HTTP请求验证实际确认头，避免测试重复错误假设。

本轮97项相关core/Taro/Web SDK测试、72项Flutter SDK测试、1项候选契约、5项平台HTTP、102项小程序消费者测试通过。Taro声明类型与小程序typecheck/boundaries/weapp构建通过。小程序已离线安装新Taro候选归档，24个安装文件逐字节哈希及既有core候选、7事件编译检查通过。归档名为fenleng-sdk-taro-0.5.0-fridge-account-lifecycle-candidate.tgz，完整SHA/来源在vendor/provenance.json；旧候选与档案保留，不称已发布不可变版本。

Flutter首次测试因package_config仍指向stock3.44.5而编译失败；通过固定FVM Dart刷新本package依赖解析后，使用62357a93d653bf844f730bb1f4b7cc9e2139d14e对应Flutter3.41.9/OH完成72项测试，没有改共享SDK/Pub缓存或伪造鸿蒙工具。另一次定向测试暴露错误头名称，已修正并经实际控制器复核。小程序common.js458KiB和NoAsyncChunks原警告仍在。

证据：../evidence/account-lifecycle-sdk-results.json与../evidence/client-sdk/account-lifecycle/。fridge、SDK、平台知识审计均通过，nextAction=none。各SDK全量/消费者回归只在本阶段边界集中执行；此结果不是App原生授权、微信设备或生产注销验收。

尚未完成：App/小程序账号页注销确认、七天等待与时间展示、持久化意图/回执、未知提交结果、权限取消与隐私/身份切换的协作。它们是后续开发，不能转为Owner配置待办。正式配置、平台部署、SDK不可变版本、真实Provider与设备验证独立记录；不能自动登录来“重试”未知DELETE结果，否则可能撤销已经受理的申请。
