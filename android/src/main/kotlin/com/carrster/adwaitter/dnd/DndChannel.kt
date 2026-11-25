package com.carrster.adwaitter.dnd

import android.app.Activity
import android.os.Build
import android.view.DragEvent
import com.carrster.adwaitter.core.UriCacheHelper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class DndChannel(
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "libadwaitter/dnd")

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    fun attach(act: Activity) {
        val density = act.resources.displayMetrics.density.coerceAtLeast(1f)
        act.window.decorView.setOnDragListener { _, event ->
            when (event.action) {
                DragEvent.ACTION_DRAG_STARTED -> true
                DragEvent.ACTION_DRAG_ENTERED -> {
                    channel.invokeMethod(
                        "onDropEvent",
                        mapOf(
                            "type" to "enter",
                            "x" to (event.x / density).toDouble(),
                            "y" to (event.y / density).toDouble(),
                        ),
                    )
                    true
                }
                DragEvent.ACTION_DRAG_LOCATION -> {
                    channel.invokeMethod(
                        "onDropEvent",
                        mapOf(
                            "type" to "update",
                            "x" to (event.x / density).toDouble(),
                            "y" to (event.y / density).toDouble(),
                        ),
                    )
                    true
                }
                DragEvent.ACTION_DRAG_EXITED, DragEvent.ACTION_DRAG_ENDED -> {
                    channel.invokeMethod("onDropEvent", mapOf("type" to "leave"))
                    true
                }
                DragEvent.ACTION_DROP -> {
                    val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        act.requestDragAndDropPermissions(event)
                    } else {
                        null
                    }
                    try {
                        val files = mutableListOf<String>()
                        val texts = mutableListOf<String>()
                        val clip = event.clipData
                        if (clip != null) {
                            for (i in 0 until clip.itemCount) {
                                val item = clip.getItemAt(i)
                                item.uri?.let { uri ->
                                    UriCacheHelper.copyUriToCache(act, uri)?.let { files.add(it) }
                                }
                                item.text?.toString()?.takeIf { it.isNotBlank() }?.let {
                                    texts.add(it)
                                }
                            }
                        }
                        val payload = mutableMapOf<String, Any>(
                            "type" to "drop",
                            "x" to (event.x / density).toDouble(),
                            "y" to (event.y / density).toDouble(),
                        )
                        if (files.isNotEmpty()) {
                            payload["files"] = files
                        }
                        if (texts.isNotEmpty()) {
                            payload["text"] = texts.joinToString("\n")
                        }
                        channel.invokeMethod("onDropEvent", payload)
                    } finally {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            perms?.release()
                        }
                    }
                    true
                }
                else -> false
            }
        }
    }

    fun detach(act: Activity?) {
        act?.window?.decorView?.setOnDragListener(null)
    }
}
