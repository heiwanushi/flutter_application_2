package com.example.flutter_application_2

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.service.quicksettings.TileService
import android.os.Build

class NewNoteTileService : TileService() {
    override fun onClick() {
        // Prepare intent
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("notesapp://new")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        // Handle locked screen state for better UX and stability
        if (isLocked) {
            unlockAndRun {
                executeStart(intent)
            }
        } else {
            executeStart(intent)
        }
    }

    private fun executeStart(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ (API 34) requires PendingIntent for background activity starts
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            // Older versions use Intent directly
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
