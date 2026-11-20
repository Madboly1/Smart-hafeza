"""Add local Android reminders after configure_incoming_share.py, no external services."""
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET
A = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', A)
manifest = Path('android/app/src/main/AndroidManifest.xml')
tree = ET.parse(manifest)
for permission in ['android.permission.POST_NOTIFICATIONS', 'android.permission.RECEIVE_BOOT_COMPLETED']:
    ET.SubElement(tree.getroot(), 'uses-permission', {f'{{{A}}}name': permission})
app = tree.find('application')
receiver = ET.SubElement(app, 'receiver', {f'{{{A}}}name': '.BougaReminderReceiver', f'{{{A}}}exported': 'false'})
f = ET.SubElement(receiver, 'intent-filter')
for action in ['android.intent.action.BOOT_COMPLETED', 'android.intent.action.TIMEZONE_CHANGED', 'android.intent.action.MY_PACKAGE_REPLACED']:
    ET.SubElement(f, 'action', {f'{{{A}}}name': action})
ET.indent(tree, space='    ')
tree.write(manifest, encoding='utf-8', xml_declaration=True)
root = Path('android/app/src/main/kotlin/com/hafeza/bouga')
shutil.copyfile('tool/BougaReminderReceiver.kt', root / 'BougaReminderReceiver.kt')
p = root / 'MainActivity.kt'
s = p.read_text()
s = s.replace('    private val pending =', '''    private var reminderResult: MethodChannel.Result? = null
    private fun reminderState(): Map<String, Any> {
        val p = BougaReminderReceiver.prefs(this)
        return mapOf("enabled" to (p.getBoolean("enabled", false) && BougaReminderReceiver.allowed(this)), "days" to p.getInt("days", 3), "permission" to BougaReminderReceiver.allowed(this))
    }
    private fun enableReminders(result: MethodChannel.Result) {
        BougaReminderReceiver.ensureChannel(this)
        if (android.os.Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            if (reminderResult != null) { result.error("BUSY", "Permission request in progress", null); return }
            reminderResult = result
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 3010)
        } else {
            val allowed = BougaReminderReceiver.allowed(this)
            BougaReminderReceiver.prefs(this).edit().putBoolean("enabled", allowed).apply()
            BougaReminderReceiver.schedule(this)
            result.success(reminderState())
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 3010) {
            val allowed = BougaReminderReceiver.allowed(this)
            BougaReminderReceiver.prefs(this).edit().putBoolean("enabled", allowed).apply()
            BougaReminderReceiver.schedule(this)
            reminderResult?.success(reminderState())
            reminderResult = null
        }
    }
    private val pending =''')
needle = '        captureShare(intent)\n    }'
assert s.count(needle) == 2
# Only configure engine, not the separate incoming intent handler.
s = s.replace(needle, '''        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bouga/reminders").setMethodCallHandler { call, result ->
            val p = BougaReminderReceiver.prefs(this)
            when (call.method) {
                "state" -> result.success(reminderState())
                "initialize" -> {
                    if (!p.getBoolean("initialized", false)) {
                        p.edit().putBoolean("initialized", true).apply()
                        enableReminders(result)
                    } else { BougaReminderReceiver.schedule(this); result.success(reminderState()) }
                }
                "set" -> {
                    val days = call.argument<Int>("days")
                    if (days == null || days !in listOf(1,2,3,7,14,30)) { result.error("INVALID", "Invalid reminder days", null) }
                    else {
                        p.edit().putInt("days", days).putBoolean("initialized", true).apply()
                        if (call.argument<Boolean>("enabled") == true) enableReminders(result)
                        else { BougaReminderReceiver.disable(this); result.success(reminderState()) }
                    }
                }
                else -> result.notImplemented()
            }
        }
        captureShare(intent)
    }''', 1)
p.write_text(s)
print('Configured local grouped unopened reminders and ordinary notification permission.')
