package com.rydex.rider.rydex_rider

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.ImageView
import kotlin.math.abs

/**
 * The optional floating Mangaale Rider bubble.
 *
 * Opt-in only: it is shown when the rider has enabled it in Settings, granted
 * "Display over other apps", is Online, and the app is not on screen. The
 * Flutter side decides when (background_mode_policy.dart shouldShowBubble);
 * this class only draws it. It is a shortcut back into the app and keeps
 * nothing alive — the Online foreground service does that.
 *
 * Overlay windows are not drawn over the lock screen, and Android hides them
 * over system permission dialogs; the app additionally never shows the bubble
 * while it is merely "inactive" (a dialog or the notification shade).
 */
object RiderBubble {
    private var bubble: ImageView? = null

    fun canDrawOverlays(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    @SuppressLint("ClickableViewAccessibility")
    fun show(context: Context) {
        if (bubble != null || !canDrawOverlays(context)) return

        val appContext = context.applicationContext
        val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val density = appContext.resources.displayMetrics.density
        val size = (56 * density).toInt()

        val params = WindowManager.LayoutParams(
            size,
            size,
            overlayWindowType(),
            // Not focusable: touches outside the bubble go to the app below.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = (160 * density).toInt()
        }

        val view = ImageView(appContext).apply {
            setImageResource(R.mipmap.ic_launcher)
            contentDescription = "Open Mangaale Rider"
        }

        val touchSlop = ViewConfiguration.get(appContext).scaledTouchSlop
        var downRawX = 0f
        var downRawY = 0f
        var startX = 0
        var startY = 0
        var dragged = false

        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downRawX = event.rawX
                    downRawY = event.rawY
                    startX = params.x
                    startY = params.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - downRawX
                    val dy = event.rawY - downRawY
                    if (abs(dx) > touchSlop || abs(dy) > touchSlop) {
                        dragged = true
                    }
                    if (dragged) {
                        params.x = startX + dx.toInt()
                        params.y = startY + dy.toInt()
                        try {
                            windowManager.updateViewLayout(view, params)
                        } catch (ignored: IllegalArgumentException) {
                            // Removed while dragging.
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragged) {
                        openApp(appContext)
                    }
                    true
                }
                else -> false
            }
        }

        try {
            windowManager.addView(view, params)
            bubble = view
        } catch (ignored: RuntimeException) {
            // Permission revoked between the check and the add. The bubble is
            // optional; carry on without it.
            bubble = null
        }
    }

    fun hide() {
        val view = bubble ?: return
        bubble = null
        val windowManager = view.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            windowManager.removeView(view)
        } catch (ignored: IllegalArgumentException) {
            // Already removed, e.g. the permission was revoked.
        }
    }

    private fun openApp(context: Context) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        context.startActivity(intent)
    }

    @Suppress("DEPRECATION")
    private fun overlayWindowType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
}
