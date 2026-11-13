package com.fenlengtech.fridge

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import java.util.concurrent.Executors

/** Own local schedules only; no engine, SDK registration or network in receivers. */
internal class LocalReminders(private val context: Context) {
    private val prefs = context.getSharedPreferences("local-reminders", Context.MODE_PRIVATE)
    private val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private fun allowed(): Boolean {
        if (!prefs.getBoolean("allowed", false) || prefs.getString("policyVersion", "") != POLICY) return false
        if (prefs.getString("releaseChannel", "") == "global") return true
        val consent = context.getSharedPreferences("privacy-consent", Context.MODE_PRIVATE)
        return consent.getString("policyVersion", "") == POLICY && consent.getString("releaseChannel", "") == "china" && consent.contains("acceptedAt")
    }
    fun authorizeBusiness(version: String, channel: String) {
        check(prefs.edit().putBoolean("allowed", true).putString("policyVersion", version).putString("releaseChannel", channel).commit())
    }
    fun permission(): Boolean = (Build.VERSION.SDK_INT < 24 || manager.areNotificationsEnabled()) &&
        (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    fun status() = mapOf("enabled" to prefs.getBoolean("enabled", false), "authorized" to permission(), "requested" to prefs.getBoolean("requested", false))
    fun requested() {check(prefs.edit().putBoolean("requested", true).commit())}
    fun enable(value: Boolean) {
        check(allowed()); require(!value || permission())
        check(prefs.edit().putBoolean("enabled", value).commit())
        if (!value) cancel() else reconcile("enable")
    }
    fun sync(cycles: List<ReminderCycle>, copy: ReminderCopy) {
        check(allowed())
        val array = JSONArray(); cycles.forEach { array.put(it.json()) }
        check(prefs.edit().putString("cycles", array.toString()).putString("copy", copy.json().toString()).commit())
        reconcile("sync")
    }
    private fun alarm(): PendingIntent = PendingIntent.getBroadcast(context, 0,
        Intent(context, ReminderReceiver::class.java).setAction(DUE), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun cancel() {
        alarms.cancel(alarm())
        for (day in prefs.getStringSet("postedDays", emptySet())!!.toSet()) manager.cancel(TAG, day.replace("-", "").toInt())
        check(prefs.edit().putStringSet("postedDays", emptySet()).putString("rendered", "{}").commit())
    }
    fun revoke() {
        check(prefs.edit().putBoolean("allowed", false).putBoolean("enabled", false).remove("pendingDay").commit())
        cancel()
    }
    fun pendingDay(day: String) {
        if (day.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))) check(prefs.edit().putString("pendingDay", day).commit())
    }
    fun consumeTap(): String? {
        check(allowed()); val day = prefs.getString("pendingDay", null)
        check(prefs.edit().remove("pendingDay").commit()); return day
    }
    fun reconcile(origin: String) {
        if (!allowed() || !prefs.getBoolean("enabled", false) || !permission()) {cancel(); return}
        val raw = prefs.getString("copy", null) ?: return
        val copy = ReminderCopy.parse(JSONObject(raw))
        val cycles = ReminderCycle.list(JSONArray(prefs.getString("cycles", "[]")))
        val now = System.currentTimeMillis()
        val due = cycles.filter { it.at() <= now }.groupBy { it.day }
        val sent = prefs.getStringSet("sentCycles", emptySet())!!.toMutableSet()
        val posted = prefs.getStringSet("postedDays", emptySet())!!.toMutableSet()
        val rendered = JSONObject(prefs.getString("rendered", "{}"))
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, copy.channel, NotificationManager.IMPORTANCE_DEFAULT))
        for (day in posted.toSet() - due.keys) {
            manager.cancel(TAG, day.replace("-", "").toInt()); posted.remove(day); rendered.remove(day)
        }
        for ((day, items) in due) {
            val fresh = items.any { it.key !in sent }
            // A dismissed or opened card isn't re-created for an already-seen cycle.
            if (!fresh && day !in posted) continue
            if (!fresh && Build.VERSION.SDK_INT >= 23 && manager.activeNotifications.none { it.tag == TAG && it.id == day.replace("-", "").toInt() }) continue
            val signature = copy.json().put("count", items.size).toString()
            if (!fresh && rendered.optString(day) == signature) continue
            sent.addAll(items.map { it.key })
            posted.add(day); rendered.put(day, signature)
            check(prefs.edit().putStringSet("sentCycles", sent.toSet()).putStringSet("postedDays", posted.toSet())
                .putString("rendered", rendered.toString()).putString("lastOrigin", origin).commit())
            post(day, items.size, copy)
        }
        check(prefs.edit().putStringSet("postedDays", posted.toSet()).putString("rendered", rendered.toString()).commit())
        alarms.cancel(alarm())
        cycles.filter { it.key !in sent && it.at() > now }.minOfOrNull { it.at() }?.let {
            if (Build.VERSION.SDK_INT >= 23) alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, it, alarm())
            else alarms.set(AlarmManager.RTC_WAKEUP, it, alarm())
        }
        check(prefs.edit().putString("lastReconcileOrigin", origin).putLong("lastReconcileAt", now)
            .remove("lastError").commit())
    }
    @Suppress("DEPRECATION")
    private fun post(day: String, count: Int, copy: ReminderCopy) {
        val intent = Intent(context, MainActivity::class.java).setAction(OPEN)
            .setData(Uri.parse("fridge://reminder/$day")).putExtra("reminderDay", day)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val tap = PendingIntent.getActivity(context, day.replace("-", "").toInt(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val number = NumberFormat.getIntegerInstance(Locale.forLanguageTag(copy.locale)).format(count)
        manager.notify(TAG, day.replace("-", "").toInt(), builder.setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(copy.title).setContentText(copy.body.replace("{count}", number))
            .setStyle(Notification.BigTextStyle().bigText(copy.body.replace("{count}", number)))
            .setAutoCancel(true).setOnlyAlertOnce(true).setContentIntent(tap).setShowWhen(true).build())
    }
    companion object {
        const val POLICY = "V0.4"
        const val CHANNEL = "fridge-checks"; const val TAG = "fridge-check"
        const val DUE = "com.fenlengtech.fridge.CHECK_DUE"; const val OPEN = "com.fenlengtech.fridge.OPEN_CHECK"
        val executor = Executors.newSingleThreadExecutor()
    }
}
