package com.designer1974.devoo_radio_kids

import android.content.Intent
import android.net.Uri
import android.os.Build
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Activity compatibile con la riproduzione in background (notifica con i controlli)
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kids/app").setMethodCallHandler { call, result ->
            when (call.method) {
                "is64" -> result.success(Build.SUPPORTED_64_BIT_ABIS.isNotEmpty())
                "openUrl" -> {
                    val ok = try {
                        startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        true
                    } catch (_: Exception) {
                        false
                    }
                    result.success(ok)
                }
                else -> result.notImplemented()
            }
        }
    }
}
