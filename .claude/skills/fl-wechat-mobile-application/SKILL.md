---
name: fl-wechat-mobile-application
description: "为 Fenleng FL 项目申请、审核并接入微信开放平台移动应用，准备 Android/iOS 申请材料、AppID 配置和项目 Knowledge。触发场景包含：申请微信移动应用 AppID、创建微信开放平台移动应用、准备微信 App 登录材料或完成审核后接入；网站应用和小程序不使用本 Skill。"
---

# fl-wechat-mobile-application

为 Fenleng FL 项目完成微信开放平台“移动应用”的材料准备、Owner 审核、平台提交、AppID 接入和项目事实沉淀。

## 输入

- 唯一 FL 项目 ID、项目根目录和真实 App 根目录。
- Android、iPhone、iPad 或鸿蒙的真实开发范围与上架状态。
- 项目源码、正式构建配置、应用官网、应用市场资料、权威图标和可运行的界面测试。
- Owner 对本次登录、扫码、上传、提交或修改线上应用的明确授权；不接收 AppSecret、密码、验证码、Cookie、Token 或二维码。

## 输出

- 目标项目 `docs/wechat-open-platform/mobile-application/` 下的申请材料草稿和 Owner 操作清单。
- 审核通过、SDK 配置和真实设备验证后的目标项目 Knowledge 更新建议；基座不集中保存具体 App 的接入结果。
- 带证据引用的验收结论，或明确的 `draft` / `changes-required` 阻断原因。

## 执行步骤

1. 定位目标项目的 `fenleng.project.yaml`、真实 App 根目录、正式发布配置和已声明 Project Knowledge 根；目标不唯一时停止，不把一个项目的事实用于另一个项目。
2. 完整读取 [`references/mobile-application-registration.md`](references/mobile-application-registration.md)，按其中保留的 FL 账号、页面基线、平台字段、安全边界、材料规则和验收清单执行。网站应用或小程序改用其对应流程，不复用本 Skill 的申请材料。
3. 从 `assets/` 复制相应模板到目标项目 `docs/wechat-open-platform/mobile-application/`，仅用源码、构建配置、应用市场、官网、Owner 输入或平台页面证据填写；必填事实缺失时保持 `draft`。当生成或复核 Android 或 iOS 签名信息时，同时在目标项目 `05-knowledge/signinfo/application-signing-info.json` 保存备案所需的公开应用信息（含中文名称）、证书指纹/公钥和签名定位；该文件必须进入 Git，不能包含密码或私钥。
4. 从同一权威应用市场图标确定性生成 28 × 28 和 108 × 108 PNG；用目标 App 的 golden/screenshot test 生成连续运行流程图，并按 reference 复验尺寸、大小、哈希、隐私和真实业务路径。
5. 在提交前执行完整清单。未获得本次外部操作授权时，只交付本地材料和 Owner 操作清单；管理员扫码、资料上传和提交审核不得由准备材料的授权自动推导。
6. 审核通过后，只记录开放平台真实返回的非敏感 AppID 和平台配置。AppSecret 的存储、构建绑定和运行时投放交给 `fl-matrix-operator`，移动客户端不得读取 AppSecret。
7. 实施工程接入时检查目标项目 Experience Manifest、现有依赖和原生配置，不替换技术栈或猜 SDK；Flutter 项目同时读取 [`fl-ai-coding-delivery` 的 Flutter 架构规则](../fl-ai-coding-delivery/references/domain-flutter-architecture.md)。从带 commit/ref 的 Fenleng Project Knowledge 读取 Shared Platform 当前身份契约；契约、客户端 SDK 能力或服务端 code 交换入口缺失时停止，不手写猜测接口。
8. 完成 Android/iOS 原生回调、客户端授权、服务端 code 交换、错误回退和真实设备验证后，按 reference 的“目标项目 Knowledge 沉淀”规则更新目标项目自己的 Knowledge；基座不集中保存具体 App 的接入结果。

## 资源

- `assets/wechat-mobile-application-basic-information.md.template`：生成 `基本信息.md`。
- `assets/wechat-mobile-application-android-information.md.template`：Android 项目生成 `Android信息.md`。
- `assets/wechat-mobile-application-ios-information.md.template`：iPhone 或 iPad 项目生成 `iOS信息.md`。
- `assets/application-signing-info.json.template`：生成或补齐 `05-knowledge/signinfo/application-signing-info.json`，保存备案和签名登记所需的公开元数据。

只复制真实适用的平台模板；未开发的平台在 `基本信息.md` 中明确标记“不适用”。

## 完成标准

- 申请材料、平台标识、图标和流程图均来自目标项目可追溯证据，且通过 reference 的提交前验收。
- 外部状态只按真实页面证据推进，账号、授权和管理员边界没有被绕过。
- 审核与真实设备接入完成后，目标项目 Knowledge 记录 AppID、包标识、签名或关联域、能力、状态、证据和复核时间。
- 生成或复核签名信息时，目标项目 `05-knowledge/signinfo/application-signing-info.json` 已保存并纳入 Git；其内容只包含公开登记信息、证书指纹、公钥和签名路径，不包含密码、私钥、AppSecret 或 Token。
- AppSecret、密码、验证码、Cookie、Token、二维码和生产用户数据未进入 Git、Knowledge、客户端、构建产物、日志或截图。

## 失败处理

- 平台规则或页面字段与 `2026-08-31` 基线不一致时，以当日页面为准，更新本 Skill reference 后再继续，不臆造新规则。
- 正式包名、Bundle ID、签名证书、Universal Links、权威图标、上架状态或 Owner 授权无法确认时，保持 `draft` 并列出唯一必要的人工动作。
- 已有发布证书缺失、包标识已绑定其他移动应用、平台审核驳回或真实设备验证失败时停止对应接入，不生成替代事实或报告完成。
