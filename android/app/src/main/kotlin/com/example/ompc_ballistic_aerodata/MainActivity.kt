package com.example.ompc_ballistic_aerodata

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ompc.ballistic/storage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getDocumentsDirectory") {
                val path = getDocumentsDirectory()
                if (path != null) {
                    result.success(path)
                } else {
                    result.error("UNAVAILABLE", "Documents directory not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getDocumentsDirectory(): String? {
        return context.filesDir.absolutePath
    }
}
