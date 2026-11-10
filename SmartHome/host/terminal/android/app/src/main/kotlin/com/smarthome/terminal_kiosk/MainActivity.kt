package com.smarthome.terminal_kiosk

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 工业级壁挂 Kiosk 终端主活动 (MainActivity)
 *
 * 核心安全防御机制 (写死防误退)：
 * 1. 沉浸式黏性全屏 (Immersive Sticky)：隐藏导航栏与状态栏，滑动浮出 200ms 内自动强行收回；
 * 2. 屏幕触控重置 (dispatchTouchEvent)：手指滑动即强制重刷全屏状态；
 * 3. 任务置顶守护 (onStop / onUserLeaveHint)：任何意外切出后台 (Home/多任务) 100ms 内瞬间通过 moveToFront 拉回；
 * 4. 原生屏幕专机固定 (LockTask / Screen Pinning)：深度禁用系统级虚拟按键；
 * 5. 唯一合法退出口：设置界面内经过二次安全确认后，由业务层发送 exitTerminal 指令退出。
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smarthome.terminal/hardware"
    private var methodChannel: MethodChannel? = null
    private var isAuthorizedExit = false
    private var isNavigatingToSettings = false
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 1. 保持屏幕常亮
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // 2. 强力加固沉浸式全屏
        applyImmersiveKiosk()

        // 3. 尝试启动系统级屏幕专机固定 (Lock Task)
        try {
            startLockTask()
        } catch (_: Exception) {}
    }

    override fun onResume() {
        super.onResume()
        isAuthorizedExit = false
        isNavigatingToSettings = false
        applyImmersiveKiosk()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        applyImmersiveKiosk()
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        applyImmersiveKiosk()
        return super.dispatchTouchEvent(ev)
    }

    /**
     * 强力沉浸式黏性全屏 + 极速 200ms 自动收回监听器
     */
    private fun applyImmersiveKiosk() {
        val flags = (View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN)

        window.decorView.systemUiVisibility = flags

        // 监听系统栏可见性：如果用户上滑唤出虚拟按键，200ms 极速自动强行收回隐藏！
        window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
            if (visibility and View.SYSTEM_UI_FLAG_FULLSCREEN == 0) {
                handler.removeCallbacksAndMessages(null)
                handler.postDelayed({
                    window.decorView.systemUiVisibility = flags
                }, 200)
            }
        }
    }

    /**
     * 防逃逸拦截 1：用户尝试点击 Home 键或多任务键切出
     */
    override fun onUserLeaveHint() {
        if (!isAuthorizedExit && !isNavigatingToSettings) {
            reassertTerminalForeground()
        }
        super.onUserLeaveHint()
    }

    /**
     * 防逃逸拦截 2：Activity 一旦进入 onStop (被切入后台)，立即通过 Task 栈瞬间拉回前台！
     */
    override fun onStop() {
        super.onStop()
        if (!isAuthorizedExit && !isNavigatingToSettings) {
            handler.postDelayed({
                if (!isAuthorizedExit && !isNavigatingToSettings) {
                    reassertTerminalForeground()
                }
            }, 100)
        }
    }

    /**
     * 强行拉回前台核心实现：优先采用 Android 原生 moveToFront，兜底采用 Intent REORDER_TO_FRONT
     */
    private fun reassertTerminalForeground() {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val appTasks = am.appTasks
            if (appTasks.isNotEmpty()) {
                appTasks[0].moveToFront()
                return
            }
        } catch (_: Exception) {}

        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLockTask" -> {
                    try {
                        startLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_FAILED", e.message, null)
                    }
                }
                "stopLockTask" -> {
                    try {
                        stopLockTask()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNLOCK_FAILED", e.message, null)
                    }
                }
                "openHomeSettings" -> {
                    // 打开系统默认桌面设置，引导用户将智慧家庭终端设为默认桌面
                    isNavigatingToSettings = true
                    try {
                        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            isNavigatingToSettings = false
                            result.error("SETTINGS_FAILED", e2.message, null)
                        }
                    }
                }
                "exitTerminal" -> {
                    // 唯一合法退出通道
                    isAuthorizedExit = true
                    try {
                        stopLockTask()
                    } catch (_: Exception) {}
                    finishAffinity()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // 彻底消费返回按键，禁止退出应用
        methodChannel?.invokeMethod("onBackPressedAttempt", null)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                methodChannel?.invokeMethod("onPhysicalKey", "VOLUME_UP")
                return true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                methodChannel?.invokeMethod("onPhysicalKey", "VOLUME_DOWN")
                return true
            }
            KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_HOME, KeyEvent.KEYCODE_APP_SWITCH -> {
                // 彻底消费返回、Home 与多任务键
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
