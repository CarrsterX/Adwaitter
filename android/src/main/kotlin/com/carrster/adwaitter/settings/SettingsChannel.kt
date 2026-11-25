package com.carrster.adwaitter.settings

import android.content.Context
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

internal class SettingsChannel(
    messenger: BinaryMessenger,
    private val contextProvider: () -> Context?,
) : MethodCallHandler {
    private val channel = MethodChannel(messenger, "libadwaitter/settings")
    private var animatorScaleObserver: ContentObserver? = null

    init {
        channel.setMethodCallHandler(this)
        registerAnimatorScaleObserver()
    }

    fun dispose() {
        unregisterAnimatorScaleObserver()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getAnimationSettings") {
            result.success(buildAndroidAnimationSettingsMap())
        } else {
            result.notImplemented()
        }
    }

    private fun buildAndroidAnimationSettingsMap(): Map<String, Any> {
        val ctx = contextProvider()
        val scale = if (ctx != null) {
            try {
                Settings.Global.getFloat(
                    ctx.contentResolver,
                    Settings.Global.ANIMATOR_DURATION_SCALE,
                    1.0f,
                ).coerceIn(0.0f, 10.0f)
            } catch (_: Throwable) {
                1.0f
            }
        } else {
            1.0f
        }
        return mapOf(
            "enableAnimations" to (scale > 0.0f),
            "durationFactor" to scale.toDouble(),
            "desktop" to "Android",
        )
    }

    private fun registerAnimatorScaleObserver() {
        val ctx = contextProvider() ?: return
        if (animatorScaleObserver != null) return
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                channel.invokeMethod(
                    "onAnimationSettingsChanged",
                    buildAndroidAnimationSettingsMap(),
                )
            }
        }
        try {
            ctx.contentResolver.registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
                false,
                observer,
            )
            animatorScaleObserver = observer
        } catch (_: Throwable) {
            // Ignore if restricted on older/custom ROMs
        }
    }

    private fun unregisterAnimatorScaleObserver() {
        val obs = animatorScaleObserver ?: return
        animatorScaleObserver = null
        try {
            contextProvider()?.contentResolver?.unregisterContentObserver(obs)
        } catch (_: Throwable) {
        }
    }
}
