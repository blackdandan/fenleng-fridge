# 当前状态补充（2026-11-13最终交接）

Shared Platform rc138/V63与独立HTTPS官网已实际部署，旧“未部署/证书不匹配”诊断是首次绑定前的历史记录。最新证据见02-engineering/evidence/final-delivery；剩余真实配置与端侧验收由Owner接续。

# 外部验收当前状态

当前更新：Owner随后明确批准开发预览发布，独立站点和匹配证书已上线，完整外网APK下载哈希通过。最新事实见preview-website-runbook.md及02-engineering/evidence/website-preview-production-results.json；下文保留发布前诊断过程，不代表当前仍缺证书或server_name。真实微信手机验收与正式发行仍待办。

2026-11-13。本轮只核对状态，没有部署、修改DNS/证书、登录华为账号或继续安装模拟器。

## 官网HTTPS

127.0.0.1:7897代理端口实际监听。通过该代理请求 `https://fridge.fenlengtech.com/release.json` 时，TLS主机名校验失败。独立TLS检查观察到证书Subject/SAN仅含 `apple-sandbox-api.fenlengtech.com`，Issuer为Let's Encrypt YE2，观察到的错误为RemoteCertificateNameMismatch。证书检查回调始终拒绝接受连接，没有关闭下载客户端校验或改系统信任设置。

这证明当前访问路径尚不能作为冰箱官网的有效HTTPS下载地址，不足以判断具体是DNS指向还是站点/SNI绑定配置造成。系统DNS返回198.18保留地址，可能是本机代理的映射，不能当作实际服务器公网IP。待Owner确认现有站点承载位置；没有自动修改共享服务站点。

证据：`02-engineering/evidence/external-readiness/fridge-public-certificate-audit.json`。本地已校验的官网ZIP、APK下载和静态源码仍有效，真实微信转浏览器下载/手机安装尚未验收。不能为绕过此问题改用不校验HTTPS的下载。

## Harmony工具链

当前预检未发现SDK目录、ohpm、hvigorw、hdc。Java17和Node25可执行；这不等于完整固定工具链就绪。所需固定DevEco26.0.0.851/SDK26.0.0.105及其配套工具沿用项目基线，不自动升级到官网最新版本。

本次独立未登录浏览器访问[官方下载入口](https://developer.huawei.com/consumer/cn/download/deveco-studio)跳转华为OAuth认证，尚未取得固定版本下载包。不能据此推断Owner已有浏览器是否登录、是否已有本机安装包，也不能声称工具包不存在。已向Owner询问现有安装目录/下载包，待确认后优先复用。

Owner随后明确答复：没有现有安装包/目录，安装及账号登录由Owner后补。本阶段不继续代为登录或安装；原生编译待匹配工具链就绪再执行。

官方[26.0.0发布说明](https://developer.huawei.com/consumer/cn/doc/harmonyos-releases/deveco-studio-new-features-2600/)列出26.0.0.851配套hvigor6.26.8、ohpm26.0.0.630和Node24.14.1，与本项目基线一致。当前未执行ArkTS编译/HAP签名/原生设备验证，28项宿主测试不能替代这些结果。预检原始结果：`02-engineering/evidence/external-readiness/harmony-environment.json`。

## 接续边界

当前完整源码候选及官网/小程序构建包保持原哈希，不为本次环境观察重复重建；最新候选见本机`.fenleng/deliveries/latest-*.json`。本页是候选生成后的外部状态记录，不把它伪称为已进入旧ZIP的文件。Owner回答前继续保留这两项为未验证，不默认把沉默视为授权、配置已完成或允许改用其它SDK。

## Owner指向服务器组织资产后的实时核对

已按Owner要求从Base固定知识commit069718f51642df16e5c80c757943ce03621fd4a0读取生产主机清单，经登记root@121.199.10.6只读核对实际目录和Nginx加载配置。PromptManager、轻食、Scanister的活动静态版本分别位于 `/opt/fenleng-websites/prompt-manager/releases/0.1.0-rc.2`、`/opt/fenlengeat/official-web/releases/0.1.0-rc.6`、`/opt/scanister/web/releases/0.1.0-rc.10`，通过Nginx文档根的符号链接选中。

当前Nginx加载配置无冰箱server_name，也未发现冰箱独立部署目录；443首个加载的站点正是apple-sandbox-api，与外部实际证书吻合。当前访问落入默认站点，尚不能把“域名已配置”视作官网已部署。后续应按既有版本目录/原子链接模式为冰箱准备独立站点，不覆盖现有网站。实际证据见 `02-engineering/evidence/external-readiness/results.json`、nginx-public-routes.txt和website-current-symlinks.txt；本轮没有证书签发、Nginx修改、上传或发布。
