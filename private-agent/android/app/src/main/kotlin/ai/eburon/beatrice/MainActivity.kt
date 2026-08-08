package ai.eburon.beatrice

import android.content.Intent
import android.provider.Settings
import android.os.Build
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.graphics.PixelFormat
import android.graphics.Color
import android.view.Gravity
import android.view.WindowManager
import android.view.View
import android.widget.Button
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ai.eburon.beatrice/accessibility"
    private val EVENT_CHANNEL = "ai.eburon.beatrice/accessibility_events"
    private var eventSink: EventChannel.EventSink? = null
    private var overlayView: View? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    AgentAccessibilityService.eventListener = { eventMap ->
                        runOnUiThread {
                            eventSink?.success(eventMap)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    AgentAccessibilityService.eventListener = null
                }
            }
        )

        registerAccessibilityChannel(flutterEngine, this)
    }

    companion object {
        fun registerAccessibilityChannel(flutterEngine: FlutterEngine, context: android.content.Context) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.eburon.beatrice/accessibility")
                .setMethodCallHandler { call, result ->
                    android.util.Log.d("BeatriceOSKotlin", "Received method call: ${call.method}")
                    when (call.method) {
                        "ping" -> result.success(true)

                        "startVoiceForeground" -> {
                            BeatriceForegroundService.start(context)
                            result.success(true)
                        }

                        "stopVoiceForeground" -> {
                            BeatriceForegroundService.stop(context)
                            result.success(true)
                        }

                        "isForegroundRunning" -> {
                            // A simple proxy: the service sets a static flag if desired.
                            // For now we just report true; the real state can be checked via a manager later.
                            result.success(true)
                        }

                        "logToNative" -> {
                            val msg = call.argument<String>("message") ?: ""
                            android.util.Log.d("BeatriceOSDart", msg)
                            result.success(true)
                        }

                        "isServiceRunning" -> {
                            result.success(AgentAccessibilityService.isRunning())
                        }

                        "getDeviceProfile" -> {
                            result.success(buildDeviceProfile(context))
                        }

                        "checkOverlayPermission" -> {
                            result.success(Settings.canDrawOverlays(context))
                        }

                        "requestOverlayPermission" -> {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        }

                        "showMacroOverlay" -> {
                            // Macro overlay requires an Activity context, so we just ignore or return error if called from background
                            result.error("NOT_SUPPORTED", "Macro overlay not supported from background", null)
                        }

                        "hideMacroOverlay" -> {
                            result.success(true)
                        }

                        "openAccessibilitySettings" -> {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(true)
                        }

                        "dumpScreen" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val nodes = service.dumpScreen()
                                result.success(nodes)
                            }
                        }

                        "takeScreenshot" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                                    service.takeScreenshot { base64 ->
                                        if (base64 != null) {
                                            result.success(base64)
                                        } else {
                                            result.error("SCREENSHOT_FAILED", "Failed to capture screenshot", null)
                                        }
                                    }
                                } else {
                                    result.error("NOT_SUPPORTED", "Screenshot requires Android 11+", null)
                                }
                            }
                        }

                        "clickAtCoordinates" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val x = call.argument<Double>("x")?.toFloat() ?: 0f
                                val y = call.argument<Double>("y")?.toFloat() ?: 0f
                                result.success(service.clickAtCoordinates(x, y))
                            }
                        }

                        "typeText" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val text = call.argument<String>("text") ?: ""
                                val fieldHint = call.argument<String>("fieldHint")
                                result.success(service.typeText(text, fieldHint))
                            }
                        }

                        "scroll" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val direction = call.argument<String>("direction") ?: "down"
                                result.success(service.scroll(direction))
                            }
                        }

                        "pressBack" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.pressBack())
                            }
                        }

                        "pressHome" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.pressHome())
                            }
                        }

                        "getCurrentPackage" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                result.success(service.getCurrentPackage())
                            }
                        }

                        "swipe" -> {
                            val service = AgentAccessibilityService.instance
                            if (service == null) {
                                result.error("SERVICE_NOT_RUNNING", "Accessibility service is not running", null)
                            } else {
                                val startX = call.argument<Double>("startX")?.toFloat() ?: 0f
                                val startY = call.argument<Double>("startY")?.toFloat() ?: 0f
                                val endX = call.argument<Double>("endX")?.toFloat() ?: 0f
                                val endY = call.argument<Double>("endY")?.toFloat() ?: 0f
                                result.success(service.swipe(startX, startY, endX, endY))
                            }
                        }

                        "showOverlay" -> {
                            // Implementation removed; overlay is handled via Flutter overlay window flag.
                            result.success(true)
                        }

                        "hideOverlay" -> {
                            // Implementation removed; overlay is handled via Flutter overlay window flag.
                            result.success(true)
                        }

                        else -> result.notImplemented()
                    }
                }
        }

        private fun buildDeviceProfile(context: android.content.Context): Map<String, Any> {
            val metrics = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                context.display
            } else {
                @Suppress("DEPRECATION")
                (context.getSystemService(android.content.Context.WINDOW_SERVICE) as android.view.WindowManager).defaultDisplay
            }?.let { display ->
                val displayMetrics = android.util.DisplayMetrics()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display.getRealMetrics(displayMetrics)
                } else {
                    @Suppress("DEPRECATION")
                    display.getMetrics(displayMetrics)
                }
                mapOf(
                    "widthPixels" to displayMetrics.widthPixels,
                    "heightPixels" to displayMetrics.heightPixels,
                    "density" to displayMetrics.density.toDouble(),
                    "densityDpi" to displayMetrics.densityDpi.toDouble()
                )
            } ?: mapOf(
                "widthPixels" to 0,
                "heightPixels" to 0,
                "density" to 0.0,
                "densityDpi" to 0.0
            )

            val shizukuAvailable = try {
                Class.forName("rikka.shizuku.Shizuku") != null
            } catch (e: ClassNotFoundException) {
                false
            }
            val shizukuPermission = false

            return mapOf(
                "manufacturer" to Build.MANUFACTURER,
                "brand" to Build.BRAND,
                "model" to Build.MODEL,
                "device" to Build.DEVICE,
                "sdkInt" to Build.VERSION.SDK_INT,
                "androidRelease" to Build.VERSION.RELEASE,
                "securityPatch" to (Build.VERSION.SECURITY_PATCH ?: ""),
                "locale" to Locale.getDefault().toString(),
                "display" to metrics,
                "capabilities" to mapOf(
                    "accessibilityEnabled" to AgentAccessibilityService.isRunning(),
                    "screenshotSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
                    "shizukuAvailable" to shizukuAvailable,
                    "shizukuPermission" to shizukuPermission,
                    "overlayPermission" to Settings.canDrawOverlays(context)
                ),
                "capturedAt" to System.currentTimeMillis()
            )
        }
    }
}

class BackgroundEngineReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
        val engine = io.flutter.embedding.engine.FlutterEngineCache
            .getInstance()
            .get("myCachedEngine")
        if (engine == null) {
            android.util.Log.e("BeatriceOS", "Background engine myCachedEngine was not found")
            return
        }

        android.util.Log.d(
            "BeatriceOS",
            "Registering accessibility channel on myCachedEngine " +
                "(engine=${System.identityHashCode(engine)}, " +
                "dartExecuting=${engine.dartExecutor.isExecutingDart})"
        )
        MainActivity.registerAccessibilityChannel(engine, context.applicationContext)
    }
}
