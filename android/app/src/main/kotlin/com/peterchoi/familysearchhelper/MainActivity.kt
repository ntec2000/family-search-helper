package com.peterchoi.familysearchhelper

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.peterchoi.familysearchhelper/app"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exitApp" -> {
                        result.success(true)
                        // 백그라운드에 잔존하지 않도록 태스크까지 완전히 제거 후 프로세스 종료
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            finishAndRemoveTask()
                        } else {
                            finishAffinity()
                        }
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
