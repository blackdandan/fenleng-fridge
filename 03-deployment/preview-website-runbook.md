# 冰箱开发预览站

Owner于2026-11-13明确批准发布当前开发预览，包含未加固Debug APK。授权及目标见website-host-binding.md和production-host-binding.json。本页不把开发预览称为正式中国发行，不授权其他服务发布。

## 当前落点

- 网址：https://fridge.fenlengtech.com/
- 下载：https://fridge.fenlengtech.com/downloads/fenleng-fridge_latest.apk
- 主机：root@121.199.10.6，沿用OPC-SSH-001固定通道。
- 不可变网站内容：41f6bc67b6df5867195a8dff40bd24d7617f9075ab63cda926e386fed9b93249。
- 活动内容：/opt/fenleng-websites/fenleng-fridge/releases/41f6bc67b6df。
- 活动链接：/usr/share/nginx/fenleng-fridge。
- 配置：/etc/nginx/conf.d/fenleng-fridge.conf。
- 站点发布入口：/opt/fenleng-websites/fenleng-fridge/uploads/41f6bc67b6df/deploy_preview.py。
- 回滚快照：/opt/fenleng-websites/fenleng-fridge/backups/41f6bc67b6df。
- 证书：/etc/letsencrypt/live/fridge.fenlengtech.com/，公开证书有效期至2027-02-11；不读取或复制私钥值。
- 自动续期：复用已启用certbot.timer；专用deploy hook为/etc/letsencrypt/renewal-hooks/deploy/fenleng-fridge.sh，只匹配本域名lineage后执行nginx校验/重载，实际触发与HTTPS检查已验证。

当前APK为0.1.0（ARM64分包versionCode2001）、com.fenlengtech.fridge、71877247字节，SHA256为1e13091b421b214f0056d5f2c3488b13fdb2b4d0dd83770f47a549764f820654；固定签名证书摘要仍为844fb2a1f368a875b79bf54b8e9859120ce80f9ecc0fbc1538ff41718e3f86e5。网站20语言明确显示开发预览/Debug/未加固，法律页仍为V0.4中文审阅草案。正式AppID/服务Provider和商店状态未被本轮发布改变。

## 回滚（须对应Owner操作授权）

```text
ssh root@121.199.10.6 "cd /opt/fenleng-websites/fenleng-fridge/uploads/41f6bc67b6df && python3 deploy_preview.py rollback"
```

本次更新前已有35efd85c3910站点；该快照回滚会恢复原站点配置、活动链接及旧APK，再校验/重载Nginx。版本目录、候选ZIP、证书、续期hook和备份仍保留可恢复路径，不删除其他产品，不自动销毁证书。r3入口只安装续期hook，不能把r3的hook快照当作r2站点回滚快照。

## 已知过程与验证范围

第一轮在证书签发和重载后立即健康检查，旧worker短暂返回默认站点证书，固定脚本自动恢复原配置/链接。随后补有上限的就绪重试；r2使用同一不可变内容和已签发证书，第二次健康检查成功。11项本地测试覆盖摘要/目录穿越/符号链接/不可变目录/回滚/重试上限。r1失败日志与r2成功日志同时保留，不把失败抹成一次通过。

线上HEAD返回200、正确APK MIME/长度/no-cache/attachment，Range返回206及正确Content-Range。服务器侧和直连Chromium的HTTP/2分段请求成功。使用本机7897代理的Chromium HTTP/2出现停滞，诊断中相同范围的HTTP/1.1成功；浏览器仅临时映射实际服务器IP来隔离本机fake DNS，没有修改全局代理、hosts或HTTPS信任。页面和实际下载发起已验证，浏览器下载测试主动取消以避免重复200MiB传输；独立HTTP全量下载及最终哈希以部署证据结果为准，不把局部分段检查说成完整浏览器下载。

PromptManager、Scanister、轻食官网部署前后均200。未执行真实Android微信操作或物理手机安装；微信内请按页面提示转系统浏览器下载，实际手机验收保留待办。Owner要求暂不安装模拟器继续有效。

本地维护源码在03-deployment/scripts；生产只运行已校验并登记的固定入口。后续发布须冻结新的内容/脚本摘要、登记新版本、备份和健康检查，不覆盖旧制品或借用其他项目发布身份。正式中国发行继续按原正式签名、加固、真机门禁执行。CLI矩阵尚未登记冰箱时返回CROSS_PROJECT_DENIED，本次依既有OPC-SSH-001和Owner明确授权使用固定SSH通道，没有修改Base治理资产。

2026-11-13包体优化更新：使用update动作核对精确旧内容、备份、原子切换并复用现有证书；12项部署工具测试通过。原首次绑定r2和续期r3证据作为历史保留，当前站点回滚须使用41f6bc67b6df入口。当前下载仅ARM64；其他架构包保留本地。全量外网下载71,877,247字节与新SHA一致。
