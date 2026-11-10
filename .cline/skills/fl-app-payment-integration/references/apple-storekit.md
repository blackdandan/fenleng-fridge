# Apple StoreKit 2 快速接入

## 读取与事实核对

从目标 Manifest 读取正式 Bundle ID、Team/Profile、发布渠道、商品与权益事实。读取固定 ref 的 Shared Platform `docs/runbooks/apple-storekit-integration.md`、支付接入 Runbook、实际 Apple Adapter/履约契约，以及 Client SDK `docs/apple-storekit-integration.md` 和 native-payment 包；记录来源与可获取提交。资料无法远程读取时，核实 Manifest 允许的本地知识根及 Git 提交，明确 local/git 来源，不伪造远程验证。

在 App Store Connect 分别核对应用、Paid Apps Agreement、税务/银行、目标地区销售条件、订阅组、商品 ID/周期/价格/语言/审核资料、In-App Purchase key 和 Notifications V2。复用组织账号、既有密钥恢复入口与上传通道；缺少时先准备具体配置供 Owner 审阅。税务、银行、签约等需 Owner 确认的事实不得代填。生成密钥或扩大访问遵守宿主当次确认要求，不因支付接入自动轮换身份。

首次内购随新 App 版本提交；正在审核的版本不擅自撤回。商品字段、价格档位和审核规则以当日 Apple 官方资料及后台为准，不把资料齐全或可编译当作上线。

## 商品与环境

- iOS/iPadOS 国内、海外均用 StoreKit 内购，不用 Apple Pay 或国内钱包回退；按明确构建渠道注入。
- 常规月自动订阅使用真实 Apple 自动续订商品。原钱包价格为 PREPAID 时，为商店建立匹配 SUBSCRIPTION 的独立 PriceOption/绑定，不改钱包计费与其他渠道代扣。
- 注册和绑定使用应用级 Secret 引用；Sandbox/TestFlight 与生产分别验证。Xcode 本地 StoreKit 凭证不得送入生产 API或伪造服务端成功。
- 读取 StoreKit 本地化价格、实际币种和周期；运行时测试账号0.01配置不改变 Apple 结算。将页面展示报价作为 `appleStoreQuote` 交给公共 SDK，服务端限定 Apple，并独立核对签名交易金额。无商品、报价变更或能力缺失时说明原因、允许重试，不用目录价格冒充商店价格。
- 首个基础能力支持普通月商品；免费试用、优惠、家庭共享、商店外购买/推广购买需各自真实价格与验证归属支持。未支持时不得宣称可用；特别核对 streamlined purchasing 等默认设置，不默许无账号归属的购买。任何调整准备成具体配置后按授权执行。
- 普通单账号订阅核对 Purchase Options，按商品实际能力配置单席位 App Store；Apple Business/School Manager、多席位默认选项不能当作已具备组织席位履约能力。可售地区从当前 App 实际配置继承，不把自动计算的全球价格误认为已授权销售范围。
- 关闭 Streamlined Purchasing 可能被 Apple 拒绝，因为最新已审核通过的 binary 缺少必需 API。保存失败仍记录实际 ON，补齐 StoreKit `PurchaseIntent`（iOS 16.4 起）及应用处理，待新 binary 审核通过后再保存并验证；不撤回当前审核来规避。购买意图仅打开商品确认流程，不代表付款成功，不直接扣款或 finish。优惠/推广功能仍须单独验收。

## Sandbox 账号准备

创建 Sandbox tester 时使用未注册普通 Apple Account 的邮箱；遇到邮箱已占用错误，应换符合条件的地址，不能把普通 Apple 登录成功当作测试账号创建成功。新密码按宿主交接规则由 Owner 输入，不收集或写入知识资产。分别记录测试账号是否创建、Paid Apps Agreement/税务/银行状态和商品可读取性；这些前置状态与真实交易验证不能用密钥认证成功替代。

Paid Apps Agreement 必须实际为 Active 才能进行真实 Sandbox 内购；Pending User Info、税表 Missing Tax Info 或银行 Processing 分别记录，不用商品创建成功代替。目录接口返回商品而 StoreKit 返回空列表时，先核对协议、Bundle ID、商品 ID、可售地区和设备商店状态，不用目录价绕过商店商品读取。

税表签署人、Apple Account 显示姓名与 Business 法律主体名称分别核对。发现不一致时不要沿用显示昵称提交；锁定的法律主体名称及无法修改的已提交税表按 Apple 官方支持流程申请更正或重置，保存案例编号及恢复步骤。姓名、出生日期、税号及税务居民/协定声明依据 Owner 明确事实填写；最终法律声明按宿主当次确认执行，不推断税务资格。

独立测试平台记录实际部署位置、数据隔离、代码 ref、支付环境和公网入口；Mac 本地服务加 SSH 转发依赖本机在线，不称为线上环境 1:1 还原。测试地址用构建参数注入，正式默认地址保持发布契约，验收后核对正式包地址与签名再上传。

## 通知链路预验收

