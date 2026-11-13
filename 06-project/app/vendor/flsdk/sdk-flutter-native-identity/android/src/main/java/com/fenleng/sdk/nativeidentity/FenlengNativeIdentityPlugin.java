package com.fenleng.sdk.nativeidentity;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import com.tencent.mm.opensdk.modelbase.BaseResp;
import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.lang.ref.WeakReference;
import java.util.Map;
import java.util.UUID;

public final class FenlengNativeIdentityPlugin
    implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private static final String CHANNEL = "com.fenleng.sdk/native_identity";
  private static WeakReference<FenlengNativeIdentityPlugin> activePlugin =
      new WeakReference<>(null);

  private Context context;
  private MethodChannel channel;
  private IWXAPI wechat;
  private String wechatAppId;
  private String wechatScope = "snsapi_userinfo";
  private String expectedState;
  private MethodChannel.Result pendingResult;
  private final Handler handler = new Handler(Looper.getMainLooper());
  private Runnable timeout;
  private final java.util.ArrayDeque<String> retiredStates = new java.util.ArrayDeque<>();

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    context = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
    activePlugin = new WeakReference<>(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    if (activePlugin.get() == this) activePlugin.clear();
    finishError("IDENTITY_ENGINE_DETACHED", "身份认证服务已停止", null);
    channel = null;
    context = null;
    wechat = null;
  }

  @Override
  @SuppressWarnings("unchecked")
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    Map<String, Object> arguments = call.arguments instanceof Map
        ? (Map<String, Object>) call.arguments : null;
    switch (call.method) {
      case "configureWechat":
        configureWechat(arguments, result);
        break;
      case "isAvailable":
        if (!isWechat(arguments)) {
          result.success(false);
        } else if (wechat == null) {
          result.error("IDENTITY_NOT_CONFIGURED", "微信身份渠道尚未配置", null);
        } else {
          result.success(wechat.isWXAppInstalled());
        }
        break;
      case "authorize":
        if (!isWechat(arguments)) {
          result.error("IDENTITY_PROVIDER_UNSUPPORTED", "当前身份渠道尚未接入", provider(arguments));
        } else {
          authorizeWechat(result);
        }
        break;
      default:
        result.notImplemented();
    }
  }

  private void configureWechat(Map<String, Object> arguments, MethodChannel.Result result) {
    if (pendingResult != null) {
      result.error("IDENTITY_AUTH_IN_PROGRESS", "Identity authorization is in progress", null);
      return;
    }
    String appId = stringValue(arguments, "appId");
    if (appId == null || appId.isEmpty()) {
      result.error("IDENTITY_CONFIG_INVALID", "微信 AppID 不能为空", null);
      return;
    }
    wechatAppId = appId;
    String scope = stringValue(arguments, "scope");
    if (scope != null && !scope.isEmpty()) wechatScope = scope;
    wechat = WXAPIFactory.createWXAPI(context, wechatAppId, true);
    // registerApp sends a broadcast to WeChat and may return false when WeChat
    // is not installed. Configuration must not prevent the host app starting;
    // availability and sendReq provide the actionable runtime result instead.
    wechat.registerApp(wechatAppId);
    result.success(null);
  }

  private void authorizeWechat(MethodChannel.Result result) {
    if (wechat == null) {
      result.error("IDENTITY_NOT_CONFIGURED", "微信身份渠道尚未配置", null);
      return;
    }
    if (!wechat.isWXAppInstalled()) {
      result.error("WECHAT_NOT_INSTALLED", "请先安装微信", null);
      return;
    }
    if (pendingResult != null) {
      result.error("IDENTITY_AUTH_IN_PROGRESS", "身份授权正在进行", null);
      return;
    }
    expectedState = "fenleng_" + UUID.randomUUID().toString().replace("-", "");
    SendAuth.Req request = new SendAuth.Req();
    request.scope = wechatScope;
    request.state = expectedState;
    pendingResult = result;
    timeout = () -> {
      if (pendingResult == result) finishError("WECHAT_AUTH_TIMEOUT", "WeChat authorization timed out", null);
    };
    handler.postDelayed(timeout, 120000);
    try {
      if (!wechat.sendReq(request)) finishError("WECHAT_SEND_FAILED", "无法打开微信授权", null);
    } catch (RuntimeException ignored) {
      finishError("WECHAT_SEND_FAILED", "WeChat authorization could not be opened", null);
    }
  }

  static void dispatchWechatResponse(BaseResp response) {
    FenlengNativeIdentityPlugin plugin = activePlugin.get();
    if (plugin != null) plugin.handleWechatResponse(response);
  }

  private void handleWechatResponse(BaseResp response) {
    if (!(response instanceof SendAuth.Resp)) return;
    SendAuth.Resp auth = (SendAuth.Resp) response;
    if (pendingResult == null || retiredStates.contains(auth.state)) return;
    if (expectedState == null || !expectedState.equals(auth.state)) {
      finishError("WECHAT_STATE_MISMATCH", "微信授权校验失败", null);
      return;
    }
    switch (response.errCode) {
      case BaseResp.ErrCode.ERR_OK:
        if (auth.code == null || auth.code.isEmpty()) {
          finishError("WECHAT_CODE_MISSING", "微信未返回授权码", null);
        } else {
          finishSuccess(auth.code);
        }
        break;
      case BaseResp.ErrCode.ERR_USER_CANCEL:
        finishError("WECHAT_AUTH_CANCELLED", "已取消微信授权", response.errCode);
        break;
      case BaseResp.ErrCode.ERR_AUTH_DENIED:
        finishError("WECHAT_AUTH_DENIED", "微信授权被拒绝", response.errCode);
        break;
      case BaseResp.ErrCode.ERR_UNSUPPORT:
        finishError("WECHAT_UNSUPPORTED", "当前微信版本不支持授权", response.errCode);
        break;
      default:
        finishError("WECHAT_AUTH_FAILED", "微信授权未完成", response.errCode);
    }
  }

  private void finishSuccess(String code) {
    MethodChannel.Result result = pendingResult;
    clearPending();
    if (result != null) result.success(code);
  }

  private void finishError(String code, String message, Object details) {
    MethodChannel.Result result = pendingResult;
    clearPending();
    if (result != null) result.error(code, message, details);
  }

  private void clearPending() {
    if (timeout != null) handler.removeCallbacks(timeout);
    timeout = null;
    if (expectedState != null) {
      retiredStates.addLast(expectedState);
      if (retiredStates.size() > 8) retiredStates.removeFirst();
    }
    pendingResult = null;
    expectedState = null;
  }

  private static boolean isWechat(Map<String, Object> arguments) {
    return "wechat".equals(provider(arguments));
  }

  private static String provider(Map<String, Object> arguments) {
    return stringValue(arguments, "provider");
  }

  private static String stringValue(Map<String, Object> arguments, String key) {
    Object value = arguments == null ? null : arguments.get(key);
    return value instanceof String ? (String) value : null;
  }
}
