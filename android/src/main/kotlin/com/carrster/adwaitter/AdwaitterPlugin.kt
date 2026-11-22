package com.carrster.adwaitter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream

class AdwaitterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private companion object {
        const val REQ_OPEN_FILES = 41001
        const val REQ_SAVE_FILE = 41002
    }

    private lateinit var channel: MethodChannel
    private lateinit var portalChannel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPortalResult: Result? = null
    private var pendingPortalRequestCode: Int = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "libadwaitter/style")
        channel.setMethodCallHandler(this)
        portalChannel = MethodChannel(binding.binaryMessenger, "libadwaitter/portal")
        portalChannel.setMethodCallHandler { call, result ->
            onPortalMethodCall(call, result)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        portalChannel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        applySoftInputMode(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        applySoftInputMode(binding.activity)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
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
        if (call.method == "isInMultiWindowMode") {
            val inMultiWindow = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                activity?.isInMultiWindowMode ?: false
            } else {
                false
            }
            result.success(inMultiWindow)
            return
        }
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

    private fun onPortalMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "openUri" -> {
                val uriStr = call.argument<String>("uri")
                if (uriStr.isNullOrBlank()) {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "errorMessage" to "Missing URI.",
                        )
                    )
                    return
                }
                val ctx = activity ?: applicationContext
                if (ctx == null) {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "errorMessage" to "No active Android context.",
                        )
                    )
                    return
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uriStr)).apply {
                        if (activity == null) {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                    }
                    ctx.startActivity(intent)
                    result.success(mapOf("status" to "granted"))
                } catch (e: android.content.ActivityNotFoundException) {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "errorMessage" to "No application found to open URI: $uriStr",
                        )
                    )
                } catch (e: Exception) {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "errorMessage" to (e.message ?: "Failed to open URI."),
                        )
                    )
                }
            }
            "openFiles" -> {
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "No active Android activity.", null)
                    return
                }
                if (pendingPortalResult != null) {
                    result.error("BUSY", "Another file dialog is already open.", null)
                    return
                }
                val multiple = call.argument<Boolean>("multiple") ?: false
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    if (multiple) {
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                }
                pendingPortalResult = result
                pendingPortalRequestCode = REQ_OPEN_FILES
                act.startActivityForResult(intent, REQ_OPEN_FILES)
            }
            "saveFile" -> {
                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "No active Android activity.", null)
                    return
                }
                if (pendingPortalResult != null) {
                    result.error("BUSY", "Another file dialog is already open.", null)
                    return
                }
                val currentName = call.argument<String>("currentName") ?: "file"
                val mime = if (currentName.endsWith(".png", ignoreCase = true)) {
                    "image/png"
                } else {
                    "application/octet-stream"
                }
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, currentName)
                }
                pendingPortalResult = result
                pendingPortalRequestCode = REQ_SAVE_FILE
                act.startActivityForResult(intent, REQ_SAVE_FILE)
            }
            "writeUriBytes" -> {
                val ctx = activity ?: applicationContext
                val uriStr = call.argument<String>("uri")
                val bytes = call.argument<ByteArray>("bytes")
                if (ctx == null || uriStr == null || bytes == null) {
                    result.success(false)
                    return
                }
                try {
                    val uri = Uri.parse(uriStr)
                    ctx.contentResolver.openOutputStream(uri)?.use { out ->
                        out.write(bytes)
                        out.flush()
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("WRITE_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != pendingPortalRequestCode || pendingPortalResult == null) {
            return false
        }
        val result = pendingPortalResult!!
        pendingPortalResult = null
        pendingPortalRequestCode = 0

        if (requestCode == REQ_OPEN_FILES) {
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(emptyList<String>())
                return true
            }
            val paths = mutableListOf<String>()
            val clipData = data.clipData
            if (clipData != null) {
                for (i in 0 until clipData.itemCount) {
                    clipData.getItemAt(i).uri?.let { uri ->
                        copyUriToCache(uri)?.let { paths.add(it) }
                    }
                }
            } else {
                data.data?.let { uri ->
                    copyUriToCache(uri)?.let { paths.add(it) }
                }
            }
            result.success(paths)
            return true
        }

        if (requestCode == REQ_SAVE_FILE) {
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result.success(null)
                return true
            }
            result.success(data.data.toString())
            return true
        }

        return false
    }

    private fun copyUriToCache(uri: Uri): String? {
        val ctx = activity ?: applicationContext ?: return null
        return try {
            var displayName = "picked_file"
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = cursor.getString(idx)
                        if (!name.isNullOrBlank()) {
                            displayName = name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                        }
                    }
                }
            }
            val target = File(ctx.cacheDir, "adw_portal_${System.currentTimeMillis()}_$displayName")
            ctx.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output ->
                    input.copyTo(output)
                }
            }
            target.absolutePath
        } catch (_: Exception) {
            null
        }
    }
}
