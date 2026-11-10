# 微信开放平台移动应用创建与 App 登录接入

> 适用范围：Fenleng 矩阵中需要在微信开放平台创建“移动应用”的 iOS、Android 或鸿蒙 App。
>
> 本文不适用于“网站应用”或“小程序”。网站应用使用 `fl-wechat-website-application` Skill；小程序使用对应的小程序流程。
>
> 微信开放平台的页面字段、限制、审核要求和平台接入项可能变化。本文以 Owner 于 `2026-08-31` 提供的“创建移动应用”页面内容为当前基线；每次执行仍必须以当日后台页面为准。

## 1. 入口、账号和执行边界

1. 打开 [微信开放平台](https://open.weixin.qq.com/)，进入“管理中心 → 移动应用 → 创建移动应用”。
2. Owner 已于 `2026-08-31` 确认登录账号为 `diamondorange233@gmail.com`，与网站应用 Knowledge 使用同一账号。执行时仍不得把账号标识理解为对密码、验证码、管理员扫码或提交审核的自动授权。
3. 本 Skill 和目标项目只记录登录账号标识，不记录密码、短信验证码、二维码、Cookie、AppSecret、Token 或管理员微信个人信息。
4. AI 可以在目标项目内准备申请资料和执行本地验证；登录开放平台、管理员扫码、提交审核、修改已上线应用和上传资料都属于外部操作，必须取得 Owner 对本次具体操作的明确授权。

## 2. 目标项目产物契约

当用户要求某个 FL 项目准备微信移动应用申请时，执行者必须先定位该项目根目录和真实 App 根目录，再在**目标项目**中生成以下产物，不得生成到 `fenlengtechbase`：

```text
docs/wechat-open-platform/mobile-application/
├── 基本信息.md
├── Android信息.md
├── iOS信息.md
└── assets/
    ├── 移动应用图片-28.png
    ├── 移动应用高清图片-108.png
    ├── 运行流程图-01-{步骤}.png
    ├── 运行流程图-02-{步骤}.png
    └── ...
```

- `基本信息.md` 必须按 [基本信息模板](../assets/wechat-mobile-application-basic-information.md.template) 生成，所有结论必须能追溯到目标项目源码、配置、应用市场页面或 Owner 输入。
- Android 项目必须按 [Android 信息模板](../assets/wechat-mobile-application-android-information.md.template) 生成 `Android信息.md`；iPhone 或 iPad 项目必须按 [iOS 信息模板](../assets/wechat-mobile-application-ios-information.md.template) 生成 `iOS信息.md`。未开发的平台也要在对应文档或 `基本信息.md` 中明确标记“不适用”，不得把一个平台的事实推断到其他平台。
- 两张移动应用图片必须来自目标 App 当前应用市场图标或准备提交应用市场的同一批准源图，不得用生成式 AI 重绘、添加文字、水印、边框或更换构图。
- 运行流程图必须由目标 App 的 golden test / screenshot test 驱动真实界面生成；不得用手绘流程图、Figma 草图或静态拼图冒充实际运行结果。
- `{步骤}` 使用简短、稳定、不含空格的中文或 ASCII 名称；文件按用户真实路径从 `01` 连续编号。微信后台当前最多接收 10 张流程相关图片，因此默认生成 3–8 张，只有真实业务需要时才扩展到 10 张。
- 目标项目已有等价且更严格的文档目录时可以沿用，但必须在 `基本信息.md` 的“产物位置”中记录实际路径；不得同时维护两套申请资料。

这些产物可以进入目标项目版本控制，但不得包含 Secret、真实测试密码、个人二维码、Cookie、Token 或生产用户数据。临时登录态、后台截图和上传缓存应放在项目忽略的临时目录，不得提交。

当生成或复核 Android 或 iOS 签名信息时，目标项目还必须生成并 Git 跟踪以下公开登记文件：

```text
05-knowledge/signinfo/application-signing-info.json
```

该文件用于集中保存备案所需的应用名称（含中文名称）、后台域名、Android 包名、iOS Bundle ID、Android/iOS 证书指纹、公钥和签名定位。iOS 同时登记 Team ID、证书 ID 和证书名称；钥匙串身份使用 `login-keychain:<证书名称>` 这种稳定定位，不记录私钥导出文件。它不是阿里云后台表单或业务数据库模型；字段仍使用备案字段名，便于人工填报。文件中不得保存密码、私钥、AppSecret、Token 或 keystore 内容。

## 3. 创建页面当前字段基线

### 3.1 基本信息

| 字段 | 当前要求与填写规则 |
| --- | --- |
| 移动应用名称 | 2–20 字节，一个中文按两个字节计算；会显示在微信分享、收藏、登录、支付等用户授权场景中；当前页面提示半年只能修改 1 次。必须与应用市场和应用内品牌一致。 |
| 英文名称 | 选填，显示在英文版微信中；没有已确认英文品牌时留空，不临时直译。 |
| 移动应用简介 | 最多 80 字，描述实际核心能力，不写未实现功能。 |
| 英文简介 | 选填，最多 80 字；只有目标项目已有确认英文文案时填写。 |
| 应用官网 | 填可公开访问的 HTTPS 应用官网或当前应用市场下载页；页面应包含应用介绍、下载或上架信息、用户协议和隐私政策。 |
| 移动应用图片 | `28 × 28` PNG，不超过 300 KB，必须与应用市场图标完全一致。 |
| 高清参考图片 | `108 × 108` PNG，不超过 300 KB，必须与应用市场图标完全一致。 |
| 应用市场 | 在“未上架任何应用市场”和“已上架至少一个应用市场”中按事实选择；该选择同时影响 Android、iOS 和鸿蒙状态。不得为了减少审核材料虚报上架状态。 |
| 应用类目 | 当前为选填；只有类目已经申请或符合当日页面规则时选择。带登录态 Token 的“点击申请”链接不得写入 Knowledge。 |
| 应用运行流程图 | 上传能说明真实运营业务的 App 运行截图、交互设计图或流程逻辑图；当前页面最多 10 张，支持 JPG、JPEG、BMP、GIF 或 PNG，单张不超过 5 MB。FL 项目默认使用 golden test 生成的 PNG。 |
| 申请/修改应用说明 | 最多 200 字；说明本次申请目的、主要能力、平台范围和必要审核提示。需要测试账号时，只在获得授权的开放平台会话中填写，不把密码写入项目。 |
| 管理员身份设置 | 使用管理员本人微信扫描页面二维码；注册后扫码微信号成为该移动应用管理员。二维码和管理员微信信息不得保存到项目。 |

### 3.2 未上架应用当前限制

当页面选择“未上架任何应用市场”时，`基本信息.md` 必须明确记录以下当前页面提示，不得把申请成功描述为无限制生产可用：

- 分享量限制为 100 次/天，包含分享到会话和朋友圈；
- App 跳转小程序调用量限制为 100 次/天；
- 已认证主体的微信登录用户次数限制为 100 次/天；
- 一次性订阅消息调用量限制为 100 次/天。

这些数值是 `2026-08-31` 的页面基线。实际提交和上线判断必须重新读取当日页面；规则变化时更新本 reference 后再继续。

### 3.3 应用平台信息

基本信息完成后，进入“填写应用平台信息”。Android、鸿蒙、iPhone 和 iPad 分别按真实工程选择“开发：是/否”。Android 包名和 iOS Bundle ID 必须尚未配置到微信开放平台的其他移动应用，并与正式发布构建一致；不得为了通过页面校验临时填写测试包标识。

#### Android 应用

| 字段 | 当前要求与填写规则 |
| --- | --- |
| 开发 Android 应用 | 目标项目存在正式 Android 工程且本次接入时选“是”，否则选“否”。 |
| 应用签名 | 填由当前 App 专用 keystore 对应用签名后得到的微信平台签名值。必须按[微信官方 Android 签名生成指引](https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/miniapp/handbook/build/open_android_cert.html)从真实安装包或同一签名证书复核，不填 SHA-256 文件摘要代替。 |
| 应用包名 | 读取正式 Android `applicationId` / Manifest 包标识，例如 `com.tencent.mm`；必须与正式发布包一致。 |
| 应用已上架 | 按事实选择“否/是”。该选择同时影响 Android、iOS 和鸿蒙状态；选择“否”时保留 3.2 节限制。 |
| 开发方式 | 当前页面基线为“传统模式开发”。 |

同一移动应用的 Android 正式构建与测试构建默认必须使用**同一套项目专用 keystore、key alias 和签名证书**，确保微信应用签名稳定。不得继续把 Android SDK 的共享默认 debug keystore 当作正式签名，也不得为每次构建临时生成新证书。若应用已经上架或已有真实用户安装包，必须复用既有正式证书；找不到既有证书时停止，不得生成新证书冒充原签名。

#### iPhone 与 iPad 应用

| 字段 | 当前要求与填写规则 |
| --- | --- |
| 开发 iPhone / iPad 应用 | 分别按 Xcode `TARGETED_DEVICE_FAMILY` 和真实支持范围选择“是/否”。同时支持 `1,2` 时 iPhone、iPad 均为“是”。 |
| Bundle ID | 填正式 iOS App 的唯一 Bundle ID，必须与 Xcode Release 配置一致且未绑定其他微信移动应用。 |
| 测试版本 Bundle ID | 填实际测试构建使用的 Bundle ID。同一 App 的正式与测试构建共用 Bundle ID 时填写同一值；存在单独测试 Target 时按事实填写，不能猜测。 |
| Universal Links | 必须为 HTTPS，以 `/` 结尾，建议使用专用 path，例如 `https://example.com/app/`。该路径必须能唤起当前 App，并与 Xcode Associated Domains、Apple App Site Association 文件及实际 SDK 调用完全匹配。只写候选 URL、但未配置关联域和线上 AASA 时只能标记“待配置”，不得报告可提交。 |
| 应用已上架 | 按事实选择“否/是”，并与 Android/鸿蒙选择保持同一真实状态。 |
| 开发方式 | 当前页面基线为“传统模式开发”；接入前阅读[iOS 接入指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)。 |

Android、iOS 或鸿蒙以 SDK 方式接入微信开放能力前，必须阅读并遵守[《微信 Open SDK 个人信息处理规则》](https://support.weixin.qq.com/cgi-bin/mmsupportacctnodeweb-bin/pages/RYiYJkLOrQwu0nb8)，同步检查应用隐私政策、第三方 SDK 清单、初始化时机、授权提示和实际数据处理行为。

### 3.4 Android 签名资产与私有仓库例外

默认治理仍是密码、私钥和 Secret 不进入 Git。只有同时满足以下条件时，才允许把 Android 专用签名资产提交到目标项目：

1. Owner 对**具体项目**明确说明该仓库是受控私人仓库，并明确授权将 keystore、store password、key alias 和 key password 提交到 Git；普通“生成申请材料”请求不自动构成授权。
2. 执行者通过远端配置和可用仓库证据确认目标是 Owner 指定的私有仓库；仓库可见性不明、存在公开镜像、Fork 或外部协作者边界不明时停止提交。
3. 签名资产只服务一个 App，不跨项目复用；正式与测试构建使用同一套。已有发布证书时只能复用，不得重新生成。
4. 目标 Flutter/Android 项目的固定位置为：

   ```text
   <app-root>/android/signing/
   ├── application-release.jks
   └── credentials.properties
   ```

   `credentials.properties` 至少包含 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`。Gradle 的 debug 与 release `signingConfig` 必须读取同一文件，禁止在构建脚本中再复制一份密码。历史项目仍使用 `android/key.properties` 时，该文件适用完全相同的人类控制边界。
5. `Android信息.md` 只记录签名文件路径、alias、微信应用签名、证书指纹和验证证据，不复制密码；密码值只存在于上述凭据文件。公开登记元数据固定保存到目标项目 `05-knowledge/signinfo/application-signing-info.json`，可进入 Git；签名凭据目录本身仍不得位于目标项目 `fenleng.project.yaml` 的 Knowledge roots 内，避免 Project Knowledge MCP 暴露。
6. 生成和验证过程不得在命令、标准输出、日志、测试报告或聊天中回显密码。提交前确认 Git 远端、文件权限、`git diff --cached` 范围和仓库访问成员；提交后所有仓库读者都应被视为已经获得该签名身份。
7. 仓库改为公开、成员权限失控、keystore 或密码泄露时立即停止发布，按应用市场和微信平台能力评估轮换/迁移；不能把“私有仓库”描述为硬件密钥或独立 Secret Vault。
8. AI 默认禁止创建、修改、覆盖、迁移、删除或轮换 `android/key.properties`、`android/signing/credentials.properties` 和 keystore。即使发现疑似泄露、路径不标准或构建失败，也只能报告事实并等待 Owner 对具体项目和具体动作明确授权；不得把安全处置建议解释为授权。获准执行时仍不得回显任何凭据值。

9. 生成或复核签名规则时，必须同步维护 `05-knowledge/signinfo/application-signing-info.json`。该文件只写公开证书指纹、公钥、包标识、Bundle ID、后台域名、应用名称和签名文件路径；签名配置路径可以记录，但不得复制配置内容。字段缺失时写 `null` 并在 `fieldStatus` 标记 `pending-owner-evidence`，不得猜测或用其他平台证书代填。

10. iOS 项目在 Day 1 确定 Team ID、正式 Bundle ID 和可复用的 Apple Distribution 身份，并登记证书 SHA-1、公钥、证书 ID、证书名称及钥匙串身份。Distribution 证书可服务同一 Team 下多个 App；每个 App 仍须使用自己的显式 App ID 和 App Store Provisioning Profile，并登记 Profile ID、名称和到期日。Debug/开发安装由 Apple Development 身份签名，Release/归档由 Apple Distribution 身份签名，不能强行让两者使用同一张证书。

11. Owner 已接受私人仓库保存签名身份的风险模型时，每个 iOS App 在 `<ios-root>/signing/apple-distribution.p12` Git 跟踪一份可恢复的正式证书与私钥归档，并把相对路径登记到 `signingPath_IOS`。若归档密码也会与文件进入同一仓库，允许明确登记 `signingArchivePasswordMode_IOS: empty`，避免密码丢失形成不可恢复故障；仓库转为公开或访问成员变化时只报告影响，不擅自删除、轮换或阻断发布。

未满足上述显式例外时，keystore 和密码继续保存在受控凭据库，项目只提交路径、alias 和指纹元数据。

## 4. `基本信息.md` 生成规则

1. 从目标项目的 Manifest、MVP、应用官网登记、商店元数据、移动端配置和 Owner 输入收集字段，不得用仓库名猜应用名，不得把开发域名当作应用官网。
2. 对每个字段标注 `已确认`、`待 Owner 确认`、`待上架后补充` 或 `不适用`。任何必填字段仍为待确认时，整体状态只能是 `draft`，不得报告“资料已可提交”。
3. 应用名称、简介和申请说明分别做字节数或字数校验，并把实测值记录在文档中。名称按当前页面规则初筛：中文计 2 字节、ASCII 字符计 1 字节；其他字符或组合字符以微信页面的最终计数为准，不得直接使用 UTF-8 编码字节数代替平台口径。
4. 记录两张图标的源文件、源文件 SHA-256、输出路径、像素尺寸、PNG 格式和文件大小；源文件或应用市场图标变化后必须重新导出并重新验证。
5. 生成 `Android信息.md` 和 `iOS信息.md`，记录包标识、签名、Bundle ID、Universal Links、上架状态、开发方式、OpenSDK 合规确认和各自证据；平台必填项缺失时保持 `draft`。
6. 记录 golden test 源文件、执行命令、通过时间、目标视口、测试数据来源和每张流程图对应的用户步骤。
7. 测试账号只记录凭据库条目名或 Owner 交付方式，例如 `credentialVaultRef: wechat-review-account`；不得记录账号密码组合。若开放平台必须展示明文，只有在 Owner 授权的浏览器会话中临时填写。
8. `基本信息.md` 是申请资料索引，不是提交成功证据。提交时间、审核结果和 AppID 只有在真实发生并取得证据后才能回填。

## 5. 移动应用图片生成与验证

1. 优先使用应用市场实际使用的最高分辨率图标；未上架时使用本次准备提交应用市场的同一批准源图，并在 `基本信息.md` 标记“待上架一致性复核”。
2. 源图必须为正方形。若源图不是正方形或不同平台商店图标不一致，停止生成并请求 Owner 选择权威图标，不自行裁切或合成。
3. 从同一源图分别等比缩放到 `28 × 28` 和 `108 × 108`，保持原色彩、透明通道和完整构图。不得二次锐化、圆角化、加水印、替换背景或重新设计。
4. 输出文件必须是 PNG，分别命名为 `移动应用图片-28.png` 和 `移动应用高清图片-108.png`，单张不超过 300 KB。
5. 生成后确定性检查宽、高、文件类型、文件大小和 SHA-256，并在浅色与深色背景各进行一次人工可辨识性检查。
6. 若平台自动套用圆角或遮罩，只提交未经额外套壳的权威图标；最终以当日上传预览为准。

## 6. 运行流程图的 golden test 契约

### 6.1 内容范围

流程图应按顺序覆盖审核人员理解产品所需的最短真实路径：

1. 启动或首页，能识别应用名称与核心入口；
2. 进入核心业务；
3. 完成一段核心交互并显示结果；
4. 涉及微信登录、分享、收藏、支付或跳转小程序时，增加对应功能入口和调用前的应用页面；不得伪造微信系统授权页。

只生成与当前申请能力有关的页面。不得为了凑数量加入空页面、调试页、后台页或尚未实现的设计稿。

### 6.2 测试和输出要求

- Flutter 项目使用 `flutter_test` 的 `matchesGoldenFile` 或项目已有等价 golden 基础设施；其他端使用项目已建立的确定性 screenshot test，并在 `基本信息.md` 说明等价关系。
- Golden test 必须启动真实 App Widget / 页面组件并按用户顺序执行点击、滚动和状态转换；不得直接把设计图复制为 golden 文件。
- 使用固定视口、设备像素比、字体、语言、时区、主题和确定性 fixture；隐藏状态栏中的个人信息，禁止连接生产账号和生产数据。
- 每张 PNG 对应一个清晰步骤，按 `运行流程图-{序号}-{步骤}.png` 输出到申请目录的 `assets/`。若测试框架先输出到测试基线目录，执行者必须通过项目脚本确定性同步到申请目录，并记录源路径和命令。
- 生成后重新运行测试且不带更新参数，确认 golden 比对通过；仅生成新基线但未做第二次比对，不算验证完成。
- 每张图片必须小于 5 MB。上传前人工核对顺序、文字可读性、真实品牌、核心业务连续性和隐私遮挡。

## 7. 提交、管理员设置与审核状态

1. 上传前逐项核对 `基本信息.md`、应用官网、应用市场状态、图标和流程图，确认页面看到的名称与资料一致。
2. 需要测试账号时，先确认这是专用审核账号、权限最小、数据为测试数据且可在审核期使用；凭据仅通过批准的凭据渠道交付。
3. 管理员本人在已授权的会话中扫码。不得截图二维码转交、共享管理员微信或把扫码结果当作可复用凭据。
4. 提交后只在有真实页面证据时将状态从 `owner-reviewed` 更新为 `submitted`；审核通过后更新为 `approved` 并记录 AppID 的非敏感标识。审核驳回则使用 `changes-required`，记录驳回原因和下一次变更，不覆盖历史。
5. AppSecret 只能保存在服务端凭据库；不得进入移动端、Git、Knowledge、构建参数、日志或截图。

## 8. 审核通过后的接入

- Android、iOS 和鸿蒙分别按微信开放平台当日显示的包标识、签名或关联域配置完成平台登记；不得把一个端审核通过推断为其他端已经可用。
- 微信登录、分享、收藏、支付和跳转小程序是不同能力，必须分别验证当前应用已获权限、SDK 配置正确且真实设备 smoke 通过。
- 移动客户端只持有公开 AppID 和平台允许的公开配置；授权 code 交给 Fenleng Shared Platform 服务端换取微信凭据和 Fenleng Session，客户端不得持有 AppSecret。
- 至少验证：用户取消、重复回调、错误 AppID、签名或关联域不匹配、首次登录、已有账号续登、服务端拒绝和安全回退；日志不得记录完整 code、Token、AppSecret 或个人资料。

工程实现必须先检查目标项目 Experience Manifest、依赖锁、Android/iOS 原生入口和现有身份架构，再选择目标项目已经声明或当前官方指南支持的 SDK/Flutter 插件，不以本 reference 固定第三方包版本。Flutter 项目遵守 `fl-ai-coding-delivery/references/domain-flutter-architecture.md`，并完成以下验证：

1. Android 的正式 `applicationId`、微信平台签名值、SDK 注册 AppID、回调 Activity 所在包路径、Manifest 和混淆配置彼此一致，真实安装包能收到并处理授权回调。
2. iOS 的正式 Bundle ID、URL Scheme、Universal Links、Associated Domains、AASA、App/Scene 生命周期回调转发和 SDK 注册值彼此一致，真实设备能完成唤起与回调。
3. 客户端只把一次性授权 code 交给 Fenleng Client SDK 或 Shared Platform 当前契约声明的入口。必须通过带 commit/ref 的 Fenleng Project Knowledge 读取 `fenleng-shared-platform` 身份 OpenAPI、Schema 和接入 Runbook；入口或错误模型不存在时停止，不在业务项目手写底层 HTTP 或猜字段。
4. 服务端完成 code 交换、Fenleng Session 签发、账号绑定/冲突处理、幂等和错误映射；客户端只持久化 Fenleng access/refresh token，不持久化微信 code、access token 或 refresh token。
5. 自动测试覆盖授权取消、重复回调、错误 AppID、签名/关联域不匹配、服务端拒绝和安全回退；真实设备 smoke 覆盖首次登录和已有账号续登。任何平台只完成模拟测试时不得标记为已接入。

### 8.1 目标项目 Knowledge 沉淀

申请草稿、后台填报材料和审核过程继续保存在目标项目 `docs/wechat-open-platform/mobile-application/`，不得作为“已接入”事实。只有审核通过、SDK 配置完成并通过真实设备验证后，才更新目标项目自己的 Project Knowledge：

1. 读取目标项目 `fenleng.project.yaml`，复用已声明 Knowledge root 中现有的第三方接入或应用身份目录；没有同类目录时，在声明根内创建 `integrations/wechat-mobile-application.md`，不得写到未暴露目录或 `fenlengtechbase`。网站应用使用 `fl-wechat-website-application` Skill，不复用本移动应用流程。
2. 记录项目 ID、移动应用名称、微信移动应用 AppID、审核状态、审核通过时间、已验证时间、适用平台和已开通能力。
3. Android 记录正式包名、微信应用签名、证书 MD5/SHA-256 指纹和证据；iOS 记录正式/测试 Bundle ID、Universal Links、Associated Domains、AASA 和真实设备唤起证据；鸿蒙按真实平台字段记录。
4. 记录 AppID 的客户端配置键、服务端映射、应用官网、应用市场页面、审核页面证据引用、真实设备 smoke 结果和最后复核时间。
5. 只记录已观察事实。未完成的能力明确标记状态和阻断原因，不把 `submitted`、候选 URL、候选签名或计划配置写成已接入。
6. AppSecret、密码、验证码、Cookie、Token、二维码、测试账号密码、管理员微信个人信息和生产用户数据不得进入 Knowledge。

## 9. 提交前验收清单

- [ ] 已按当日微信开放平台页面复核字段、限制和上传规格。
- [ ] 登录账号使用 Owner 已确认的 `diamondorange233@gmail.com`。
- [ ] `基本信息.md` 的必填字段均有证据，状态至少为 `owner-reviewed`。
- [ ] 移动应用名称、简介和申请说明已完成长度校验。
- [ ] 应用官网可公开访问并与应用名称、功能、协议和隐私政策一致。
- [ ] 应用市场状态按事实填写，未上架限制已明确记录。
- [ ] Android 包名、应用签名、签名资产路径和正式/测试同签名证据已经复核；不开发 Android 时已明确标记不适用。
- [ ] iPhone/iPad Bundle ID、测试 Bundle ID、Universal Links、Associated Domains 和 AASA 已一致复核；不开发对应平台时已明确标记不适用。
- [ ] Android/iOS/鸿蒙上架状态结论一致，且没有复用其他微信移动应用已经配置的包名或 Bundle ID。
- [ ] 已阅读 OpenSDK 个人信息处理规则，并核对隐私政策、第三方 SDK 清单和初始化/授权行为。
- [ ] 如使用私有仓库签名例外，Owner 授权、仓库私有性、固定路径、Git 范围和不回显验证均已完成。
- [ ] 28 × 28 与 108 × 108 PNG 来自同一权威图标，且与应用市场图标一致。
- [ ] Golden test 从真实 App 生成 3–10 张连续流程图片，第二次比对通过。
- [ ] 每张流程图小于 5 MB，顺序、文字、隐私遮挡和业务连续性已人工复核。
- [ ] 测试账号使用最小权限和测试数据，密码未进入项目或 Knowledge。
- [ ] Owner 已授权本次登录、管理员扫码、上传和提交操作。
- [ ] AppSecret、Token、二维码、Cookie 和生产用户数据未进入任何申请产物。

## 10. 证据与维护

- 官方入口：[微信开放平台](https://open.weixin.qq.com/)。公开首页确认移动应用可接入微信分享、收藏和支付；登录后的创建页面字段以 Owner 于 `2026-08-31` 提供的页面内容为本次基线。
- Android 签名：[微信开放平台移动应用 Android 签名生成指引](https://developers.weixin.qq.com/miniprogram/dev/platform-capabilities/miniapp/handbook/build/open_android_cert.html)，`2026-08-31` 复核 HTTP 200。
- iOS 接入：[微信开放平台 iOS 接入指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)，`2026-08-31` 复核 HTTP 200。
- SDK 隐私：[微信 Open SDK 个人信息处理规则](https://support.weixin.qq.com/cgi-bin/mmsupportacctnodeweb-bin/pages/RYiYJkLOrQwu0nb8)，`2026-08-31` 复核 HTTP 200。
- 主体与凭据边界：`knowledge/organization/README.md`、`knowledge/operations/credential-vault.md`。
- 应用官网与协议：`knowledge/application-websites/README.md`、`knowledge/application-websites/application-website-integration-template.md`。
- 本 reference 最后复核日期：`2026-08-31`。

微信字段、应用市场限制、图像规格、类目、审核政策或平台接入项变化时，先更新本 reference 的“当前事实”，再执行新的申请；不得把带会话 Token 的申请链接、管理员二维码或一次性后台地址写入 Skill 或 Knowledge。
