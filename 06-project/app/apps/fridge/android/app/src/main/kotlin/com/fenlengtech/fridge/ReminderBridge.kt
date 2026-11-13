package com.fenlengtech.fridge

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

internal class ReminderBridge(private val activity: FlutterActivity, engine: FlutterEngine,
    private val allowed: () -> Boolean) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "fenleng.fridge/notifications")
    private val main = Handler(Looper.getMainLooper())
    private val store by lazy { LocalReminders(activity.applicationContext) }
    private var permissionResult: MethodChannel.Result? = null
    private var launchDay: String? = null
    init {
        receive(activity.intent)
        channel.setMethodCallHandler { call, result ->
            if (!allowed()) {result.error("CONSENT_REQUIRED", null, null); return@setMethodCallHandler}
            when (call.method) {
                "status" -> work(result) {store.status()}
                "request" -> request(result)
                "enable" -> work(result) {
                    val value = call.argument<Boolean>("enabled") ?: throw IllegalArgumentException()
                    store.enable(value); store.status()
                }
                "sync" -> work(result) {
                    val cycles = JSONArray(call.argument<List<Map<String, Any>>>("cycles") ?: throw IllegalArgumentException())
                    val copy = JSONObject(call.argument<Map<String, String>>("copy") ?: throw IllegalArgumentException())
                    store.sync(ReminderCycle.list(cycles), ReminderCopy.parse(copy)); true
                }
                "consumeTap" -> work(result) {store.consumeTap()}
                "settings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
                        activity.startActivity(intent); result.success(true)
                    } catch (_: Exception) {result.error("NOTIFICATION_SETTINGS_FAILED", null, null)}
                }
                else -> result.notImplemented()
            }
        }
    }
    fun authorize(version: String, channel: String) {
        store.authorizeBusiness(version, channel)
        launchDay?.let {store.pendingDay(it)}; launchDay = null
    }
    fun revoke() {launchDay = null; store.revoke()}
    private fun work(result: MethodChannel.Result, action: () -> Any?) {
        LocalReminders.executor.execute {
            try {
                check(allowed()); val answer = action()
                main.post {result.success(answer)}
            } catch (_: Exception) {main.post {result.error("NOTIFICATION_FAILED", null, null)}}
        }
    }
    private fun request(result: MethodChannel.Result) {
        if (permissionResult != null) {result.error("PERMISSION_IN_PROGRESS", null, null); return}
        try {
            store.requested()
            if (Build.VERSION.SDK_INT < 33 || activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                result.success(store.status()); return
            }
            permissionResult = result
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
        } catch (_: Exception) {permissionResult = null; result.error("NOTIFICATION_PERMISSION_FAILED", null, null)}
    }
    fun permissionResult(code: Int) {
        if (code != REQUEST) return
        val result = permissionResult; permissionResult = null
        if (allowed()) result?.success(store.status()) else result?.error("CONSENT_REQUIRED", null, null)
    }
    fun receive(intent: Intent?) {
        if (intent?.action != LocalReminders.OPEN) return
        val day = intent.getStringExtra("reminderDay") ?: return
        if (!day.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) return
        if (!allowed()) {launchDay = day; return}
        LocalReminders.executor.execute {
            try {
                if (!allowed()) return@execute
                store.pendingDay(day)
                main.post {channel.invokeMethod("openReminder", mapOf("day" to day))}
            } catch (_: Exception) {}
        }
    }
    companion object {private const val REQUEST = 9017}
}
