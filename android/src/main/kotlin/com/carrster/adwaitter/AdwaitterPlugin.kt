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
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
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
