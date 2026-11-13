package com.fenlengtech.fridge

import io.flutter.embedding.engine.FlutterEngine

/** Local plugins after China consent (or global local-home startup). */
object DeferredPluginRegistrant {
    fun registerLocal(engine: FlutterEngine, china: Boolean) {
        engine.plugins.add(io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin())
        engine.plugins.add(io.flutter.plugins.camerax.CameraAndroidCameraxPlugin())
        engine.plugins.add(io.flutter.plugins.imagepicker.ImagePickerPlugin())
        engine.plugins.add(com.baseflow.permissionhandler.PermissionHandlerPlugin())
        if (china) engine.plugins.add(com.fenleng.sdk.nativeidentity.FenlengNativeIdentityPlugin())
    }

    /** Called only from the native persisted global-consent gate. */
    fun registerGlobal(engine: FlutterEngine) {
        engine.plugins.add(io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin())
        engine.plugins.add(io.flutter.plugins.firebase.auth.FlutterFirebaseAuthPlugin())
        engine.plugins.add(io.flutter.plugins.googlesignin.GoogleSignInPlugin())
    }
}
