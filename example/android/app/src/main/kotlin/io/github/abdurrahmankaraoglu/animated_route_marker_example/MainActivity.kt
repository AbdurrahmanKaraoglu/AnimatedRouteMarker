package io.github.abdurrahmankaraoglu.animated_route_marker_example

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells the Dart side whether a Google Maps key was built in, so the
        // example can show a map-less preview instead of a broken map.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "animated_route_marker_example/config")
            .setMethodCallHandler { call, result ->
                if (call.method == "hasMapsKey") {
                    val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                    val key = info.metaData?.getString("com.google.android.geo.API_KEY")
                    result.success(!key.isNullOrBlank())
                } else {
                    result.notImplemented()
                }
            }
    }
}
