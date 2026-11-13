# 冰箱独立官网承载方案

状态：Owner于2026-11-13明确回复“spec approved，发布开发预览站”，授权本方案内独立HTTPS站点、匹配证书和当前未加固Debug预览APK公开下载。开始执行；不得将该授权外推至正式发行、其他产品或平台后端部署。

## 当前事实

- 确认域名：fridge.fenlengtech.com；登记SSH主机root@121.199.10.6。
- 服务器当前Nginx无该域名server_name，默认443站点为apple-sandbox-api；实际TLS返回该站点证书。证据：../evidence/external-readiness/results.json。
- 现有官网使用独立不可变版本目录和原子符号链接，例如PromptManager `/opt/fenleng-websites/prompt-manager/releases/0.1.0-rc.2`。
- 当前网站明确“开发预览，尚未正式发布”，协议为V0.4审阅草案，APK为0.1.0+1固定签名Debug预览，SHA256为0b19e47a4d33aa11e92b179a921cc32c8cebefae1ae7fd7907b49a9385ec06ac。没有正式加固包或物理Android真机验收。
- 已补稳定下载URL `/downloads/fenleng-fridge_latest.apk`；版本化文件名保留于release.json的artifactFilename。原APK内容及签名不变。本地5项下载测试、静态20语言/法律/完整APK检查和实际Chromium全量下载SHA验证通过。

## 两种发布范围

Owner可明确批准本轮仅公开开发预览站，继续显示开发/未加固Debug/法律草案状态，提供当前预览APK下载；这属于Owner对本次目标和产物的明确选择，不能记成正式中国发行或修改基座常规发布规则。未获该明确批准时不把Debug候选上传为正式官网发行物。

如选择正式发行路径，按既有产品官网下载契约，先从确定提交构建正式签名release、中国加固、指定物理真机覆盖安装与冷启动门禁，再打包官网候选。当前模拟器不充当该真机，Owner“先不用安装”继续有效。

## 拟登记的独立目标

以下均为拟新增位置，尚未在服务器创建，禁止借用其他产品发布脚本的身份冒充已登记：

| 内容 | 位置 |
| --- | --- |
| 项目部署根 | /opt/fenleng-websites/fenleng-fridge/ |
| 校验后上传区 | uploads/ |
| 不可变版本目录 | releases/<candidate-id>/ |
| 活动链接 | /usr/share/nginx/fenleng-fridge |
| 独立Nginx配置 | /etc/nginx/conf.d/fenleng-fridge.conf |
| 对应域名证书 | /etc/letsencrypt/live/fridge.fenlengtech.com/ |

只处理这一域名、站点目录和证书；不改Apple Sandbox、PromptManager、Scanister、轻食及现有门户站点。首次无旧冰箱版本时，回滚为移除本轮新建站点入口并恢复原Nginx配置快照；后续保留前一版本链接。

## 执行顺序与验收

1. 核对Owner本次批准范围、候选ZIP SHA、源快照manifest；冻结拟发布版本和站点配置摘要。准备用于本项目的固定目标发布入口及本地路径穿越、哈希与回滚测试，不复用其他项目身份。
2. 实时检查目标目录/配置/证书是否已被其他操作创建、80/443和磁盘情况；有并发变化即保留现状重新比较。检查现有ACME机制，复用已登记账户；不读取或输出其私钥。
3. 仅上传已验证的不可变候选和配置模板。备份相关配置和链接；在本项目上传目录解包验证全部manifest、普通文件类型和摘要，拒绝越界/符号链接包。
4. 为该域名建立HTTP验证入口并使用既有机制签发对应证书；任何HTTP配置写入先nginx -t、失败恢复。证书签发/验证失败时不启用错误证书，也不修改客户端校验。
5. 安装版本目录及独立TLS配置，原子切换活动链接；nginx -t通过后reload。保存回滚点，失败恢复配置/链接并再次健康检查。
6. HTTPS主机名有效；首页、terms、privacy、app和release.json返回正确内容；固定APK URL为200、MIME/长度/完整SHA与候选一致，HEAD/Range正确，固定URL无不可变长缓存。观察同机其他已登记站点响应，保留部署前后证据。
7. 实际Android微信打开、转系统浏览器、完整下载及安装另有设备证据；仅HTTP微信UA或桌面Chrome不能记成微信真机验收。

本次只完成准备与本地候选检查；没有执行上述服务器写入。真实AppID/订阅模板后补、iOS由Owner接Mac验证、Harmony工具安装及华为登录由Owner后补的决定保持。

## Owner批准后的执行结果

2026-11-13已完成独立预览部署，内容35efd85c3910，匹配域名证书有效至2027-02-11。r1在Nginx重载切换窗口的立即TLS检查失败后自动回滚；补有界就绪重试后，r2用同一制品和已签发证书成功，healthAttempts=2。r3安装并实际触发仅本域名匹配的续期加载hook，复用既有certbot.timer。11项校验/回滚/重试测试通过。

首页、协议、隐私、app页与下载入口可公开访问；完整外网HTTP下载204147812字节、SHA256与候选完全一致，HEAD/Range/MIME/缓存和16字节实际APK前缀核对通过。直连Chromium页面/下载发起、默认TLS、HTTP2分段与德语窄屏通过；浏览器完整下载没有冒充通过，代理HTTP2停滞及主动取消测试范围单列记录。其他三个官网前后均200。证据见../evidence/website-preview-production-results.json，操作与回滚见../../03-deployment/preview-website-runbook.md。真实Android微信及物理手机安装仍未运行；开发预览未升级成正式发行。

## 授权依据与规则来源

Base仓库https://github.com/blackdandan/fenlengtechbase，固定commit069718f51642df16e5c80c757943ce03621fd4a0：knowledge/operations/production-host-inventory.md的OPC-SSH-001；knowledge/application-websites/product-download-contract.md的正式中国发行门禁。当前矩阵技能要求“Production 写入必须有 Owner 对本次目标和用途的明确授权”。本方案不修改这些治理资产。
