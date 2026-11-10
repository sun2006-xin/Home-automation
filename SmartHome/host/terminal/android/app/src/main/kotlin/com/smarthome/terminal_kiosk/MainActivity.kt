package com.smarthome.terminal_kiosk

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 壁挂终端主活动 (MainActivity)
 *
 * 核心工程职责：
 * 1. 硬件屏幕常亮保活 (FLAG_KEEP_SCREEN_ON)，确保作为壁挂中控不熄屏；
 * 2. 硬件实体按键底层拦截 (onKeyDown)：
 *    - 拦截音量加 (VOLUME_UP) 映射为 [回家模式]；
 *    - 拦截音量减 (VOLUME_DOWN) 映射为 [离家模式]；
 *    - 核心防御：消费事件并返回 true，阻止 Android 弹出原生音量调节条；
 * 3. 通过 MethodChannel 将硬件物理事件无延迟上报至 Flutter 业务层。
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smarthome.terminal/hardware"
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 保持屏幕常亮，防止壁挂终端意外黑屏
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    }

    /**
     * 底层硬件按键事件拦截器
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                methodChannel?.invokeMethod("onPhysicalKey", "VOLUME_UP")
                return true // 彻底消费事件，阻止系统音量悬浮窗弹出
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                methodChannel?.invokeMethod("onPhysicalKey", "VOLUME_DOWN")
                return true // 彻底消费事件，阻止系统音量悬浮窗弹出
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
