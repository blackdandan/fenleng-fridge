# 域名与发布预检

- 官网：`fridge.fenlengtech.com`，Owner于2026-11-13批准公开开发预览。独立站点与匹配证书已部署，公开页面/HEAD/Range已验证；ICP备案和真实微信手机验收仍待办。具体内容、入口和回滚见[预览站运行手册](preview-website-runbook.md)。
- 仅官网网页，无 Web 工作台域名；无自建业务 API 域名，复用 Shared Platform 的受管理端点，具体环境由应用接入登记确定。
- 协议正式 URL 规划为 `/terms/`、`/privacy/`；App canonical link 规划为 `/app/`。本地静态工程与固定签名Debug APK下载已生成并校验；长期签名公开登记见05-knowledge/signinfo/application-signing-info.json。正式域名托管、AASA/assetlinks及真实回跳仍未验，不宣称已上线或已完成Universal Link接入。
- 无照片上传与云同步，业务 OSS 不适用；无需为本产品新建 Bucket/RAM Role/Policy。
- Android applicationId / iOS bundleId / HarmonyOS bundleName：统一为 `com.fenlengtech.fridge`，Owner 于 2026-11-13 确认。
- 微信 AppID、主体认证、合法域名及开发者工具配置：待接入时提供/核对，不在文档记录 AppSecret。
- 前期只读阶段没有部署；Owner后续明确批准预览发布后已按独立固定目标执行。不把预览包当正式加固发行，不修改其他站点或DNS。

历史访问问题：首次诊断未部署独立server_name，请求落到默认apple-sandbox-api证书。现已通过独立站点及匹配证书修复；历史证据保留在[外部验收状态](external-verification-status.md)，当前事实以运行手册和最新部署结果为准。

本地 4173 原型和 4180 原型/官网服务已从 06-project/prototype 重启，外部 URL 端口保持；过程见迁移报告。
