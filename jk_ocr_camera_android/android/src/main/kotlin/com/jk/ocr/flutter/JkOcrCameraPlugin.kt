package com.jk.ocr.flutter

import android.app.Activity
import android.content.Intent
import com.jk.ocr.scanner.IdCardScanActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONArray
import org.json.JSONObject

/**
 * Kênh `jk_ocr_camera`, method `scanCard`: mở [IdCardScanActivity] với tham số (map → JSON),
 * trả map kết quả, `null` khi huỷ, hoặc lỗi với mã `permission_denied` / `camera_unavailable` /
 * `busy` / `no_activity`.
 */
class JkOcrCameraPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "jk_ocr_camera")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onDetachedFromActivity() = detach()

    private fun attach(newBinding: ActivityPluginBinding) {
        binding = newBinding
        newBinding.addActivityResultListener(this)
    }

    private fun detach() {
        binding?.removeActivityResultListener(this)
        binding = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanCard" -> scanCard(call, result)
            else -> result.notImplemented()
        }
    }

    private fun scanCard(call: MethodCall, result: Result) {
        val activity = binding?.activity
        if (activity == null) {
            result.error("no_activity", "Plugin chưa gắn vào Activity", null)
            return
        }
        if (pendingResult != null) {
            result.error("busy", "Đang có một phiên quét khác", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
        pendingResult = result
        activity.startActivityForResult(
            IdCardScanActivity.createIntent(activity, JSONObject(args).toString()),
            REQUEST_CODE,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingResult ?: return true
        pendingResult = null

        val json = data?.getStringExtra(IdCardScanActivity.EXTRA_RESULT)
        val error = data?.getStringExtra(IdCardScanActivity.EXTRA_ERROR)
        when {
            resultCode == Activity.RESULT_OK && json != null -> result.success(toValue(JSONObject(json)))
            error != null -> result.error(error, null, null)
            else -> result.success(null) // người dùng bấm quay lại
        }
        return true
    }

    /** JSON → giá trị StandardMessageCodec (Map / List / String / Number / Boolean / null). */
    private fun toValue(v: Any?): Any? = when (v) {
        null, JSONObject.NULL -> null
        is JSONObject -> v.keys().asSequence().associateWith { toValue(v.opt(it)) }
        is JSONArray -> (0 until v.length()).map { toValue(v.opt(it)) }
        else -> v
    }

    private companion object {
        const val REQUEST_CODE = 0x4A4B // "JK"
    }
}
