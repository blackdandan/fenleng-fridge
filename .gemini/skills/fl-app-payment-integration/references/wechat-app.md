# 微信 APP 支付接入与验收

## 身份与能力

1. 从正式签名 Android 产物核对包名、证书 MD5 和移动应用 AppID，与微信开放平台登记一致。需要创建或调整移动应用时使用 `fl-wechat-mobile-application`，不重复维护申请材料。
2. 分别记录移动应用审核、微信支付能力、商户 APP 支付产品开通及 AppID/商户号绑定证据。开放平台“已获得”或 Owner 已绑定的说明不能替代真实下单验收；注明事实来源。
3. 数字订阅在国内 Android、已接入的国内 HarmonyOS 注册并允许 `wechat-pay`。iOS、海外 Android 和未接入的海外 HarmonyOS 不展示、调用或回退到微信支付。使用正式构建渠道，不按语言或定位决定渠道。
4. 核对服务端商户证书私钥、证书序列号、API v3 密钥，以及微信支付公钥 ID/平台证书对应的验签配置。只记录稳定凭据引用，不将密钥或 AppSecret 放客户端；登录 AppSecret 不等于支付凭据。按当日官方文档核实公钥和证书模式，不把任意序列号当作验签身份。

## 公共链路

- 使用公共 SDK 和 Shared Platform 的 `NATIVE_APP` 会话。服务端调用 `/v3/pay/transactions/app` 获取 `prepay_id`，按官方 APP 规则使用商户私钥签名；不得以 H5 URL 替代 APP SDK。
- 当前原生载荷字段为 `appId`、`partnerId`、`prepayId`、`packageValue`（`Sign=WXPay`）、`nonceStr`、`timeStamp`、`sign`。核对带 ref 的实际契约，不由业务 App 拼接签名。订单金额、用户和权益均由平台确认。
- 国内 Android 组合 `WechatPaymentAdapter(FenlengNativePaymentBridge())`；正式包名的 `wxapi.WXPayEntryActivity` 处理微信 Intent，向公共 `FenlengWechatPaymentCallbackDispatcher` 分发 `PayResp`。与登录 `WXEntryActivity` 分离，核对 Manifest、混淆和正式签名。公共 SDK 负责结果映射和并发状态，业务 App 不复制支付领域。
- 隐私同意后才初始化或调用钱包能力。原生调用前保存平台订单和支付尝试；回调成功、取消、错误、超时或进程重启后均通过平台恢复和确认，不将 SDK 成功当作权益到账。
- 多钱包页面使用已有 App 和 FL 组件展示可用渠道。新订单按所选渠道发起；恢复旧订单使用其原支付尝试，不因用户改变页面选择切换旧订单渠道。未配置或未开通的渠道明确不可用，不伪造可支付状态。
- APP 支付不自动包含代扣。单独核实商户的委托扣款资格、签约产品和通知契约，按实际支持接入；不支持时保留普通支付、手动续费及其他渠道协议，不删除公共代扣架构。

## 验收与留证

### 异步退款确认

- 退款接口受理不等于成功。`PROCESSING`、`ABNORMAL` 保留退款金额占用及权益，`SUCCESS` 才调整账本和期限，`CLOSED` 释放未完成退款占用。异常需商户处理，不能自动当作退款已终止。
- 退款请求必须设置应用级通知地址；通知验签解密并核对商户、原订单、退款号和金额。主动查询与通知在同一订单事务下确认，重复及乱序通知不重复调整、不覆盖已成功记录。
- 核对国内退款通知的真实金额对象：官方通知没有 `currency` 字段，不能把查询响应字段强加给通知；人民币契约按 CNY 归一化，并继续校验关联订单与退款金额。用官方不含币种的签名加密通知做测试。
- 验证 HTTP/治理幂等入口的完整重试：首次返回处理中，再用同一键和参数查询已成功退款；不能只测试 Adapter 查询。处理中快照不得阻断查询，重入仍校验原指纹、强认证及业务权限，不生成新退款。
- 网络结果不确定时保留原退款号，重试先查询。只有明确的 `RESOURCE_NOT_EXISTS` 才同号同参数重新申请；查询失败不能另建退款号。实际退款累计只统计成功，余额占用同时统计处理中和成功。
- 订单查询 `trade_state=REFUND` 不能证明具体退款金额或完成，不单独撤销全额权益。覆盖部分退款、全额退款、重复通知、事务回滚和并发确认；明确哪些仅本地验证、哪些已真实渠道验收。
- 依据执行日官方[退款最佳实践](https://pay.wechatpay.cn/doc/v3/merchant/4014959631)核实规则，不将当前应用商户凭据写入公共 Skill。

验证正式签名设备的微信唤起、成功与取消回调、未安装微信、重复点击、回调丢失、前后台及进程恢复。服务端验证签名和解密、商户/AppID/金额归属、重复及延迟通知、主动查询、关闭与支付竞态、退款与权益期限调整。首笔付款、重新登录权益、手动续费累计期限和退款分别留证。

本地桥接测试和原生编译只能证明对应实现；未验证正式设备真实订单前标记 `validated-with-follow-up`。渠道后台被工具访问策略阻断时，停止该后台操作，使用 Owner 提供的公开配置证据继续独立实现，不换浏览器或读取会话绕过限制。

官方规则需在执行日复核：[APP 调起支付](https://pay.wechatpay.cn/doc/v3/merchant/4013070351)。该文档说明 APP 参数与 RSA 签名，不能作为具体商户已开通的证据。

## 同商户多应用复用

Owner 选择同一已开通商户时，复用该商户现有商户私钥、证书序列号、API v3 密钥及当前验签公钥/证书的稳定 Secret 引用；不把移动应用 AppSecret 当作支付密钥。各应用独立保留 AppID、商户绑定、registration 与通知 URL；按具体商品 readiness 和真实交易验证新应用。不同商户不直接复用同一凭据集合。

返回应用而未收到原生回调时，公共原生 SDK 应结束交互等待并触发平台订单查询；返回前台只能视为 UNCONFIRMED。保留未确认订单以供恢复，避免等待整个钱包超时才刷新权益；覆盖迟到回调、取消和进程恢复，不能因此授予会员。

## HarmonyOS原生桥

公共原生插件封装腾讯官方OHPM `@tencent/wechat_open_sdk`，候选固定1.0.23；宿主querySchemes登记weixin，使用已登记BundleName/appIdentifier、exported且singleton的EntryAbility。请求只消费平台签名的七项APP参数，V3签名使用RSA，回调Ability为EntryAbility。通过AbilityPluginBinding注册NewWant与WindowFocus监听，官方handleWant处理回调；只消费PayResp，不接管登录/分享响应。PayReq关联transaction，返回时核对可用的transaction/prepayId，缺少关联仅视为UNCONFIRMED，不判为取消或付款成功。

未安装微信返回PAYMENT_APP_NOT_INSTALLED，保留服务端恢复上下文并显示既有安装提示；不将微信APP支付伪造为支付宝式H5自动回退。原生接口错误保留稳定nativeErrorCode，仍按平台订单确认；返回前台或超时只触发查询。插件注册不调用WXAPI，SDK只在用户实际付款时创建；不记录签名参数或回调正文。正式调起与到账仍需微信客户端、渠道审核及真实交易验收。
