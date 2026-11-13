# Fenleng Flutter Native Identity

Optional native identity-provider integrations for Fenleng Flutter applications.
Version `0.2.0` implements WeChat on Android and iOS; the current local candidate adds HarmonyOS. Overseas Google,
Facebook, Apple and other approved providers are deliberately not duplicated
here: use `fenleng_sdk_flutter_firebase_identity` and configure them in
Firebase Authentication.

Applications own provider credentials and platform association metadata. They
must call `configureWechat` before checking availability or authorizing. Android
applications also retain the package-name-specific `wxapi.WXEntryActivity` and
forward its `BaseResp` to `FenlengWechatCallbackDispatcher.dispatch`.

## HarmonyOS WeChat candidate

The ohos plugin uses official OHPM @tencent/wechat_open_sdk pinned to1.0.23. The host registers generated plugins after privacy consent, calls configureWechat with its existing public AppID, and declares querySchemes weixin and an exported singleton EntryAbility. Configuration stores public fields only and does not invoke WeChat. Availability checks return false when WeChat is absent; authorization reports WECHAT_NOT_INSTALLED.

SendAuthReq uses configured scope (snsapi_userinfo by default), a cryptoFramework random 24-byte state and EntryAbility callback. NewWant is passed to the official handleWant; only SendAuthResp is accepted and state must match before returning a non-empty one-time code. Prior requests and payment callbacks cannot authenticate the current user. The existing server exchanges the code; AppSecret, accessToken and refreshToken never enter this plugin. SDK callback diagnostics are not logged.

Cancellation, denial, missing code, state mismatch and120-second timeout have stable errors. Returning to the host without a callback reports WECHAT_AUTH_UNCONFIRMED after500ms, allowing retry; listeners and timers are removed on detach. Request state remains memory-only. This local candidate has build and contract evidence; real authorization and account association still require an installed WeChat client and channel acceptance.

## iOS Apple native credential (0.3.0)

After app privacy and login consent, call `MethodChannelFenlengNativeIdentity.authorizeApple()`. The typed credential contains `identityToken` and optional first-authorization `displayName`; its string representation redacts the token. `APPLE_AUTH_CANCELLED` is a normal cancellation. Never log the returned credential or store it in project evidence. Exchange through `FlutterAuthSDK.loginWithAppleIdentityToken` (core 0.6.0), using the registered application/client. The SDK stores the returned platform access/refresh session through its existing storage adapter. Global Firebase clients keep the existing Firebase flow.

iOS `isAvailable(wechat)` checks app installation without registering WeChat. Hosts must wait for privacy acceptance before probing; configure/authorize only after explicit login consent. URL schemes, associated domains and AASA remain host/deployment responsibilities.
