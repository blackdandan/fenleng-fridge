# WP05 Flutter 游客会话与微信账号衔接

承接已批准 WP05。本阶段修改官方 Flutter SDK 本地候选及 App 消费端；不新增账号密码、安装密钥、社交账号合并或食材云同步。

平台游客合同来自同级 fenleng-shared-platform 的本地候选 docs/contracts/v1/guest-identity.md，基线 `777c6ba4d87be940b3cc91d1167f173e5e25ef49`；尚未部署。公开微信合同 MCP 核对同一基线 docs/contracts/v1/mini-program-identity.md（repository https://github.com/blackdandan/fenleng-shared-platform，sourceMode github，resolvedCommit 同基线）。SDK sourceMode local-git，修改前完整基线 `334611afbd9ae4be95771159a5cd00dc6f0ba31f`。

官方 FlutterGuestIdentity.loginAsGuest 单实例 single-flight，仅 applicationCode/clientId 和可选 device；认证 POST 不自动重试。SDK 持久化 guest/account 显示标记，刷新保留、微信交换成功替换、退出/过期/写盘失败清理。标记不是服务端权限依据；旧会话按 account 显示。离线恢复不会直接创建替代游客。

App 同意后后台 ensureSession：先恢复，确实没有可恢复会话时才在显式 guestEnabled 开关下创建游客。游客可供真实反馈 SDK 使用，但账号页仍显示游客和可选微信登录。网络失败不阻断本机库存；关闭/撤回后清理迟到游客。微信登录仅替换平台会话，不迁移、删除本机库存。

FRIDGE_IDENTITY_ENABLED 与 FRIDGE_GUEST_ENABLED 默认 false。正式应用/客户端/专门游客角色登记，以及平台 PLATFORM_GUEST_LOGIN_HTTP_ENABLED 开关都未配置或部署；不能宣称公网免登录反馈已验收。

本阶段定向验证：Flutter 控制器/存储/布局/启动与 SDK 身份共34项通过（含当时6项 guest SDK），本机 HTTP 游客反馈和既有反馈4项通过；mini 微信身份9项通过。新增第7项 SDK kind 写入失败回归后，执行一次 App 全集与四份 SDK 身份测试，最终结果见 implementation-status.json。新增代码 Dart analyze 无问题。日志 .fenleng/flutter-guest-stage-full.log、flutter-guest-analyze.log、flutter-guest-feedback-targeted.log。

本机 HTTP 测试确实经过官方 SDK 网络和磁盘存储：游客换 TokenPair → Bearer + Idempotency-Key 反馈 → 关闭重建后 refresh → 微信 code 交换账号；旁置本机文件字节保持一致。它不是正式 Provider 或生产平台验收。

原8文件 SDK 候选仍未发布；本次共享文件已继续演进，旧 client-sdk-identity.patch 仅保留前一阶段快照，当前不能反向验证为最新候选。本轮未提交、推送、部署，也不扩大原待答复的8文件发布问题。最终仍需独立确认发布范围、固定不可变 SDK commit、移除临时 path overrides、干净重验。Taro 游客/mini 反馈、遥测、订阅消息和其他 WP 保持待完成。

当前 APK 与官网 APK 尚未包含本阶段源码；既有下载校验仍仅证明其记录的旧 APK，不代表新游客功能运行证据。

阶段收口：App 全集78项与官方本地 SDK 身份17项合计95项一次运行全部通过，含现有 golden 回归；SDK guest 为7项。项目与 SDK 两份知识审计均通过，nextAction 为 none，日志分别为 .fenleng/guest-session-knowledge-audit.log、guest-sdk-knowledge-audit.log。无新增界面或文案，沿用已验账号页游客/微信入口。
