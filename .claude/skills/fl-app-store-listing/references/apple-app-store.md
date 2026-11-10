# Apple App Store 上架信息

来源：Apple Developer / App Store Connect 官方帮助，核验日期 2026-09-20。本文件是执行摘要，不替代控制台；Apple 会调整表单、SDK/Xcode 和截图规格，当前提交判断必须重新核验官方页面。

## App 记录与权限

- 上传构建前先在 App Store Connect 创建 App 记录；Account Holder 必须先接受最新协议。
- 创建 App 记录需要 Account Holder、Admin 或 App Manager；上传构建还可由 Developer 执行。
- 记录包含平台、名称、主要语言、Bundle ID、SKU 和用户访问范围。Bundle ID 必须与构建一致。
- 官方来源：[创建 App 记录](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)、[上传构建](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)。

## 包名与构建渠道隔离 (Bundle ID & Build Channels)

为符合不同国家/地区的合规监管及数据出境要求，中国大陆及海外发行版本必须实施工程级的“硬隔离”，严禁在同一个 Bundle ID 对应的同一个二进制包中混淆使用两套策略。

- **国内版（中国大陆发行）**：
  - **包名 (Bundle ID)**：使用标准包名（如 `com.company.app` 或 `com.company.app.cn`）。
  - **构建渠道**：打包时必须使用 `china` 渠道配置，强制包含首启隐私门禁、国内第三方服务，并在应用内提供 APP 备案信息展示。
  - **发行与合规**：App Store Connect 发行地区仅限“中国大陆”，且必须提供与开发者主体一致的工信部 APP 备案号。
- **海外版（全球其他地区发行）**：
  - **包名 (Bundle ID)**：必须在标准包名后增加 `.en` 后缀（如 `com.company.app.en`）。
  - **构建渠道**：打包时必须使用 `global` 渠道配置，剔除中国区特有的强阻断弹窗门禁，使用海外通用合规及账号体系（如 Firebase / Apple 登录）。
  - **发行与合规**：App Store Connect 发行地区全选并**剔除“中国大陆”**；不需要且不得展示工信部 APP 备案号。
- **独立记录**：国内版与海外版在 App Store Connect 中必须作为两款完全独立的 App 记录进行创建和维护。

## App 级与版本级字段

- App 级：名称、主要语言、Bundle ID、SKU、类别、年龄分级、内容版权、可用地区、App 隐私和中国大陆备案信息。
- 本地化产品页：副标题、宣传文本、描述、关键词、支持 URL、营销 URL、版权、截图/预览。
- 版本级：Marketing Version、Build Number、版本更新说明、所选构建、审核信息和发布方式。
- App 名称每个本地化最多由一个 App 使用；字段实际字符限制以当前控制台为准，生成产物要记录本地 Unicode 字符数。
- 官方来源：[App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)、[平台版本信息](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)。

## 首次提交执行顺序

生成项目产物时按以下顺序给出清单，不按资料发现顺序堆放：

1. 确认 App Store Connect 版本与构建的 `CFBundleShortVersionString` 一致，同版本 `CFBundleVersion` 未被使用。
2. 在“定价与销售范围”选价格；免费且无内购的 App 选“免费”。
3. 在“App 隐私”完成数据类型、用途、身份关联和跟踪问卷，填公开隐私政策 URL；URL 和问卷是两个独立门禁。
4. 按本地化语言填描述、关键词、技术支持 URL、版权，按需填宣传文本和营销 URL；路由覆盖地区文件只属于路由 App，轻 App/iMessage 只在实际包含时配置。
5. 上传 1–10 张当前平台接受尺寸的真实 iOS/iPadOS 截图，不用 Android 截图或拉伸素材代替。
6. 使用 Xcode/Transporter/API 上传构建，等待 Apple 处理，然后在当前版本选择该构建。
7. 根据最终二进制回答加密出口合规；只访问 Apple 系统 HTTPS/Keychain 等豁免能力时可按实际声明 `ITSAppUsesNonExemptEncryption=false`，但必须同时核对所有 SDK。
8. 填写审核登录账号、完整登录路径、联系人姓名/电话/邮箱和审核备注；最终构建中实测账号。
9. 选择审核通过后手动、自动或定时发布；首次上架需复核时优先记录“手动发布”为建议，不代替 Owner 决策。
10. 保存后逐项清除页面错误，只在构建已选、必填项齐全且人类明确授权时“添加以供审核”。

无 App 内购、付费或自动续期订阅时，生产/沙盒 App Store 服务器通知 URL 均留空，App 专用共享密钥不生成。这些不是免费 App 提审门禁。

## 截图与图标

