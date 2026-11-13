# Owner 后续事项

2026-11-13 Owner明确将下列事项留待本人处理，不阻塞本轮收尾。已完成的开发、平台部署和SDK推送不再列为待办。

本轮结果：Shared Platform生产已升级0.1.0-rc.138；官方SDK已推送b5e529f；Android ARM64开发预览降至68.5MiB并更新官网；软著人工复核材料位于docs/ip/software-copyright/deliverables/v1。

| 待办 | 后续执行内容 |
| --- | --- |
| 微信小程序真实预览与配置 | 正式AppID、主体认证、合法域名、隐私声明；开发者工具和真机预览、存储/大字/RTL检查。构建与本地测试已完成。 |
| 微信订阅消息与移动微信登录 | 补真实模板ID、字段映射、凭据、开放平台移动应用登记及回调；验证直接授权、退出送达、旧消息回跳、离线取消、重启恢复。源码已完成。 |
| Shared Platform产品运行配置 | 登记冰箱产品、逐端OAuth客户端、允许的游客能力和七类事件权限；启用真实反馈、认证、遥测与订阅消息。平台已部署，默认关闭项保持关闭，未配置不等于已完成真实联调。 |
| iOS验收与发行 | Mac/Xcode、Apple Team、Profile、Sign in with Apple、Universal Link、原生提醒、归档与真机；当前不宣称已编译IPA。 |
| 鸿蒙验收与发行 | 安装DevEco/SDK及登录华为账号，补appIdentifier和证书/Profile，核对提醒代理资格，编译HAP并真机验收。 |
| Android正式发行 | 真实手机、微信内下载转浏览器、正式中国加固包与冷启动验收。当前下载为固定签名Debug开发预览，ARM64；32位和x86_64分包保留在本机构建目录。 |
| global身份与远程清理 | 真实Firebase项目和OAuth配置、Google/Apple Provider、平台audience及服务端清理凭据；管理私钥仅进入既有服务端通道。物理删除沿用原审批和hold。 |
| 备案、协议与法律事实 | 填实际App/网站备案号，确认政策生效日、数据保留期限和运营主体。当前政策为V0.4审阅草案。 |
| 软著复核和申报 | 确认登记名称（当前“冰箱库存管理”仍是产品描述名）、主体与权属、完成日期和首次发表事实，补主体证明并签章；复核源码重复率风险及开源边界后再提交。材料不是已登记证书。 |

接续文档：03-deployment/identity-configuration.md、ios-notification-verification.md、harmony-notification-verification.md、preview-website-runbook.md，以及docs/ip/software-copyright/deliverables/v1/用户执行步骤.md。
