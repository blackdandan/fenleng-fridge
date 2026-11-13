# `fenleng_sdk_flutter`

Official Fenleng Client SDK for Flutter (Auth, Commerce, Telemetry, Storage, and AI Stream).

## 微信登录配置

```dart
import 'package:fenleng_sdk_flutter/fenleng_sdk_flutter.dart';

final authSDK = FlutterAuthSDK(
  client: client,
  applicationCode: 'your-app',
  clientTarget: 'mobile',
);

await authSDK.loginWithWechatCode(shortLivedWechatCode);
```

未显式提供 `clientId` 时，SDK 使用 `<applicationCode>-<clientTarget>`。
微信 AppID 属于客户端公开配置；AppSecret 只保存在 Shared Platform。

## 账号注销消费者

`currentUser()`只读当前会话的`id/kind/status`，不登录或刷新。宿主确认后通过`createFederatedDeletionChallenge`取得挑战，重新请求原生Provider凭据，用`confirmFederatedDeletionReauthentication`验证，再以原幂等键和`actionConfirmationId`调用`requestData('DELETE',...)`。只有真实PENDING及服务端七天日期可显示受理。

回执先持久化，再调用`logout(localOnly:true)`清理原会话；该选项不发送logout HTTP。宿主应对本机清理加身份代际保护，不能清掉后来建立的新会话。未知结果保留原意图，不能自动登录；显式新登录后再次申请使用新键。既有`logout()`默认行为不变。上述代码目前仍是本地未发布候选。
