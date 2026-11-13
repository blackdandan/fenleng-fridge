import Flutter
import UIKit
import AuthenticationServices
import WebKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var legalInProgress = false
  private var bridge: FlutterImplicitEngineBridge?
  private var bootstrapChannel: FlutterMethodChannel?
  private var pluginsRegistered = false
  private var globalPluginsRegistered = false
  private var activeReleaseChannel: String?
  private var businessAllowed = false
  private var appleController: ASAuthorizationController?
  private var appleResult: FlutterResult?
  private var appleTimeout: DispatchWorkItem?
  private var appleWindow: UIWindow?
  private let consent = UserDefaults.standard
  private let reminders = ReminderBridge()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Minimal callback routing only; no business store or permission query here.
    UNUserNotificationCenter.current().delegate = self
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    bridge = engineBridge
    // Only this minimal application channel exists before explicit consent.
    bootstrapChannel = FlutterMethodChannel(name: "fenleng.fridge/bootstrap",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    bootstrapChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "BOOTSTRAP_UNAVAILABLE", message: nil, details: nil)); return }
      self.handleBootstrap(call, result)
    }
  }

  private func handleBootstrap(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: String] ?? [:]
    switch call.method {
    case "legal.open":
      guard !legalInProgress else { result(FlutterError(code: "LEGAL_READER_BUSY", message: nil, details: nil)); return }
      guard let html = args["html"], !html.isEmpty,
        let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController
        else { result(FlutterError(code: "LEGAL_UNAVAILABLE", message: nil, details: nil)); return }
      var presenter = root
      while let presented = presenter.presentedViewController { presenter = presented }
      legalInProgress = true
      let document = LegalReaderController(html: html, title: args["title"] ?? "", backLabel: args["backLabel"] ?? "",
        allowWithdrawal: args["withdrawalEnabled"] == "true") { [weak self] action in
          self?.legalInProgress = false
          if action == "withdraw" { result("withdraw") } else { result(true) }
        }
      document.overrideUserInterfaceStyle = args["appearance"] == "dark" ? .dark : args["appearance"] == "light" ? .light : .unspecified
      let readerNavigation = UINavigationController(rootViewController: document)
      readerNavigation.overrideUserInterfaceStyle = document.overrideUserInterfaceStyle
      readerNavigation.modalPresentationStyle = .fullScreen
      presenter.present(readerNavigation, animated: true)
    case "identity.apple":
      guard businessAllowed, activeReleaseChannel == "china" else { result(FlutterError(code: "CONSENT_REQUIRED", message: nil, details: nil)); return }
      startApple(result)
    case "privacy.read":
      var record = consent.dictionary(forKey: "privacyConsent") ?? [:]
      record["locale"] = (consent.string(forKey: "displayLocale") as Any?) ?? NSNull()
      record["appearance"] = consent.string(forKey: "displayAppearance") ?? "system"
      record["withdrawalPending"] = consent.bool(forKey: "withdrawalPending")
      result(record)
    case "privacy.accept":
      guard let version = args["policyVersion"], !version.isEmpty,
        ["china", "global"].contains(args["releaseChannel"] ?? ""), let acceptedAt = args["acceptedAt"],
        !acceptedAt.isEmpty else { result(FlutterError(code: "CONSENT_INVALID", message: nil, details: nil)); return }
      let previous = consent.object(forKey: "privacyConsent")
      consent.set(args, forKey: "privacyConsent")
      if consent.synchronize() { result(true) }
      else { consent.set(previous, forKey: "privacyConsent"); result(FlutterError(code: "CONSENT_WRITE_FAILED", message: nil, details: nil)) }
    case "plugins.initialize":
      let record = consent.dictionary(forKey: "privacyConsent") ?? [:]
      let accepted = record["policyVersion"] as? String == args["policyVersion"] &&
        record["releaseChannel"] as? String == "china" && record["acceptedAt"] is String
      guard args["releaseChannel"] == "global" || (args["releaseChannel"] == "china" && accepted),
        let bridge = bridge else { result(FlutterError(code: "CONSENT_REQUIRED", message: nil, details: nil)); return }
      if !pluginsRegistered {
        FridgeDeferredPluginRegistrant.registerLocal(with: bridge.pluginRegistry, china: args["releaseChannel"] == "china")
        pluginsRegistered = true
      }
      businessAllowed = true
      activeReleaseChannel = args["releaseChannel"]
      reminders.authorize(messenger: bridge.applicationRegistrar.messenger())
      result(true)
    case "plugins.initializeOnline":
      let record = consent.dictionary(forKey: "privacyConsent") ?? [:]
      guard businessAllowed, activeReleaseChannel == "global", args["releaseChannel"] == "global",
        args["policyVersion"] == "V0.4", record["policyVersion"] as? String == "V0.4",
        record["releaseChannel"] as? String == "global", record["acceptedAt"] is String,
        !consent.bool(forKey: "withdrawalPending"), let bridge = bridge
        else { result(FlutterError(code: "CONSENT_REQUIRED", message: nil, details: nil)); return }
      if !globalPluginsRegistered {
        guard FridgeDeferredPluginRegistrant.registerGlobal(with: bridge.pluginRegistry)
          else { result(FlutterError(code: "BOOTSTRAP_UNAVAILABLE", message: nil, details: nil)); return }
        globalPluginsRegistered = true
      }
      result(true)
    case "data.directory":
      guard businessAllowed else { result(FlutterError(code: "CONSENT_REQUIRED", message: nil, details: nil)); return }
      guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { result(FlutterError(code: "DATA_DIRECTORY_UNAVAILABLE", message: nil, details: nil)); return }
      result(directory.appendingPathComponent("fridge", isDirectory: true).path)
    case "display.locale":
      let previousLocale = consent.object(forKey: "displayLocale")
      consent.set(args["locale"], forKey: "displayLocale")
      if consent.synchronize() { result(true) }
      else { consent.set(previousLocale, forKey: "displayLocale"); result(FlutterError(code: "DISPLAY_WRITE_FAILED", message: nil, details: nil)) }
    case "display.theme":
      guard let appearance = args["appearance"], ["system", "light", "dark"].contains(appearance)
        else { result(FlutterError(code: "DISPLAY_INVALID", message: nil, details: nil)); return }
      let previousAppearance = consent.object(forKey: "displayAppearance")
      consent.set(appearance, forKey: "displayAppearance")
      if consent.synchronize() { result(true) }
      else { consent.set(previousAppearance, forKey: "displayAppearance"); result(FlutterError(code: "DISPLAY_WRITE_FAILED", message: nil, details: nil)) }
    case "filing.open":
      guard let url = URL(string: "https://beian.miit.gov.cn") else { result(false); return }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    case "privacy.revoke":
      consent.removeObject(forKey: "privacyConsent")
      consent.set(true, forKey: "withdrawalPending")
      if consent.synchronize() {
        businessAllowed = false
        reminders.revoke { error in
          if error == nil { result(true) }
          else { result(FlutterError(code: "NOTIFICATION_REVOKE_FAILED", message: nil, details: nil)) }
        }
      }
      else { result(FlutterError(code: "CONSENT_WRITE_FAILED", message: nil, details: nil)) }
    case "privacy.directory":
      guard consent.bool(forKey: "withdrawalPending"),
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { result(FlutterError(code: "CONSENT_REQUIRED", message: nil, details: nil)); return }
      result(directory.appendingPathComponent("fridge", isDirectory: true).path)
    case "privacy.finishRevoke":
      consent.removeObject(forKey: "withdrawalPending")
      if consent.synchronize() { result(true) }
      else { result(FlutterError(code: "CONSENT_WRITE_FAILED", message: nil, details: nil)) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void) {
    guard let day = ReminderBridge.day(response.notification) else {
      super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler); return
    }
    DispatchQueue.main.async {
      if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
        self.reminders.receive(day: day, id: response.notification.request.identifier)
      }
      completionHandler()
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    guard ReminderBridge.day(notification) != nil else {
      super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler); return
    }
    DispatchQueue.main.async { self.reminders.foreground(notification, completion: completionHandler) }
  }

  private func startApple(_ result: @escaping FlutterResult) {
    guard appleResult == nil else { result(FlutterError(code: "IDENTITY_AUTH_IN_PROGRESS", message: nil, details: nil)); return }
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    guard let window = window else { result(FlutterError(code: "IDENTITY_ACTIVITY_UNAVAILABLE", message: nil, details: nil)); return }
    let request = ASAuthorizationAppleIDProvider().createRequest()
    // No name/email is needed for a local inventory. The server validates this proof.
    request.requestedScopes = []
    let controller = ASAuthorizationController(authorizationRequests: [request])
    appleController = controller
    appleWindow = window
    appleResult = result
    controller.delegate = self
    controller.presentationContextProvider = self
    let timeout = DispatchWorkItem { [weak self, weak controller] in
      guard let self = self, let controller = controller, self.appleController === controller else { return }
      self.finishApple(nil, "APPLE_AUTH_TIMEOUT")
    }
    appleTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: timeout)
    controller.performRequests()
  }

  private func finishApple(_ token: String?, _ error: String?) {
    let result = appleResult
    appleTimeout?.cancel()
    appleTimeout = nil
    appleResult = nil
    appleController = nil
    appleWindow = nil
    if let error = error { result?(FlutterError(code: error, message: nil, details: nil)) }
    else { result?(token) }
  }
}

