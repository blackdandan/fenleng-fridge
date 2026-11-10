# 数字订阅渠道矩阵

本矩阵是 Owner 确定的产品规则，适用于数字内容及 App 权益订阅。区域政策例外不自动改变本矩阵；实物交易另按业务契约处理。

| 编译期 APP_RELEASE_CHANNEL | iOS / iPadOS | Android | HarmonyOS |
|---|---|---|
| china | Apple In-App Purchase / StoreKit | 微信支付、支付宝 APP 支付 | 支付宝、微信 APP 支付（分别完成原生接入及渠道验收） |
| global | Apple In-App Purchase / StoreKit | Google Play Billing | 暂无已接入渠道 |

Apple 支付指 StoreKit 内购，不是 Apple Pay 钱包；海外 Android 的数字订阅使用 Google Play Billing，不是 Google Pay 钱包。

## 实施

- 发布渠道取明确编译期配置，值只允许 china/global；不得按语言、IP、SIM 或用户偏好推断。
- 组合根只注册该平台／渠道允许且真实可用的 Adapter；购买方法也校验矩阵，不能仅隐藏按钮。
- 禁止在 iOS 上回退到支付宝／微信数字订阅；global Android 不能回退到国内钱包。
- Adapter 类、后台 READY 或商户产品已开通，不等于客户端购买能力、商品和 registration/binding 已完成。缺失时保留明确不可用及订单恢复入口，不伪造接入。
- StoreKit / Play Billing 的价格、凭证和测试环境遵循商店机制；运行时测试账号低价配置不得绕过商店计费。
- 首笔收款与续费签约分别确认。支付宝签约失败不移除订阅能力、不清空其他支付渠道代扣协议。

## 取消和恢复

原生用户取消只表示退出收银台，不表示服务端订单已关闭。应用展示尚未完成支付，保存账号隔离的 order/attempt，并有界查询。签名确认交易不存在可以结束本地未支付订单；未知结果保留记录。订单关闭与到账必须事务化串行处理；迟到的已验签、金额及归属校验通过的付款仍履约，重复通知不得重复授予权益。旧订单金额不随测试价格配置追溯变化。

待支付页面提供继续支付、查询结果、关闭订单三个独立动作。手动查询使用 SDK 单次核对入口 `queryOnce`，未支付即结束 loading；不要复用十轮自动补单或等待后台轮询。总等待有上限，超时保留订单并恢复按钮。

支付宝继续支付使用 `resume(orderId, attemptId, idempotencyKey)`：先核对终态，再通过平台 `startPayment` 的 `resumeAttemptId` 获取同订单／同尝试的新签名参数。原订单金额冻结，不重复创建订单；调起前再次检查当前登录账号。平台 ref 必须确实支持该字段，终态或其他账号不得恢复支付；支付宝采用 NATIVE_APP；Apple 同订单重试以固定平台/SDK ref 的 StoreKit 恢复及 resumeApple 契约为准，不复制钱包签名流程。

用运行时实际组合的 Adapter 验证关单，而不只直接测试支付宝实现：监控与开关包装层须转发 `closePayment`、保留渠道能力和错误。覆盖未支付查询结束 loading、续付取消后仍可恢复、已付款不再调起、原金额保持、关闭与到账竞态，并区分测试通过、候选构建、线上部署和 Owner 真实资金验收。

查询和关闭失败保留稳定 code、requestId 和动作上下文，不记录 token、签名订单串或完整渠道交易号。展示明确重试与保留订单反馈。

## 官方资料

- [Apple 数字内购规则](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
- [Google Play Billing](https://developer.android.com/google/play/billing)

## 权益恢复与手动续费

- 配置业务 App OAuth 客户端 `application:entitlement:read`，核对应用成员授权；旧会话刷新后验证权益接口 200。SDK 对权益读取的 403 PERMISSION_DENIED 只刷新并重试一次，持续拒绝正常报错。
- 每次进入页面调用服务端订阅及权益读取（Flutter coordinator `currentAccess`）；将无订阅 200 null 作为正常状态。不得用本地待支付记录或渠道客户端回调推断权益。
- 按期预付的钱包已有有效订阅展示权益及到期日，默认提供“手动续费”；点击后才出现支付按钮。续费成功应在当前有效期后累加一个月，过期从本次付款时间起算。退出重进必须仍能恢复权益。
- 支付按钮按实际渠道显示品牌图标与文字；支付宝按钮在“确认并支付”前展示支付宝图标。验收包含旧会话、已有订阅重进、手动续费、有效期累加和渠道图标。

Apple 自动续订展示经验证的商店周期和续订状态，提供管理 Apple 订阅与恢复购买，不默认手动再买一个月。Apple 过期时其他渠道有效权益仍须展示；商店固定周期及退款以 [Apple 接入规则](apple-storekit.md) 为准。

## 退款后的期限一致性

- 核对平台是否按订单或受验证渠道事件记录独立购买期限；累计 grant.validUntil 不等价于该订单独占周期。不得机械减 30 天或仅隐藏 UI。
- 全额退款只撤回目标购买来源，并同步订阅到期日、对应有效权益和下一次续费基准。其他未退款订单及其他渠道协议保留；带渠道订阅标识的订单退款仍按订单范围处理。
- 查询成功不等于存在权益：页面核对目标有效 entitlement items 后才显示已生效。首次购买全退、退最新续费、退历史购买、重复通知、再购买增加一个周期、其他渠道协议保留均须覆盖。
- 历史来源无法确认时保留可审计基线，先核对来源，不猜测期限；在调用真实渠道退款前确认能正确回收目标期限。新账本迁移与旧版本回滚的语义兼容限制必须记录。
