import Flutter
import UIKit
import WechatOpenSDK

public final class FenlengNativeIdentityPlugin: NSObject, FlutterPlugin, WXApiDelegate, FlutterSceneLifeCycleDelegate {
  public static let shared = FenlengNativeIdentityPlugin()

  private var appId: String?
  private var scope = "snsapi_userinfo"
  private var expectedState: String?
  private var pendingResult: FlutterResult?
  private var timeout: DispatchWorkItem?
  private var retiredStates: [String] = []

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.fenleng.sdk/native_identity",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(shared, channel: channel)
    registrar.addSceneDelegate(shared)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "configureWechat": configureWechat(arguments, result: result)
    case "isAvailable":
      guard provider(arguments) == "wechat" else { result(false); return }
      guard appId != nil else { fail(result, "IDENTITY_NOT_CONFIGURED", "微信身份渠道尚未配置"); return }
      result(WXApi.isWXAppInstalled())
    case "authorize":
      guard provider(arguments) == "wechat" else {
        fail(result, "IDENTITY_PROVIDER_UNSUPPORTED", "当前身份渠道尚未接入", provider(arguments))
        return
      }
      authorizeWechat(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func configureWechat(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard pendingResult == nil else { fail(result, "IDENTITY_AUTH_IN_PROGRESS", "Identity authorization is in progress"); return }
    guard let appId = arguments?["appId"] as? String, !appId.isEmpty else {
      fail(result, "IDENTITY_CONFIG_INVALID", "微信 AppID 不能为空")
      return
    }
    guard let universalLink = arguments?["universalLink"] as? String,
          universalLink.hasPrefix("https://"), universalLink.hasSuffix("/") else {
      fail(result, "IDENTITY_CONFIG_INVALID", "iOS 微信 Universal Link 必须以 https:// 开头并以 / 结尾")
      return
    }
    self.appId = appId
    if let scope = arguments?["scope"] as? String, !scope.isEmpty { self.scope = scope }
    guard WXApi.registerApp(appId, universalLink: universalLink) else {
      self.appId = nil
      fail(result, "WECHAT_REGISTER_FAILED", "微信 SDK 注册失败")
      return
    }
    result(nil)
  }

  private func authorizeWechat(_ result: @escaping FlutterResult) {
    guard appId != nil else { fail(result, "IDENTITY_NOT_CONFIGURED", "微信身份渠道尚未配置"); return }
    guard WXApi.isWXAppInstalled() else { fail(result, "WECHAT_NOT_INSTALLED", "请先安装微信"); return }
    guard pendingResult == nil else { fail(result, "IDENTITY_AUTH_IN_PROGRESS", "身份授权正在进行"); return }
    let state = "fenleng_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    let request = SendAuthReq()
    request.scope = scope
    request.state = state
    expectedState = state
    pendingResult = result
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.expectedState == state else { return }
      self.finishError("WECHAT_AUTH_TIMEOUT", "WeChat authorization timed out")
    }
    self.timeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: timeout)
    WXApi.send(request) { [weak self] success in
      guard !success else { return }
      DispatchQueue.main.async {
        guard self?.expectedState == state else { return }
        self?.finishError("WECHAT_SEND_FAILED", "无法打开微信授权")
      }
    }
  }

  public func onResp(_ response: BaseResp) {
    guard let auth = response as? SendAuthResp else { return }
    guard pendingResult != nil else { return }
    if let state = auth.state, retiredStates.contains(state) { return }
    guard expectedState != nil, auth.state == expectedState else {
      finishError("WECHAT_STATE_MISMATCH", "微信授权校验失败")
      return
    }
    switch response.errCode {
    case WXSuccess.rawValue:
      guard let code = auth.code, !code.isEmpty else { finishError("WECHAT_CODE_MISSING", "微信未返回授权码"); return }
      finishSuccess(code)
    case WXErrCodeUserCancel.rawValue: finishError("WECHAT_AUTH_CANCELLED", "已取消微信授权", response.errCode)
    case WXErrCodeAuthDeny.rawValue: finishError("WECHAT_AUTH_DENIED", "微信授权被拒绝", response.errCode)
    case WXErrCodeUnsupport.rawValue: finishError("WECHAT_UNSUPPORTED", "当前微信版本不支持授权", response.errCode)
    default: finishError("WECHAT_AUTH_FAILED", "微信授权未完成", response.errCode)
    }
  }

  public static func handle(url: URL) -> Bool {
    // Leave callbacks owned by legacy providers available to their delegates.
    guard shared.pendingResult != nil else { return false }
    return WXApi.handleOpen(url, delegate: shared)
  }

  public static func handle(userActivity: NSUserActivity) -> Bool {
    guard shared.pendingResult != nil else { return false }
    return WXApi.handleOpenUniversalLink(userActivity, delegate: shared)
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    URLContexts.contains { Self.handle(url: $0.url) }
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    Self.handle(userActivity: userActivity)
  }

  private func finishSuccess(_ code: String) {
    let result = pendingResult
    clearPending()
    result?(code)
  }

  private func finishError(_ code: String, _ message: String, _ details: Any? = nil) {
    let result = pendingResult
    clearPending()
    fail(result, code, message, details)
  }

  private func clearPending() {
    timeout?.cancel()
    timeout = nil
    if let state = expectedState {
      retiredStates.append(state)
      if retiredStates.count > 8 { retiredStates.removeFirst() }
    }
    pendingResult = nil
    expectedState = nil
  }

  private func fail(_ result: FlutterResult?, _ code: String, _ message: String, _ details: Any? = nil) {
    result?(FlutterError(code: code, message: message, details: details))
  }

  private func provider(_ arguments: [String: Any]?) -> String? {
    arguments?["provider"] as? String
  }
}
