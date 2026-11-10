# 微信开放平台网站应用登记与 Web 登录

> 适用范围：Fenleng 矩阵中需要在 Web 端使用微信开放平台网站应用登录的产品。本 reference 是可复用流程与平台事实基线，不是任何一个应用的审核结果。

## 1. 申请入口与执行顺序

1. 打开 [微信开放平台](https://open.weixin.qq.com/)，使用 Owner 提供的授权账号登录；当前登记邮箱基线为 `diamondorange233@gmail.com`。Knowledge、Skill 和申请材料不得记录密码、AppSecret 或其他长期凭据。
2. 进入“管理中心 → 网站应用 → 创建网站应用”。
3. 填写前从微信开放平台重新下载最新版 [《微信开放平台网站信息登记表》](https://open.weixin.qq.com/zh_CN/htmledition/res/assets/manage/Website_Information_Form.doc)。旧表只作版式参考，不能替代当前法律或审核依据。
4. 先填写应用、网站和主体信息，再核对所有示例文字是否已经替换；不得残留模板中的 `腾讯`、`qq.com`、旧年份或其他应用名称。
5. 经 Owner 本次确认后，使用已授权的签名和主体公章完成签字盖章，打印或导出后逐页检查，再按微信后台要求上传扫描件。
6. 审核通过后，再把同一网站应用 AppID、授权回调域和 Fenleng Shared Platform 的 Web OAuth 配置联调；浏览器端不得保存或使用 AppSecret。

## 2. 主体资料与应用事实

- 主体名称、证照标准名称、统一社会信用代码、注册地址、负责人、联系方式、官网、备案号和所在地区，统一从目标项目声明的组织 Knowledge 读取并逐字核对。
- 当前 Fenleng 主体资料和签章资产位于 `knowledge/organization/`；能读取资产不等于获得本次签名、盖章或上传授权。
- 应用公开官网与 Web 业务网址是不同概念：前者用于审核人员了解应用，后者是用户实际访问和发起 Web 登录的 HTTPS 站点。
- 应用名称、简介、网站网址、备案和平台能力只能记录目标项目的已观察事实，不得把 Fenleng Eat 或其他项目的示例直接当成新项目事实。

## 3. 网站信息登记表与后台字段

| 字段 | 填写规则 |
| --- | --- |
| 网站网址 | 填实际提供 Web 登录和业务访问的 HTTPS 地址，不填本地地址、Git 地址或内部地址。 |
| 网站名称 | 与网站应用名称保持一致，按当前页面的字节数和修改频率限制复核。 |
| 网站主办单位 | 填证照主体名称，不填品牌名或个人姓名。 |
| 主办单位官方网站 | 填主体官方网站；若表格单独要求应用官网，另填该应用公开官网。 |
| 网站内容简介 | 描述主体和网站的真实能力，不写与实际功能不符的宣传语。 |
| 负责人信息 | 从组织 Knowledge 和 Owner 输入核对，不从其他项目复制。 |
| 负责人签名/申请单位盖章 | 只在 Owner 明确授权本次文件后操作，签章成品不回填通用 Skill。 |

通用简介模板：

`杭州临安芬棱软件设计工作室(个体工商户)专注于软件开发、技术服务与信息系统集成。{应用名称}由其开发运营，提供{真实核心能力}。`

当前历史示例（仅作参考，必须重新核验）：芬棱 Eat 的 Web 业务网址为 `https://eat.fenlengtech.com/`，公开官网为 `https://eat-official.fenlengtech.com/`，示例回调地址为 `https://eat.fenlengtech.com/auth/wechat/callback`。该示例不构成其他项目的已登记事实。

## 4. 图片、登记表与签章

- 网站应用图片准备 28 × 28 像素 PNG；高清图片准备 108 × 108 像素 PNG。透明背景和不超过 300 KB 的限制必须按当前后台页面重新复核。
- 两个尺寸必须来自同一权威源图，主体居中、边缘不裁切，并在浅色和深色背景各查看一次；禁止使用签名、公章、营业执照或主体证件作为应用图片。
- 现行页面基线曾提示登记表扫描件最多 10 张、支持 JPG/PNG/BMP、单张不超过 5 MB；每次申请必须以当前页面为准。
- 登记表签字盖章时，签名覆盖负责人签名位置，公章覆盖申请单位/盖章位置；不要改变原表分页或挤压字段。
- 公章物理尺寸锁定为 `40 mm × 40 mm`，保持 `1:1`、不可拉伸、裁切或为适应单元格缩放。打印/导出使用 100% 实际大小，最终逐页检查并测量。
- 当前表格版式的坐标只能作为历史测量基线；微信更新表格后必须重新确认纸张、边距、签名栏和盖章栏，不能直接复用坐标。

## 5. Web OAuth 接入

审核和 AppID 获得后，按目标项目当前 Shared Platform 契约接入：

1. 确认微信开放平台登记的网站应用、Web 端使用的 AppID、应用归属和授权回调域一致。
2. 授权回调域字段只填域名本身，不填 `https://`、路径、端口或末尾斜杠；客户端只配置公开 AppID、回调 URI 和平台 API 基地址。
3. 登录跳转生成一次性 `state`；浏览器只保存用于校验的短期 state，不保存 AppSecret 或微信长期凭据。
4. 回调页只读取 `code` 和 `state`，先校验 state，再把一次性 code 交给服务端的当前 OAuth 入口。浏览器不得直接调用微信换取长期凭据。
5. AppSecret、微信 access token、refresh token 和服务端会话密钥只能由服务端受控 Secret 管理；不得进入前端构建产物、日志、Knowledge、Git 或错误提示。
6. 至少验证：用户取消、state 不匹配、code 重放、回调域不一致、微信错误、首次登录创建账号、已有账号续登和登录失败安全回退。真实环境未验证时不得标记为已接入。

工程实现必须先检查目标项目 Experience Manifest、依赖锁、Web 入口和现有身份架构，再选择目标项目已经声明或当前官方指南支持的 SDK；不得固定猜测第三方版本。必须通过带 commit/ref 的 Fenleng Project Knowledge 读取 `fenleng-shared-platform` Web OAuth 契约、Schema 和接入 Runbook；入口或错误模型不存在时停止，不在业务项目手写底层 HTTP 或猜字段。

## 6. 目标项目 Knowledge 沉淀

申请草稿、填报材料和审核过程继续保存在目标项目 `docs/wechat-open-platform/website-application/`，不得作为“已接入”事实。只有审核通过、Web OAuth 配置完成并通过真实环境验证后，才更新目标项目自己的 Project Knowledge：

1. 读取目标项目 `fenleng.project.yaml`，复用已声明 Knowledge root 中现有的第三方接入或应用身份目录；没有同类目录时，在声明根内创建 `integrations/wechat-website-application.md`，不得写到未暴露目录或 `fenlengtechbase`。
2. 记录项目 ID、网站应用名称、非敏感 AppID、审核状态、审核通过时间、已验证时间、授权回调域和已开通能力。
3. 记录 Web 业务网址、公开官网、平台页面证据、Shared Platform 契约 commit/ref、state/code 测试、账号绑定结果和最后复核时间。
4. 只记录已观察事实。未完成的能力明确标记状态和阻断原因，不把 `submitted`、候选域名或计划配置写成已接入。
5. 密码、AppSecret、验证码、Cookie、Token、二维码、完整授权 code、测试账号密码和生产用户数据不得进入 Knowledge。

## 7. 提交前验收清单

- [ ] 使用本次申请时从微信官方链接下载的最新版登记表。
- [ ] 应用名称、Web 网址、公开官网、主体名称、备案号和联系人已逐项核对。
- [ ] 表格中没有残留腾讯、qq.com、旧年份或其他应用示例值。
- [ ] 28 × 28 与 108 × 108 图片来自同一权威图标，尺寸、透明通道和文件大小符合当前页面限制。
- [ ] Owner 已确认本次使用签名和主体公章，并复核最终上传扫描件。
- [ ] 公章在最终 PDF/打印件中为 40 mm × 40 mm，原表分页未改变。
- [ ] 使用 100% 实际大小打印或导出，扫描件清晰、完整、可读。
- [ ] 微信后台上传的是已签字盖章扫描件，而不是未签章源文件。
- [ ] AppSecret、Token、密码和其他长期凭据未进入表格、图片、Knowledge 或日志。
- [ ] Web 回调域、AppID、Shared Platform 路由和生产域名已完成真实环境复核。
- [ ] state 校验、code 重放、用户取消、微信错误、首次登录、已有账号续登和安全回退已验证。

## 8. 证据与维护

- 官方入口：[微信开放平台](https://open.weixin.qq.com/)。
- 官方表格：[微信开放平台网站信息登记表](https://open.weixin.qq.com/zh_CN/htmledition/res/assets/manage/Website_Information_Form.doc)。
- 主体资料与签章资产：`knowledge/organization/README.md`、`knowledge/organization/assets/catalog.json`。
- 应用官网与协议：`knowledge/application-websites/README.md`、`knowledge/application-websites/application-website-integration-template.md`。
- 当前 reference 最后复核日期：`2026-08-25`。

微信官方表格、后台字段、图片规格、类目、审核政策或 OAuth 接入项变化时，先更新本 reference 的当前事实，再执行新的申请；不要把带会话 Token 的申请链接、二维码或一次性后台地址写入 Skill 或 Knowledge。
