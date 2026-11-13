package com.fenleng.sdk.nativeidentity;

import com.tencent.mm.opensdk.modelbase.BaseResp;

/** Bridge used by the host package-name-specific WXEntryActivity. */
public final class FenlengWechatCallbackDispatcher {
  private FenlengWechatCallbackDispatcher() {}

  public static void dispatch(BaseResp response) {
    FenlengNativeIdentityPlugin.dispatchWechatResponse(response);
  }
}
