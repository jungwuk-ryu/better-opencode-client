package com.jungwuk.opencodeclient

import android.content.ClipDescription
import android.content.ClipboardManager
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CLIPBOARD_IMAGE_CHANNEL =
            "opencode_mobile_remote/clipboard_image"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CLIPBOARD_IMAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "readClipboardImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(readClipboardImage())
        }
    }

    private fun readClipboardImage(): Map<String, Any>? {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager
            ?: return null
        val clipData = clipboard.primaryClip ?: return null
        if (clipData.itemCount == 0) {
            return null
        }
        val item = clipData.getItemAt(0)
        val uri = item.uri ?: return null
        val mimeType = resolveClipboardMimeType(
            description = clipboard.primaryClipDescription ?: clipData.description,
            uriString = uri.toString(),
        ) ?: return null
        if (!mimeType.startsWith("image/")) {
            return null
        }
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: return null
        if (bytes.isEmpty()) {
            return null
        }
        return mapOf(
            "bytes" to bytes,
            "mimeType" to mimeType,
            "filename" to (queryDisplayName(uri.toString()) ?: defaultFilename(mimeType)),
        )
    }

    private fun resolveClipboardMimeType(
        description: ClipDescription?,
        uriString: String,
    ): String? {
        val descriptionMimeType = description
            ?.let {
                for (index in 0 until it.mimeTypeCount) {
                    val candidate = normalizeMimeType(it.getMimeType(index))
                    if (candidate.startsWith("image/")) {
                        return@let candidate
                    }
                }
                null
            }
        if (descriptionMimeType != null) {
            return descriptionMimeType
        }
        return normalizeMimeType(contentResolver.getType(android.net.Uri.parse(uriString)) ?: "")
            .takeIf { it.startsWith("image/") }
    }

    private fun queryDisplayName(uriString: String): String? {
        val cursor = contentResolver.query(
            android.net.Uri.parse(uriString),
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        ) ?: return null
        cursor.use {
            if (!it.moveToFirst()) {
                return null
            }
            val columnIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (columnIndex == -1) {
                return null
            }
            return it.getString(columnIndex)
        }
    }

    private fun normalizeMimeType(mimeType: String): String {
        return when (mimeType.substringBefore(';').trim().lowercase()) {
            "image/jpg" -> "image/jpeg"
            else -> mimeType.substringBefore(';').trim().lowercase()
        }
    }

    private fun defaultFilename(mimeType: String): String {
        val extension = when (mimeType) {
            "image/png" -> "png"
            "image/jpeg" -> "jpg"
            "image/gif" -> "gif"
            "image/webp" -> "webp"
            else -> "png"
        }
        return "pasted-image.$extension"
    }
}
