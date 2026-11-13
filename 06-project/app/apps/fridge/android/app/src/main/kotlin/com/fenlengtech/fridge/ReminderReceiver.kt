package com.fenlengtech.fridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val allowed = setOf(LocalReminders.DUE, Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)
        if (intent.action !in allowed) return
        val pending = goAsync()
        LocalReminders.executor.execute {
            try {LocalReminders(context.applicationContext).reconcile(intent.action ?: "alarm")}
            catch (_: Exception) {
                context.getSharedPreferences("local-reminders", Context.MODE_PRIVATE).edit()
                    .putString("lastError", "SCHEDULE_FAILED").apply()
            }
            finally {pending.finish()}
        }
    }
}
