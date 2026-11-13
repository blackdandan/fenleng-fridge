# 执行决定与授权来源

Owner已批准完整实现计划，要求常规选择按产品、设计稿和推荐方案推进，并允许必要的Shared Platform/官方SDK补齐。本记录整理在该范围内由我作出的实现决定；正式配置、部署、签名平台登记与物理删除审批仍按Owner既有规则办理。完整交付时继续补充本记录，不把当前阶段记录当全部交付完成。

- 官网匿名分析复用官方SDK，默认关闭。启用后使用独立于App的统一协议/隐私同意记录；不增加单独分析开关。暂不同意仍能浏览下载。采集仅App入口事件，不传登录凭据，SDK失败不影响下载。依据及验证见[官网阶段证据](../02-engineering/specs/website-anonymous-evidence.md)。
- 鸿蒙本地提醒使用系统后台代理日历，不新增通知服务器。按日期固定通知ID、私有周期账本、发布意图恢复及30批兼容窗口；部分处理只更新已有卡片。SDK和设备证据缺失时如实保持未验证，不用宿主测试冒充HAP。见[鸿蒙交接](../03-deployment/harmony-notification-verification.md)。
- 微信无密码账号的注销复用平台本人确认和七天处理管线，扩展既有绑定的一次性授权码验证。微信code没有JWT的auth_time/nonce，不作虚假新鲜度声明。确认响应丢失可重试；七天内成功登录原子恢复，Token签发失败回滚。保持生产删除审批及其它Provider规则，不新建产品后端。见[账号生命周期证据](../02-engineering/specs/wechat-account-lifecycle-evidence.md)。

Owner后续配置与设备事项集中在[待办](owner-follow-ups.md)，源码缺口继续留在implementation-status与各WP中，不能移成Owner配置任务来代替开发。

- 小程序注销按平台环境/客户端/用户保留最小申请日志，不保存微信code或Token。未知结果不自动重新登录；原请求成功回执在并发401后仍有意义。先持久回执再清理旧身份，保存/清理失败只重试本地步骤，新身份不被旧回执清除。当前账号页已接线并完成本地验证；正式微信身份及服务部署后仍需联调，见[应用层证据](../02-engineering/mini-program/pages/account-deletion.md)。

- 最新首进协议遵守已验收稿的居中、颜色、按钮高度和16px弹窗外距；内容自然撑高并可滚动，SafeArea避免大字进入系统栏。新增说明表明拍摄和通知权限在使用时另行申请，不增加独立分析选择。80组布局、安全区和拒绝/阅读行为测试，以及独立Android验收模拟器的视觉/撤回流程证据见[当前结果](../02-engineering/evidence/android/consent-current/results.json)。Owner随后要求暂停安装，当前交付收口不再改Owner模拟器。

- 完整源候选包内附三份官方SDK未发布候选，以逐文件哈希和归档内override消除同级工作区依赖；不把该副本称为正式SDK发行，不修改规范产品仓库的Git依赖。构建产物另包官网与微信导入目录，网站下载APK须与release.json的字节数和SHA256一致。

- 任务领取与结果回写纳入同一既有数据库事务，每次只处理一项、单轮仍受原batchSize限制，修复注销任务崩溃后永久停留“处理中”的恢复缺口。普通失败保留原退避，后项失败不回滚已提交前项，远端清理沿用现有幂等UID。20项相关回归通过；不新增安全策略、生产修复脚本或自动部署，证据见../02-engineering/evidence/data-request-recovery-results.json。

- Owner明确回复“spec approved，发布开发预览站”后，按独立目录、站点配置和匹配证书发布fridge.fenlengtech.com。公开下载明确为当前未加固Debug预览；这次授权不外推到后端、其他网站或正式发行。首次重载就绪检查失败已实际回滚，补有上限重试后完成；证书续期加载复用既有timer并仅匹配本域名。11项本地恢复验证和完整外网APK哈希核对通过，微信真机仍待验，见../02-engineering/evidence/website-preview-production-results.json。

## 最终收尾执行决定

依据Owner明确授权整合平台/SDK最新main；未发布迁移顺延V61-V63，保留上游已部署历史。Docker虚拟化不可用时按现有固定SSH规则单向上传本机构建JAR，服务器缓存镜像离线装配并走原发布代理，不改治理政策。Android继续标明Debug开发预览，清理、分架构并移除非必要GPU验证库，原固定签名不变。SDK消费固定已push Git提交，保留旧candidate字节。软著材料使用完整真实Android业务文件、真实测试截图和内嵌中文字体，登记事实、签章、机械重复风险交Owner复核；不编造完成/首发日期或原创性保证。以上是Owner授权范围内的实现选择，没有代替Owner授予新权限。
