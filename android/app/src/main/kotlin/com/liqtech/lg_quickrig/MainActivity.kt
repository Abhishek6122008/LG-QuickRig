package com.liqtech.lg_quickrig

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.TransparencyMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.liqtech.lg_quickrig.lg.LGCommandChannel
import com.liqtech.lg_quickrig.lg.LGStatusWidgetProvider

open class MainActivity : FlutterActivity() {

    private var pendingCameraAction: String? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingCameraAction = intent?.getStringExtra(LGStatusWidgetProvider.EXTRA_CAMERA_ACTION)
        // Consume the extra: Android redelivers the task's intent on every
        // recreate, and a stale camera action would relaunch the app in
        // dialog-only mode, whose close handler sends the app to background.
        intent?.removeExtra(LGStatusWidgetProvider.EXTRA_CAMERA_ACTION)

        // When launched purely for a camera dialog, make the window translucent
        // so the dialog appears to float over the launcher instead of showing
        // the full dashboard behind it.
        if (pendingCameraAction != null) {
            setTheme(R.style.TransparentTheme)
        }
        super.onCreate(savedInstanceState)
        if (pendingCameraAction != null) {
            window.setBackgroundDrawableResource(android.R.color.transparent)
            window.statusBarColor = Color.TRANSPARENT
        }
    }

    // Render the Flutter surface with an alpha channel so a transparent
    // Scaffold lets the launcher show through during camera-only launches.
    override fun getTransparencyMode(): TransparencyMode =
        if (pendingCameraAction != null) TransparencyMode.transparent
        else TransparencyMode.opaque

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App was already running; deliver the camera action immediately.
        intent.getStringExtra(LGStatusWidgetProvider.EXTRA_CAMERA_ACTION)?.let {
            channel?.invokeMethod("openCamera", it)
        }
        intent.removeExtra(LGStatusWidgetProvider.EXTRA_CAMERA_ACTION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LGCommandChannel(this).setup(flutterEngine.dartExecutor.binaryMessenger)

        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.liqtech.lg_quickrig/widget",
        )
        // Cold start: Flutter asks for any pending action once it's ready.
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getPendingCameraAction") {
                result.success(pendingCameraAction)
                pendingCameraAction = null
            } else {
                result.notImplemented()
            }
        }
    }
}
