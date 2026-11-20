package com.hafeza.bouga

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import java.io.File
import java.util.Calendar

/** One quiet local digest per day, each genuinely unopened link notified once. */
class BougaReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_TIMEZONE_CHANGED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            schedule(context)
            return
        }
        val pending = goAsync()
        Thread {
            try { deliver(context) } catch (_: Exception) { /* Retry on next daily check; never change user data. */ }
            finally { pending.finish() }
        }.start()
    }
    companion object {
        private const val CHANNEL = "bouga_unopened"
        private const val ID = 3010
        fun prefs(c: Context) = c.getSharedPreferences("bouga_reminders", Context.MODE_PRIVATE)
        fun allowed(c: Context): Boolean {
            if (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
            val manager = c.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return false
            if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
            return true
        }
        fun ensureChannel(c: Context) {
            if (Build.VERSION.SDK_INT >= 26) c.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "روابط لسه ما اتفتحتش", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "تذكير مجمّع هادي بالروابط المحفوظة، مرة واحدة لكل رابط"
                    setSound(null, null)
                    enableVibration(false)
                })
        }
        private fun alarmIntent(c: Context) = PendingIntent.getBroadcast(c, ID, Intent(c, BougaReminderReceiver::class.java).setAction("com.hafeza.bouga.REMIND"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        fun schedule(c: Context) {
            val alarms = c.getSystemService(AlarmManager::class.java)
            alarms.cancel(alarmIntent(c))
            val p = prefs(c)
            if (!p.getBoolean("enabled", false) || !allowed(c)) return
            val next = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 10); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
            if (next.timeInMillis <= System.currentTimeMillis()) next.add(Calendar.DAY_OF_YEAR, 1)
            // Inexact, non-wakeup alarm: no exact-alarm access, no wakelock, Android may delay.
            alarms.setInexactRepeating(AlarmManager.RTC, next.timeInMillis, AlarmManager.INTERVAL_DAY, alarmIntent(c))
        }
        private fun deliver(c: Context) {
            val p = prefs(c)
            if (!p.getBoolean("enabled", false) || !allowed(c)) return
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            if (hour < 9 || hour >= 21) return
            val now = System.currentTimeMillis()
            if (now - p.getLong("lastDigest", 0) < 20 * 60 * 60 * 1000L) return
            val days = p.getInt("days", 3).coerceIn(1, 30)
            val file = File(c.applicationInfo.dataDir, "app_flutter/bouga.db")
            if (!file.isFile) return
            val notified = (p.getStringSet("notified", emptySet()) ?: emptySet()).toMutableSet()
            val ids = mutableListOf<String>()
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT id FROM links WHERE open_state = 'unopened' AND last_seen > 0 AND last_seen <= ? ORDER BY last_seen ASC", arrayOf((now - days * 86400000L).toString())).use { rows ->
                    while (rows.moveToNext()) { val id = rows.getString(0); if (!notified.contains(id)) ids.add(id) }
                }
            }
            if (ids.isEmpty()) return
            ensureChannel(c)
            val open = PendingIntent.getActivity(c, ID, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL) else @Suppress("DEPRECATION") Notification.Builder(c)
            val notification = builder.setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle("في بُؤجة حاجات مستنياك")
                .setContentText("عندك ${ids.size} رابط عدى عليه $days أيام ولسه ما اتفتحش")
                .setContentIntent(open).setAutoCancel(true).setOnlyAlertOnce(true).build()
            // Check again immediately before posting. Disabling cancels the current digest as well.
            if (!prefs(c).getBoolean("enabled", false) || !allowed(c)) return
            c.getSystemService(NotificationManager::class.java).notify(ID, notification)
            notified.addAll(ids)
            p.edit().putStringSet("notified", notified).putLong("lastDigest", now).apply()
        }
        fun disable(c: Context) {
            prefs(c).edit().putBoolean("enabled", false).apply()
            c.getSystemService(AlarmManager::class.java).cancel(alarmIntent(c))
            c.getSystemService(NotificationManager::class.java).cancel(ID)
        }
    }
}