private final class LegalReaderController: UIViewController, WKNavigationDelegate {
  private let html: String
  private let backLabel: String
  private let allowWithdrawal: Bool
  private let completion: (String?) -> Void
  private var finished = false
  init(html: String, title: String, backLabel: String, allowWithdrawal: Bool, completion: @escaping (String?) -> Void) {
    self.html = html
    self.backLabel = backLabel
    self.allowWithdrawal = allowWithdrawal
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    self.title = title
  }
  required init?(coder: NSCoder) { fatalError("Not supported") }
  deinit { if !finished { completion(nil) } }
  override func viewDidLoad() {
    super.viewDidLoad()
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()
    config.preferences.javaScriptEnabled = false
    let reader = WKWebView(frame: .zero, configuration: config)
    reader.navigationDelegate = self
    reader.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .systemBackground
    view.addSubview(reader)
    NSLayoutConstraint.activate([
      reader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      reader.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      reader.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      reader.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
    ])
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: backLabel, style: .plain, target: self, action: #selector(closeReader))
    reader.loadHTMLString(html, baseURL: nil)
  }
  @objc private func closeReader() { finish(nil) }
  override func accessibilityPerformEscape() -> Bool { finish(nil); return true }
  private func finish(_ action: String?) {
    guard !finished else { return }; finished = true
    dismiss(animated: true) { self.completion(action) }
  }
  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if allowWithdrawal && navigationAction.request.url?.absoluteString == "fridge://privacy/withdraw" {
      decisionHandler(.cancel); finish("withdraw"); return
    }
    decisionHandler(navigationAction.request.url?.scheme == "about" ? .allow : .cancel)
  }
}

extension AppDelegate: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return appleWindow ?? UIWindow()
  }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    guard appleController === controller else { return }
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
      let data = credential.identityToken, let token = String(data: data, encoding: .utf8), !token.isEmpty
      else { finishApple(nil, "APPLE_PROOF_MISSING"); return }
    finishApple(token, nil)
  }
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    guard appleController === controller else { return }
    let cancelled = (error as NSError).domain == ASAuthorizationError.errorDomain &&
      (error as NSError).code == ASAuthorizationError.canceled.rawValue
    finishApple(nil, cancelled ? "APPLE_AUTH_CANCELLED" : "APPLE_AUTH_FAILED")
  }
}