- 每个支持的设备尺寸与语言可上传 1–10 张截图，格式为 `.jpeg`、`.jpg` 或 `.png`，不得含 alpha/透明通道；App Preview 可选。
- 若界面在多设备尺寸一致，可只提供官方当前允许的最高分辨率截图并让 App Store Connect 缩放；iPhone、iPad 支持范围必须与构建实际一致。
- 2026-09-20 官方 iPhone 常用竖屏规格包括：6.9 英寸 `1260×2736`、`1290×2796`、`1320×2868`；6.5 英寸 `1242×2688`、`1284×2778`；6.3 英寸 `1179×2556`、`1206×2622`。横屏使用对应互换尺寸。提交时以当前官方规格页为准。
- 商店图标由构建中的 App Icon 提取；1024×1024 marketing icon 必须无 alpha。不得单独上传与构建不一致的品牌图标。
- 官方来源：[上传截图](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)、[截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)。

## 隐私、SDK 与账号注销

- iOS 必须提供公开可访问的隐私政策 URL，并在 App Privacy 回答数据类型、用途、是否关联身份、是否用于追踪。
- 声明必须覆盖开发者和第三方 SDK/合作方的实际数据处理；不能只核对自有代码。
- App 内存在账号创建时，核对账号注销入口及隐私政策说明；审核账号不得替代真实注销能力。
- 隐私选择 URL 可选，可指向访问、更正、删除数据的说明或入口。
- 官方来源：[管理 App 隐私](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)、[App 隐私字段](https://developer.apple.com/help/app-store-connect/reference/app-privacy/)。

## 年龄分级、内容版权与中国大陆

- 年龄分级是必填 App 级字段，按 App 实际控制能力、用户生成内容、暴力、成人、医疗、随机活动等问卷回答；不能按期望等级倒推答案。
- 展示、访问或分发第三方内容时，必须确认具有相应权利并按控制台填写 Content Rights。
- 中国大陆可用时，按 App Store Connect 当前字段提交与工信部记录一致的 ICP/APP 备案信息；主体、包名和简体中文元数据不一致时不能标记为完成。
- 官方来源：[设置年龄分级](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)、[App 信息](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)。

## 审核信息与登录账号

- 记录联系人姓名、电话、邮箱、审核备注；涉及登录时提供长期可用的审核账号、密码和完整路径。
- 特殊硬件、地理位置、企业网络、验证码或第三方登录依赖必须给出可复现说明或替代访问方式。
- 审核期间后端、隐私政策、支持页面和账号保持可用。准备资料不自动授权提交审核。
- 官方来源：[提交 App 供审核](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app-for-review)。

## 出口合规与加密

- 根据构建实际使用的加密回答 Export Compliance；HTTPS、系统加密、第三方 SDK 或自研密码能力均需纳入判断。
- 不因“只使用 HTTPS”直接写成“不使用加密”；是否豁免、是否需要文档以当前问卷与适用法规为准。
- 若通过 `Info.plist` 声明豁免，仍需与实际二进制和后台回答一致。
- 官方来源：[确定出口合规要求](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)。

## 构建、上传与发布

- Bundle ID 和 Marketing Version 用于关联 App/版本；Build Number 在同一版本上传中必须唯一，后台已使用的构建号不得复用。
- 使用受支持的 Xcode、Transporter 或 App Store Connect API 上传；上传成功不等于可选，需等待 Apple 处理完成。
- 处理后选择构建，完成隐私、出口合规、内容版权、年龄分级与审核信息，再加入审核并提交。
- 发布方式可为审核通过后自动发布、手动发布或不早于指定日期发布；首次上架若需发布前复核，记录为人工选择，不在模板中默认。
- 官方来源：[上传构建](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)、[选择构建](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit)。

## 内购专属字段

- App Store 服务器通知用于 App 内购的购买、续费、退款、撤销等事件；只有实际实施服务端通知时才填可公网 HTTPS 访问的生产/沙盒端点。
- App 专用共享密钥用于自动续期订阅收据场景；不属于无订阅 App 的必填材料，不应生成后写入项目知识或通用 Skill。
- 官方来源：[App Store 服务器通知 URL](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications)。

## 状态语义

- `已确认`：项目事实或实际文件已有证据。
- `草稿`：可复制文案，尚未由 Owner 最终确认。
- `待后台确认`：只能从当前 App Store Connect 得知的名称占用、构建处理或审核状态。
- `待人工填写`：年龄分级、出口合规、隐私标签等需要真实业务判断的问卷。
- `可上传`：文件格式、尺寸、alpha、签名和版本均已验证；不等于已上传。
- `已上传/已处理/已提交/已发布`：必须有平台证据，不能由本地构建推断。
