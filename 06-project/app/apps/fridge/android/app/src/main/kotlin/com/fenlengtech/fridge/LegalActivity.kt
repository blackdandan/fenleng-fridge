package com.fenlengtech.fridge

import android.app.Activity
import android.graphics.Color
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/** Offline legal reader, available before business plugin registration. */
class LegalActivity : Activity() {
    private var reader: WebView? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dark = when (intent.getStringExtra("appearance")) {
            "dark" -> true
            "light" -> false
            else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        }
        val paper = if (dark) Color.rgb(25, 35, 29) else Color.rgb(255, 255, 250)
        val ink = if (dark) Color.rgb(224, 230, 220) else Color.rgb(44, 60, 50)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(paper)
        }
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        val header = LinearLayout(this)
        header.addView(Button(this).apply {
            text = intent.getStringExtra("backLabel")
            textSize = 16f
            setTextColor(ink)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { finish() }
        })
        header.addView(TextView(this).apply {
            text = intent.getStringExtra("title")
            textSize = 20f
            setPadding(16, 16, 16, 16)
            setTextColor(ink)
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        root.addView(header)
        try {
            reader = WebView(this).apply {
                settings.javaScriptEnabled = false
                settings.domStorageEnabled = false
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                settings.blockNetworkLoads = true
                settings.setSupportZoom(true)
                settings.textZoom = (resources.configuration.fontScale * 100).toInt()
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                        if (intent.getStringExtra("withdrawalEnabled") == "true" && request?.url.toString() == "fridge://privacy/withdraw") {
                            setResult(RESULT_OK, android.content.Intent().putExtra("action", "withdraw")); finish()
                        }
                        return true
                    }
                }
                loadDataWithBaseURL(null, intent.getStringExtra("html").orEmpty(), "text/html", "UTF-8", null)
            }
            root.addView(reader, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        } catch (_: RuntimeException) {
            root.addView(TextView(this).apply {
                text = intent.getStringExtra("errorLabel")
                textSize = 18f
                setPadding(24, 24, 24, 24)
            })
        }
        setContentView(root)
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= 30) {
            // Draw the document background behind system bars; root applies insets.
            window.setDecorFitsSystemWindows(false)
            val flags = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(if (dark) 0 else flags, flags)
        }
        root.requestApplyInsets()
    }
    override fun onDestroy() {
        reader?.stopLoading()
        (reader?.parent as? ViewGroup)?.removeView(reader)
        reader?.destroy()
        reader = null
        super.onDestroy()
    }
}
