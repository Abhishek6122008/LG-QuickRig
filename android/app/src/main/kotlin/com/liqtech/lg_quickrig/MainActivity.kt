package com.liqtech.lg_quickrig

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import com.liqtech.lg_quickrig.lg.LGCommandChannel

/**
 * Entry point for the Flutter Android host.
 *
 * [configureFlutterEngine] is called once when the Flutter engine starts.
 * Register all platform channels here so they're available as soon as
 * the Dart isolate boots — before any widget builds.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wire up the LG command channel so the Dart layer can invoke
        // native operations (used by home-screen widgets & Quick Settings
        // tiles that need to act without opening the main app).
        LGCommandChannel(this).setup(flutterEngine.dartExecutor.binaryMessenger)
    }
}
