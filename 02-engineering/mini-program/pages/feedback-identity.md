# 小程序游客身份与反馈源码阶段

承接已批准 WP05、已确认 Figma 及持续实施授权。保留免登录本机库存，可选微信账号不迁移、同步或清空食材。没有新增产品后端或支付。

## 实现与契约

官方 SDK 候选新增 TaroAuthSDK.loginAsGuest、会话 identityKind 与 TaroFeedbackSDK.submit。平台游客契约为同级 Shared Platform 基线777c6ba4d87be940b3cc91d1167f173e5e25ef49上的未发布候选 docs/contracts/v1/guest-identity.md；反馈沿用同基线已公开 notification-feedback-contract.md 与 engagement.schema.json，来源见 ../../shared-platform-feedback-evidence.json。

SDK 修改前基线334611afbd9ae4be95771159a5cd00dc6f0ba31f，sourceMode local-git；mini vendor/provenance.json 保留原 git archive，新增显式 local-worktree-candidate 包及完整 SHA256/逐文件 SHA256。包名 fenleng-sdk-taro-0.5.0-fridge-candidate.tgz，SHA256为9bf0ec82c0dd142eaaeaade022a3bdce95e9daceba61f49a22858e8dca4bc472，未发布。实际安装源文件与记录一致；不是不可变新 Git commit 消费证明。

App 组合根 MiniIdentityOwner 为账号页和反馈持有唯一实例；同意后先恢复，无会话且 FRIDGE_GUEST_ENABLED=true 才创建游客。后台失败不阻断库存；快速同意/撤回/重同意跳过过时初始化，并在新身份创建前排空旧会话清理。前后台复用官方 coordinator 定时恢复，页面返回取消迟到微信 code，游客状态不显示为已登录账号。

设置→反馈为完整页面，保留已确认意见标签、输入区、隐私说明、提交、错误重试、受理/回执与再写一条。使用现有20语言153key与既有 Token/浅深主题，输入上限4000；不上传附件。单个主机存储快照保存 text/key/receipt，网络前写稳定幂等键，失败保留草稿，回执本机落盘成功才清正文。回执保存失败使用原键受控重试，正文改变换键；重启和跨页面保留草稿/已受理回执，损坏快照不覆盖。

反馈实际 SDK 使用 Bearer 和 Idempotency-Key。401 使当前会话失效，当前写入不自动重放，下次用户重试才恢复/创建会话并重用草稿键；撤回/关闭拒绝迟到成功。服务未配置显示本地化不可用状态，不伪造受理。

## 视觉与验证边界

Figma b34I8tzPpU7tv1sHHdWLkq 的2:289、2:303、2:317，沿用已读取设计与Flutter反馈页面的产品Token；不重新设计。规范基线069718f51642df16e5c80c757943ce03621fd4a0，补读内容/文字缩放/小程序规范证据见 ../../mini-feedback-design-evidence.json。几何沿用已有204.8输入高度、16正文、18受理标题等Token，输入高度随根文字缩放增加，标签始终可见。

源码/编译校验验证所有CSS变量存在、无新增硬编码颜色、20语言和变量一致、标签/输入上限、官方候选归档与安装文件哈希、编译产物包含真实身份/反馈路径。报告 ../../evidence/mini-program/guest-feedback-source-results.json 及 record-settings-source-results.json。没有微信开发者工具/原生截图、字体与键盘/RTL设备证据，不将源码校验或本机HTTP测试当作原生视觉保真；Figma行保持🔶。

测试覆盖应用草稿8、主机快照1、API/生命周期6、共享身份所有者3共18项新增；原有43项保留。另39项Taro SDK测试全通过，新增7项游客/反馈。真实本机HTTP测试走官方SDK与主机请求桥，验证游客POST→认证反馈→重建refresh→微信code交换；它不是微信原生请求或生产Provider验收。最终全集与构建结果回写 implementation-status.json，日志 .fenleng/mini-guest-feedback-full.log、mini-build-guest-feedback-final.log、taro-guest-feedback-sdk.log。

## 待完成

阶段收口：最终小程序全集61项一次运行全通过，官方Taro SDK39项全通过；TypeScript、平台边界、Token/语言/归档/安装文件及编译特性检查均通过。最终weapp约803KiB，common.js391KiB超过webpack244KiB推荐值，保留体积及async chunks建议，未当成失败或隐藏。项目与SDK知识审计均pass、nextAction=none；日志 .fenleng/mini-guest-feedback-knowledge-audit.log、taro-guest-feedback-knowledge-audit.log。

平台游客部署/正式应用、同应用PUBLIC客户端和专门游客角色登记、小程序AppID/request域名；SDK候选不可变发布收口；微信开发者工具/真机截图、真实授权和提交反馈。订阅消息客户端与平台服务、遥测/撤回和账号注销仍在后续范围。FRIDGE_IDENTITY_ENABLED/FRIDGE_GUEST_ENABLED默认关闭。本阶段未更新Android APK、未推送SDK或上传/发布小程序。
