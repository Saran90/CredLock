package com.credlock.credlock

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.credlock.credlock/autofill"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAutofillEnabled" -> {
                        result.success(isAutofillEnabled())
                    }
                    "enableAutofill" -> {
                        result.success(true)
                    }
                    "disableAutofill" -> {
                        result.success(true)
                    }
                    "provideAutofillData" -> {
                        val packageName = call.argument<String>("packageName")
                        val username = call.argument<String>("username")
                        val password = call.argument<String>("password")
                        
                        if (packageName != null && username != null && password != null) {
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Missing required arguments", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isAutofillEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val autofillManager = getSystemService("autofill")
                autofillManager != null
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }
}
