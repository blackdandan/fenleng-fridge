# 冰箱 Firebase Auth 用户清理

状态：候选实现及本地定向验证通过，正式配置/部署/真实删除验证待办。承接已批准 WP05 必要平台联动；不部署，不调用真实账户删除，不修改既有七天等待、生产删除批准或保留政策。没有涉及支付或删除原 Google/Apple 账号。

平台新增 `FirebaseAccountCleanup` 应用端口和基础设施适配器，使用既有 RSA PEM 加载能力进行 Google 服务账户 OAuth2 交换，再调用项目级 `accounts:delete`，只发送已绑定 Firebase UID。HTTP 连接和每次请求有限超时，不写入用户 ID token、Provider 响应正文、服务账户私钥或访问令牌。明确的 `USER_NOT_FOUND` 视为幂等完成，其他响应/网络失败保留为可重试结果。

由现有 `JdbcUserDataRequestProcessor` 调用：原生产批准通过后，取得提醒协调锁和账号行锁，在事务内重新检查保留限制、DELETION_PENDING 及到期时间，然后清理该用户全部 Firebase 绑定（包括已撤销的旧绑定）。受管项目均成功后才继续原有平台匿名化。远端成功、本机事务失败时，下次按同一 UID 重试；远端的“用户已不存在”使这条重试可恢复。此处不是跨 Google/数据库的分布式原子事务。

处理配置缺失返回固定 `FIREBASE_CLEANUP_NOT_CONFIGURED` 失败码，由现有数据请求处理器有界退避重试；网络/权限失败使用 `FIREBASE_CLEANUP_RETRY`。配置补齐后不需要客户端重复 DELETE。原批准/hold/未到期仍按现有阻塞语义处理。旧产品未加入受管集合时，仍按既有平台删除政策执行，没有给它们新增远程删除。

配置：`PLATFORM_FIREBASE_CLEANUP_APPLICATIONS` 为空时默认不管理任何产品；冰箱启用值为 `fenleng-fridge`。`PLATFORM_FIREBASE_CLEANUP_REGISTRATIONS_JSON` 由既有服务端秘密注入，含 applicationCode、projectId、serviceAccountEmail、privateKeyPem。客户端不得携带这些管理凭据。受管产品必须在现有 Firebase 客户端登记中对应唯一、独立的同一个 Firebase project；多个产品共用或多 project 无法从 app:uid 绑定命名空间可靠定位时返回未配置，不猜测删除目标。当前冰箱尚未正式开通账户，不迁移其他应用的身份命名空间。

Owner 后补实际产品 Firebase 项目、具有官方删除接口权限的服务账户凭据及平台部署/既有生产删除批准。模板位于冰箱 `03-deployment/config/firebase-cleanup-server.example.json`，不含真实凭据。软件实现、装配和本地验证由 Agent 完成，不能把它们转交成 Owner 配置任务。

验证分层：适配器通过真实本机 HTTP 验证签名 OAuth JWT、授权头、项目路径、UID、幂等缺失用户及失败处理；JDBC 通过临时 PostgreSQL 验证门禁、远端失败保留、后续重试、多 UID 部分成功及远端 ACK 后本机回滚恢复；配置单测验证默认不管理、受管缺配置及秘密错误不回显。尚未把这些测试称为真实 Firebase 删除或生产验收。

2026-11-13 结果：适配器6项、最新JDBC清理6项、Spring配置4项；同时复验原联合注销PG24项、原数据处理PG1项和提醒删除竞态5项，共46项全部通过、无跳过。Bootstrap生产源码及测试编译通过。最后的JDBC6项包含远端调用期间账号行锁等待的数据库观测；读者只能在匿名化提交后取得账号锁。第一轮夹具用了不存在的 hold 字段，修正后通过；该失败未被当作产品或生产错误。日志与XML归档于冰箱 `02-engineering/evidence/shared-platform/firebase-cleanup/`。

官方依据：[项目账户删除接口](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/projects.accounts/delete)、[服务账户 OAuth2](https://developers.google.com/identity/protocols/oauth2/service-account)。接口要求项目级 `firebaseauth.users.delete` 权限及支持的 OAuth scope；这不是本轮已授予任何真实 IAM 权限的声明。

## WP05收口：领取与完成回写的崩溃边界

当前复核发现生产调度先独立提交IN_PROGRESS领取，再执行匿名化和完成回写；进程在两者之间退出时，claimReady不领取IN_PROGRESS，任务会滞留。修复承接本WP已批准的失败恢复范围：调度每次只领取一个任务，在同一既有数据库事务中完成领取、处理、版本回写及outbox事件；单轮仍受原batchSize限制。崩溃或回写失败回滚领取与本地匿名化，下轮可重新领取；已成功的远程Firebase删除按现有幂等UID重试。CAS过期必须回滚本次处理，不能提交匿名化却丢失任务进度。

不新增租约、迁移、凭据权限、删除政策或发布门禁。生产批准、冷静期、hold、常规失败的有限退避及默认关闭保持原契约。验证须覆盖真实PostgreSQL：完成事件写入失败后的整体回滚/重试、处理中独立连接不可重复领取、已提交前项不被下一项失败回滚，以及普通失败仍保存退避。

结果：新增Bootstrap真实PostgreSQL6项通过，兼容回归共6个测试类20项通过、0失败/0跳过（包含原应用层退避1、请求仓储2、处理器1、Firebase清理6、配置4）。生产源码及测试编译通过。第一轮新测试的Jackson模块和Test导入不匹配，修正后执行通过，失败日志保留。未部署，没有执行真实Firebase删除；模拟事务中止不等于做过OS强杀实验。本修复保护新调度事务，不自动更改可能已存在的生产IN_PROGRESS行。结果和XML归档在冰箱02-engineering/evidence/shared-platform/data-request-recovery。
