# 微信账号生命周期：平台候选阶段

属于已批准完整计划WP05及后续微信登录。冻结知识来自fenleng-shared-platform仓库777c6ba4d87be940b3cc91d1167f173e5e25ef49的docs/runbooks/account-lifecycle-operations.md，MCP sourceMode=github，source同路径，retrievedAt=2026-11-13T05:52:08.210Z。该版本已有七天等待/登录撤销/物理删除审批，但联合注销证明只支持Firebase/Apple。

本地候选补WECHAT挑战枚举、原生一次性code交换匹配原有ACTIVE绑定、原有本人DELETE确认消费和V56检查约束；不创建账号或新会话，不依赖密码。code没有JWT的auth_time/nonce，返回authenticatedAt只表示实际交换验证时刻，不伪造已验证的用户交互时间。正式SDK与客户端必须在挑战后重新请求code；取消不提交。挑战过期、跨应用/会话/客户端/用户、被撤销绑定、缺提供者和网络错误均拒绝。已验证且未消费的同范围挑战在响应丢失后重试不再次交换已消耗的code。

发现并修复原微信登录链路拒绝DELETION_PENDING的问题。七天内成功微信登录在同一真实数据库事务中恢复账号、取消申请、维护已验证小程序收件身份、创建会话和签发Token。签发失败全部回滚；到期边界不延长等待。保持原fenlengeat UnionID规则、其它产品应用命名空间、管理权限和生产删除审批开关，没有部署或运行生产迁移。

验证使用真实临时PostgreSQL及本机Provider替身。证据在../evidence/wechat-account-lifecycle-results.json和../evidence/shared-platform/wechat-account-lifecycle/。覆盖无密码确认、错误/过期/越界证明、响应丢失重试、一次消费、实际DELETE事务失败回滚与七天时间、登录撤销/失败回滚/到期拒绝。Provider替身不代表真实微信授权成功。

SDK仍拒绝WECHAT联合注销参数，Taro生命周期方法及两端账号页注销入口还未实现；消费者尚不能完成此流程。后续继续SDK与产品接线、20语言状态、确认/取消/持久回执/撤回协作、真实HTTP消费者验收。平台正式发布需审阅V54/V55/V56及原生产门禁；不是一次本地测试就能证明物理删除已启用或完成。整体目标保持未完成。

最终已归档10个测试套件、57项通过，0失败/跳过；Bootstrap生产与测试源码编译、WechatLoginConfiguration回归通过。契约132操作/14事件、兼容性及1.9.0/34文件发布清单检查通过；fridge与Shared Platform知识审计均nextAction=none。初次HTTP验证发现领域provider限制未同步，修正后完整定向验证通过；保留失败日志不冒充最终结果。