在 Sandbox HTTPS URL 已保存、独立实例可达后，调用 Apple 官方 Request a Test Notification，再查询 Get Test Notification Status；核对 Apple 投递 SUCCESS、可信签名/应用/环境校验及平台处理记录。TEST 无购买交易，不应归类为付款失败或修改订单/权益；记录独立测试事件并验证订阅及权益不变。该步骤可在测试账号创建前完成，不能替代真实购买、续期和退款验收。缺少或无效的 signedPayload 外层请求按校验失败处理，不把它当渠道付款结果。

## App 只组合 SDK

真机检查已登录个人页面实际显示订阅入口，覆盖 iOS 与 Android 显示条件；支付 Adapter 已注册不证明入口可达。首次真实登录需使用平台标准内置成员角色及其精确权限集合，不能用临时测试权限替换保留角色定义；分别验证身份登录、会话和用户资料读取。

使用共享 `FenlengAppleStoreBridge`、`AppleStorePaymentAdapter` 和 `FlutterPaymentCoordinator`；StoreKit Swift、商品读取、购买、交易监听、恢复与完成在公共 SDK 内实现，App 不复制。核对 SDK 当前系统要求，低版本提供本地化不可用反馈。

1. 按 `fl-ui-design-system` 加载 FL 规范，再结合目标 App 的视觉组件；展示真实价格、周期、当前权益、自动续订及取消管理说明。
2. 国内按版本化购买协议明确确认并关联订单；海外无额外强制依据不增设勾选门禁，但保留 Apple 要求的使用条款/隐私链接与订阅告知。自动续订正文不得沿用“仅手动付款”的事实；旧订单恢复不伪造新确认。官网发布后核对当前页及不可变历史正文的 HTTP 状态和 SHA256，Apple 订阅页链接指向实际已发布的 Apple 自动续订条款，原用户协议入口仍用于其适用场景。平台协议登记前核实目标 Apple PriceOption 已存在；官网发布、协议登记、商品启用和客户端包更新分别记录实际状态，不能以发布条款推断已可付款。
3. readiness 通过后，按公共 SDK 的实际 `NATIVE_APP` presentation 创建未支付会话，核对 Apple `NATIVE_SDK`/`CLIENT_TOKEN` 能力、productId 与订单 appAccountToken；不能用通用 READY 代替入口验收。覆盖国内 CNY 和至少一种海外报价币种；报价订单的商品绑定匹配目录币种，原生会话保留报价金额与币种，到账仍独立核对 Apple 签名交易。此步骤不调用 StoreKit 购买，不产生真实交易。
4. 国内必要隐私同意及真实登录后，显式启动 `startAppleUpdates`；退出账号/销毁时 `stopAppleUpdates`。插件注册不得隐式读取商品、恢复或发起网络业务。启动读取 unfinished，交易按当前账号验证；换号后不继续处理旧账号记录。
   配置 `onPurchaseIntent` 将受支持商品导航到现有支付确认页，核对当前账号、商品、价格及必要协议后复用标准购买路径；未知商品忽略，不在监听回调直接创建收费订单。监听取消同时停止购买意图任务。
5. 购买前保存账号隔离的 order/attempt；使用平台发出的商品与 UUID appAccountToken，不自行拼造归属。服务端验证实际交易后才开放权益、调用 finish；网络/服务端失败保留 unfinished，可重启补单。
6. 用户取消关闭本地尝试，不取消商店订阅；Ask to Buy/pending 保留等待提示。未知结果重试复用原订单，不能再建收费订单；手动查询先调用公共 `syncAppleUnfinishedForOrder` 补交对应订单的未完成交易，再读取服务端状态；不会重新打开购买页。单次查询结束 loading，不轮询无限等待。
7. 显式“恢复购买”调用商店 sync 并验证原交易，不创建新收费订单；已订阅提供“管理 Apple 订阅”，不用手动再买一个月。读取 provider-specific Apple 状态与实际有效权益，取消自动续费后仍保留已付周期。

## 服务端与完成标准

核查可信 Apple 签名/证书用途、bundle/product/environment、appAccountToken 与认证账号、真实 transactionId/originalTransactionId、撤销、价格及有效期。旧凭证不能绑定另一个账号或新订单。续期及恢复使用稳定交易来源，不因通知重复、乱序或恢复重复授予权益。

Apple 签名 purchaseDate/expiresDate 决定固定周期，包含 Sandbox 加速周期；不能从累计到期日额外加自然月。退款/撤销只回收对应交易来源，过期只结束对应 Apple 权益；原钱包期限及其他渠道自动续费身份保留。公共层缺口回补 Platform/SDK，不在 App 补第二套账本。

完成证据覆盖：首购、取消、pending、网络失败/杀进程、同订单重试、重装/跨设备恢复、换号及凭证重放、重复/迟到通知、自动续期、关闭续费、过期、退款/撤销和已有其他渠道权益。主题、缩放、长文本/RTL、手机与产品已批准平板范围按设计体系验收。区分编译/单测、本地 StoreKit、真实 Sandbox、生产与商店审核；缺真实配置或交易时列出 follow-up，不宣称正式可购买。

## 官方依据

每次执行重新核实；2026-10-12 已核对：
- https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/
- https://developer.apple.com/documentation/appstoreserverapi
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions
- https://github.com/apple/app-store-server-library-java
