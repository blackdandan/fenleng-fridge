package com.fenlengtech.fridge

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pluginsRegistered = false
    private var globalPluginsRegistered = false
    private var activeReleaseChannel: String? = null
    @Volatile private var businessAllowed = false
    private var reminders: ReminderBridge? = null
    private var legalResult: MethodChannel.Result? = null
    private val consent by lazy { getSharedPreferences("privacy-consent", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Deliberately omit super: its generated plugin registration runs too early.
        reminders = ReminderBridge(this, flutterEngine) { businessAllowed }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fenleng.fridge/bootstrap")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "legal.open" -> {
                        if (legalResult != null) { result.error("LEGAL_READER_BUSY", null, null); return@setMethodCallHandler }
                        val html = call.argument<String>("html")
                        if (html.isNullOrBlank()) result.error("LEGAL_INVALID", null, null)
                        else {
                            try {
                                legalResult = result
                                startActivityForResult(android.content.Intent(this, LegalActivity::class.java)
                                    .putExtra("html", html)
                                    .putExtra("title", call.argument<String>("title"))
                                    .putExtra("backLabel", call.argument<String>("backLabel"))
                                    .putExtra("errorLabel", call.argument<String>("errorLabel"))
                                    .putExtra("appearance", call.argument<String>("appearance"))
                                    .putExtra("withdrawalEnabled", call.argument<String>("withdrawalEnabled")), 30333)
                            } catch (_: RuntimeException) { legalResult = null; result.error("LEGAL_UNAVAILABLE", null, null) }
                        }
                    }
                    "privacy.read" -> result.success(mapOf(
                        "policyVersion" to consent.getString("policyVersion", null),
                        "releaseChannel" to consent.getString("releaseChannel", null),
                        "acceptedAt" to consent.getString("acceptedAt", null),
                        "withdrawalPending" to consent.getBoolean("withdrawalPending", false),
                        "locale" to consent.getString("locale", null),
                        "appearance" to consent.getString("appearance", "system")
                    ))
                    "privacy.accept" -> {
                        val version = call.argument<String>("policyVersion")
                        val channel = call.argument<String>("releaseChannel")
                        val acceptedAt = call.argument<String>("acceptedAt")
                        if (version.isNullOrBlank() || channel !in listOf("china", "global") || acceptedAt.isNullOrBlank()) {
                            result.error("CONSENT_INVALID", null, null)
                        } else {
                            val saved = consent.edit().putString("policyVersion", version)
                                .putString("releaseChannel", channel).putString("acceptedAt", acceptedAt).commit()
                            if (saved) result.success(true) else result.error("CONSENT_WRITE_FAILED", null, null)
                        }
                    }
                    "plugins.initialize" -> {
                        val channel = call.argument<String>("releaseChannel")
                        val version = call.argument<String>("policyVersion")
                        val accepted = consent.getString("policyVersion", null) == version &&
                            consent.getString("releaseChannel", null) == "china" && consent.contains("acceptedAt")
                        if ((channel != "china" && channel != "global") || (channel == "china" && !accepted)) {
                            result.error("CONSENT_REQUIRED", null, null)
                        } else {
                            if (!pluginsRegistered) {
                                DeferredPluginRegistrant.registerLocal(flutterEngine, channel == "china")
                                pluginsRegistered = true
                            }
                            try {
                                reminders?.authorize(version ?: "", channel ?: "")
                                businessAllowed = true
                                activeReleaseChannel = channel
                                result.success(true)
                            } catch (_: Exception) {result.error("BOOTSTRAP_FAILED", null, null)}
                        }
                    }
                    "plugins.initializeOnline" -> {
                        val version = call.argument<String>("policyVersion")
                        val accepted = businessAllowed && activeReleaseChannel == "global" &&
                            call.argument<String>("releaseChannel") == "global" && version == "V0.4" &&
                            consent.getString("policyVersion", null) == version &&
                            consent.getString("releaseChannel", null) == "global" && consent.contains("acceptedAt") &&
                            !consent.getBoolean("withdrawalPending", false)
                        if (!accepted) result.error("CONSENT_REQUIRED", null, null)
                        else try {
                            if (!globalPluginsRegistered) {
                                DeferredPluginRegistrant.registerGlobal(flutterEngine)
                                globalPluginsRegistered = true
                            }
                            result.success(true)
                        } catch (_: Exception) {result.error("BOOTSTRAP_FAILED", null, null)}
                    }
                    "data.directory" -> {
                        if (!businessAllowed) result.error("CONSENT_REQUIRED", null, null)
                        else result.success(java.io.File(filesDir, "fridge").absolutePath)
                    }
                    "display.locale" -> {
                        val locale = call.argument<String>("locale")
                        val previous = consent.getString("locale", null)
                        val saved = consent.edit().putString("locale", locale).commit()
                        if (saved) result.success(true) else {
                            consent.edit().putString("locale", previous).commit()
                            result.error("DISPLAY_WRITE_FAILED", null, null)
                        }
                    }
                    "display.theme" -> {
                        val appearance = call.argument<String>("appearance")
                        if (appearance !in listOf("system", "light", "dark")) result.error("DISPLAY_INVALID", null, null)
                        else {
                            val previous = consent.getString("appearance", "system")
                            if (consent.edit().putString("appearance", appearance).commit()) result.success(true)
                            else {
                                consent.edit().putString("appearance", previous).commit()
                                result.error("DISPLAY_WRITE_FAILED", null, null)
                            }
                        }
                    }
                    "filing.open" -> {
                        try {
                            startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW,
                                android.net.Uri.parse("https://beian.miit.gov.cn")))
                            result.success(true)
                        } catch (_: RuntimeException) { result.error("FILING_UNAVAILABLE", null, null) }
                    }
                    "privacy.revoke" -> {
                        val saved = consent.edit().remove("policyVersion").remove("releaseChannel").remove("acceptedAt")
                            .putBoolean("withdrawalPending", true).commit()
                        if (saved) {
                            businessAllowed = false
                            try {reminders?.revoke(); result.success(true)}
                            catch (_: Exception) {result.error("CONSENT_WRITE_FAILED", null, null)}
                        }
                        else result.error("CONSENT_WRITE_FAILED", null, null)
                    }
                    "privacy.directory" -> {
                        if (!consent.getBoolean("withdrawalPending", false)) result.error("CONSENT_REQUIRED", null, null)
                        else result.success(java.io.File(filesDir, "fridge").absolutePath)
                    }
                    "privacy.finishRevoke" -> {
                        if (consent.edit().remove("withdrawalPending").commit()) result.success(true)
                        else result.error("CONSENT_WRITE_FAILED", null, null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent); setIntent(intent); reminders?.receive(intent)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (requestCode == 30333) {
            val pending = legalResult; legalResult = null
            pending?.success(if (resultCode == RESULT_OK && data?.getStringExtra("action") == "withdraw") "withdraw" else true)
        } else super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() {
        legalResult?.error("LEGAL_READER_CLOSED", null, null); legalResult = null
        super.onDestroy()
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        reminders?.permissionResult(requestCode)
    }
}
