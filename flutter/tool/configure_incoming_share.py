"""Install the Android text-share adapter after flutter create."""
from pathlib import Path
import xml.etree.ElementTree as ET

ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID)
manifest = Path('android/app/src/main/AndroidManifest.xml')
tree = ET.parse(manifest)
activity = tree.find('.//activity')
assert activity is not None
assert activity.get(f'{{{ANDROID}}}name') == '.MainActivity'
assert activity.get(f'{{{ANDROID}}}exported') == 'true'
activity.set(f'{{{ANDROID}}}launchMode', 'singleTask')
intent = ET.SubElement(activity, 'intent-filter')
for tag, name in [('action', 'android.intent.action.SEND'),
                  ('category', 'android.intent.category.DEFAULT')]:
    ET.SubElement(intent, tag, {f'{{{ANDROID}}}name': name})
ET.SubElement(intent, 'data', {f'{{{ANDROID}}}mimeType': 'text/*'})
ET.indent(tree, space='    ')
tree.write(manifest, encoding='utf-8', xml_declaration=True)

activity_file = Path('android/app/src/main/kotlin/com/hafeza/bouga/MainActivity.kt')
assert activity_file.is_file()
activity_file.write_text('''package com.hafeza.bouga

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

class MainActivity : FlutterActivity() {
    private val pending = ArrayDeque<String>()
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bouga/incoming_share")
        shareChannel!!.setMethodCallHandler { call, result ->
            if (call.method == "takePending") {
                val values = pending.toList()
                pending.clear()
                result.success(values)
            } else {
                result.notImplemented()
            }
        }
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShare(intent)
    }

    private fun captureShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val title = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val payload = listOfNotNull(text, title).joinToString("\\n").take(65536)
        if (payload.isNotBlank()) {
            if (pending.size >= 20) pending.removeFirst()
            pending.addLast(payload)
            shareChannel?.invokeMethod("available", null)
        }
        // Consume this launch intent once, so engine recreation does not repeat it.
        intent.action = Intent.ACTION_MAIN
    }
}
''', encoding='utf-8')
assert tree.find('.//data').get(f'{{{ANDROID}}}mimeType') == 'text/*'
print('Configured Android cold/warm text sharing; no storage permission added.')
