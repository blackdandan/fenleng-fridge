package com.fenlengtech.fridge.wxapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.fenleng.sdk.nativeidentity.FenlengWechatCallbackDispatcher

/** Only Tencent's verified callback parser forwards responses to the SDK. */
class WXEntryActivity : Activity(), IWXAPIEventHandler {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handle(intent)
    }
    private fun handle(callback: Intent) {
        try {
            @Suppress("DEPRECATION")
            val info = packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.GET_META_DATA)
            val appId = info.metaData?.getString("fridge.wechat.app_id")
            if (appId.isNullOrEmpty() || !WXAPIFactory.createWXAPI(this, appId, true).handleIntent(callback, this)) finish()
        } catch (_: Exception) { finish() }
    }
    override fun onReq(request: BaseReq) { finish() }
    override fun onResp(response: BaseResp) {
        FenlengWechatCallbackDispatcher.dispatch(response)
        finish()
    }
}
