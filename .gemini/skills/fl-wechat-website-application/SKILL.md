---
name: fl-wechat-website-application
description: "为 Fenleng FL 项目申请、审核并接入微信开放平台网站应用，准备网站登记材料、签章文件、网站 OAuth 配置和项目 Knowledge。触发场景包含：申请微信网站应用 AppID、创建微信开放平台网站应用、准备 Web 微信登录材料或完成审核后接入；移动应用和小程序不使用本 Skill。"
---

# fl-wechat-website-application

为 Fenleng FL 项目完成微信开放平台“网站应用”的材料准备、Owner 审核、平台提交、Web OAuth 接入和项目事实沉淀。

## 输入

- 唯一 FL 项目 ID、项目根目录、真实 Web 应用根目录和正式部署域名。
- 应用官网、Web 业务网址、协议页面、主体资料、品牌图标和当前网站实现证据。
- Owner 对本次登录、签字、盖章、上传、提交或修改线上应用的明确授权；不接收密码、AppSecret、验证码、Cookie、Token 或二维码。

## 输出

- 目标项目 `docs/wechat-open-platform/website-application/` 下的网站应用申请材料草稿和 Owner 操作清单。
- 审核通过、Web OAuth 配置和真实环境验证后的目标项目 Knowledge 更新建议；基座不集中保存具体网站应用的接入结果。
- 带证据引用的验收结论，或明确的 `draft` / `changes-required` 阻断原因。

## 执行步骤

1. 定位目标项目的 `fenleng.project.yaml`、真实 Web 应用根目录、部署配置和已声明 Project Knowledge 根；目标不唯一时停止，不把一个项目的事实用于另一个项目。
2. 完整读取 [`references/website-application-registration.md`](references/website-application-registration.md)，按其中的当前页面基线、平台字段、主体资料边界、材料规则、安全边界和验收清单执行。移动应用或小程序改用对应 Skill，不复用本 Skill 的申请材料。
3. 从 [`assets/website-application-information.md.template`](assets/website-application-information.md.template) 复制申请材料草稿到目标项目 `docs/wechat-open-platform/website-application/`，仅用源码、部署配置、公开官网、Owner 输入或平台页面证据填写；事实缺失时保持 `draft`。
4. 从同一权威应用图标确定性生成 28 × 28 和 108 × 108 PNG；准备最新版官方《微信开放平台网站信息登记表》，完成签字盖章、扫描和页面要求复核。
5. 提交前执行完整清单。未获得本次外部操作授权时，只交付本地材料和 Owner 操作清单；签字、盖章、上传和提交不得由准备材料的授权自动推导。
6. 审核通过后，只记录开放平台真实返回的非敏感 AppID、授权回调域和已验证能力。AppSecret 的存储、构建绑定和运行时投放交给 `fl-matrix-operator`，浏览器和前端构建产物不得读取。
7. 实施 Web 接入时检查目标项目 Experience Manifest、依赖和身份架构，从带 commit/ref 的 Fenleng Project Knowledge 读取 Shared Platform 当前 Web OAuth 契约；契约、客户端 SDK 能力或服务端 code 交换入口缺失时停止，不手写猜测接口。
8. 完成 state 校验、服务端 code 交换、账号绑定、错误回退和真实环境验证后，按 reference 的“目标项目 Knowledge 沉淀”规则更新目标项目自己的 Knowledge；基座不集中保存具体网站应用的接入结果。

## 资源

- `assets/website-application-information.md.template`：生成目标项目的 `网站应用申请信息.md`。
- `references/website-application-registration.md`：申请登记、签章、图片、Web OAuth、目标项目 Knowledge 和验收规则。

只复制到目标项目并填写真实适用内容；一次申请的签字盖章成品、后台截图和临时页面地址不得回填 Skill。

## 完成标准

- 申请材料、网站地址、图标和登记表均来自目标项目可追溯证据，且通过 reference 的提交前验收。
- 外部状态只按真实页面证据推进，Owner 授权、签章和管理员边界没有被绕过。
- 审核与真实环境接入完成后，目标项目 Knowledge 记录 AppID、回调域、能力、状态、证据和复核时间。
- 密码、AppSecret、验证码、Cookie、Token、二维码和生产用户数据未进入 Git、Knowledge、客户端、构建产物、日志或截图。

## 失败处理

- 平台规则或页面字段与 reference 基线不一致时，以当日官方页面和最新版官方表格为准；先更新 reference 的当前事实，再继续。
- 应用官网、Web 业务网址、备案、主体资料、Owner 授权、图标或 Shared Platform 契约无法确认时，保持 `draft` 并列出唯一必要的人工动作。
- 回调域不一致、state 校验失败、code 重放、服务端拒绝或真实环境验证失败时停止对应接入，不生成替代事实或报告完成。
