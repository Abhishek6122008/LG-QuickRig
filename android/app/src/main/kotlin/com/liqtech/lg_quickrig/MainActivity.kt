package com.liqtech.lg_quickrig

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.liqtech.lg_quickrig.lg.LGCommandChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LGCommandChannel(this).setup(flutterEngine.dartExecutor.binaryMessenger)
    }
}
