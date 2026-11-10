# HarmonyOS Day 0 固定应用身份与签名

从Day 0创建正式HarmonyOS应用身份、签名目录和登记；不可把模拟器不签名产物或IDE未关联应用的自动签名当成正式签名完成。华为后台当前要求HarmonyOS包名不与Android应用包名重复，先查后台再固定；已有合法应用身份不得静默变更。

## 固定位置

每个App固定 `<flutter-app-root>/ohos/signing/`：

- `application.p12`：该App长期密钥库，调试/发布共用密钥身份；不存在时经Owner具体授权创建，已有绝不覆盖。
- `application.csr`：与同一密钥对应的公开CSR，供华为签发证书。
- `debug.cer`、`debug.p7b`：华为调试证书和关联注册应用的调试Profile。
- `release.cer`、`release.p7b`：华为发布证书和同一注册应用的发布Profile。
- `credentials.json`：本地密码及固定文件名配置；不输出密码、不写知识资产；按Owner已有凭据契约保管，不擅自迁移或轮换。

华为调试Profile不能选择发布证书。统一指同一Bundle ID、正式appIdentifier、长期密钥和稳定文件路径，不伪造两类证书/Profile可互换；调试/发布证书公钥必须与长期密钥匹配。若Owner要求完全相同证书/Profile，报告平台限制，不生成不可用配置。

公开元数据进入仓库原 `05-knowledge/signinfo/application-signing-info.json` 的 `harmonyos`：bundleName、appIdentifier、签名目录、keyAlias、公钥指纹、debug/release证书和Profile路径与有效期、微信和支付宝登记状态。缺失真实签发材料用null或pending并列明下一步，不能编造Identifier或使用本地证书代替华为证书。

支付宝渠道资料必须明确提供 BundleName 和应用签名：`harmonyos.bundleName` 与工程 `AppScope/app.json5` 的 `app.bundleName` 一致；`harmonyos.release.certificateFingerprintSha256` 保存实际发布签名叶证书的 SHA-256 摘要，调试摘要独立保存在 `harmonyos.debug.certificateFingerprintSha256`。在 `05-knowledge/signinfo/harmonyos-channel-registration.md` 输出发布摘要及其无冒号格式供填写，并标明调试摘要用途；不可用 appIdentifier、公钥摘要或证书链根证书摘要代替应用签名。证书续期后复核最终签名 HAP、更新登记和渠道资料。

## 构建

使用 [固定签名打包脚本](../scripts/package-flutter-harmonyos.mjs)：

```text
node <skill-root>/scripts/package-flutter-harmonyos.mjs <flutter-app-root> debug
node <skill-root>/scripts/package-flutter-harmonyos.mjs <flutter-app-root> release
```

脚本只读取签名材料、验证来源和配对，通过FVM编译并由官方SDK hap-sign-tool按当前模式签名、验证；不把密码写入build-profile，不改上传通道。缺材料明确失败；模拟器不签名试验须显式记录unsigned，不能作为正式构建验收。应用内签名凭据路径不得提交个人绝对路径。

## 外部接入

在华为后台创建应用、取得真实APP ID/appIdentifier；调试和发布Profile关联同一应用。微信开放平台填写Bundle ID和Identifier并审核；支付宝按官方鸿蒙SDK接入说明核对登记、回调和支付资格。两端原有登记不自动覆盖鸿蒙。应用备案、SDK列表和第三方渠道状态同步登记。

官方依据：[调试Profile](https://developer.huawei.com/consumer/cn/doc/doccenter-getting-started/agc-help-debug-profile-0000002248181278)、[微信鸿蒙身份](https://pay.wechatpay.cn/doc/v2/partner/4011941201)、[支付宝鸿蒙SDK](https://opendocs.alipay.com/open/01ysmx)。
