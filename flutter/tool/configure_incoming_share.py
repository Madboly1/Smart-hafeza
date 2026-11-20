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
application = tree.find('application')
assert application is not None
ET.SubElement(tree.getroot(), 'uses-permission', {f'{{{ANDROID}}}name': 'android.permission.INTERNET'})
ET.SubElement(tree.getroot(), 'uses-permission', {f'{{{ANDROID}}}name': 'android.permission.REQUEST_INSTALL_PACKAGES'})
provider = ET.SubElement(application, 'provider', {
    f'{{{ANDROID}}}name': 'androidx.core.content.FileProvider',
    f'{{{ANDROID}}}authorities': '${applicationId}.bouga.updates',
    f'{{{ANDROID}}}exported': 'false',
    f'{{{ANDROID}}}grantUriPermissions': 'true',
})
ET.SubElement(provider, 'meta-data', {
    f'{{{ANDROID}}}name': 'android.support.FILE_PROVIDER_PATHS',
    f'{{{ANDROID}}}resource': '@xml/bouga_update_paths',
})
paths = Path('android/app/src/main/res/xml/bouga_update_paths.xml')
paths.parent.mkdir(parents=True, exist_ok=True)
paths.write_text('<paths><cache-path name="bouga_updates" path="bouga_updates/"/></paths>')
ET.indent(tree, space='    ')
tree.write(manifest, encoding='utf-8', xml_declaration=True)

activity_file = Path('android/app/src/main/kotlin/com/hafeza/bouga/MainActivity.kt')
assert activity_file.is_file()
activity_file.write_text('''package com.hafeza.bouga

import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bouga/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installed" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf("versionCode" to code, "abi" to android.os.Build.SUPPORTED_ABIS.first()))
                    }
                    "install" -> {
                        try {
                            val file = File(call.argument<String>("path") ?: "").canonicalFile
                            val allowed = File(cacheDir, "bouga_updates").canonicalFile
                            require(file.parentFile == allowed && file.extension == "apk" && file.isFile)
                            val uri = FileProvider.getUriForFile(this, "$packageName.bouga.updates", file)
                            val install = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            startActivity(install)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("INSTALL_FAILED", "Android could not open the package installer", null)
                        }
                    }
                    else -> result.notImplemented()
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
