package com.carrster.adwaitter

import android.app.Activity
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AdwaitterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "libadwaitter/style")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        applySoftInputMode(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        applySoftInputMode(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    /**
     * AdwWindow / AdwDialog / AdwPopover already resize themselves from
     * `MediaQuery.viewInsets`. Letting the system also resize the surface
     * (`adjustResize`) makes the Flutter surface be recreated at a new size,
     * which flashes a blank frame when the virtual keyboard appears.
     * From API 30 the IME insets are always dispatched to Flutter, so the
     * system resize can be disabled safely.
     */
    private fun applySoftInputMode(act: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            act.window.setSoftInputMode(
                android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "performSwitchHaptic") {
            val checked = call.argument<Boolean>("checked") ?: true
            val view = activity?.window?.decorView
            if (view != null) {
                val effect = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    if (checked) {
                        android.view.HapticFeedbackConstants.TOGGLE_ON
                    } else {
                        android.view.HapticFeedbackConstants.TOGGLE_OFF
                    }
                } else {
                    android.view.HapticFeedbackConstants.CONTEXT_CLICK
                }
                view.performHapticFeedback(
                    effect,
                    android.view.HapticFeedbackConstants.FLAG_IGNORE_VIEW_SETTING
                )
            }
            result.success(null)
            return
        }
        if (call.method == "setWindowBackground") {
            val argb = (call.argument<Number>("color"))?.toInt()
            val act = activity
            if (argb != null && act != null) {
                act.runOnUiThread {
                    val drawable = android.graphics.drawable.ColorDrawable(argb)
                    act.window.setBackgroundDrawable(drawable)
                    act.window.decorView.setBackgroundColor(argb)
                }
            }
            result.success(null)
            return
        }
        if (call.method == "getSystemDynamicAccent") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val ctx = activity ?: applicationContext
                if (ctx == null) {
                    result.success(null)
                    return
                }
                val res = ctx.resources
                val theme = activity?.theme ?: ctx.theme
                val lightColor = res.getColor(android.R.color.system_accent1_600, theme)
                val darkColor = res.getColor(android.R.color.system_accent1_400, theme)
                result.success(
                    mapOf(
                        "light" to lightColor,
                        "dark" to darkColor
                    )
                )
            } else {
                result.success(null)
            }
        } else {
            result.notImplemented()
        }
    }
}
