"""Read-only fixture tests for generated adapter and eligibility. No phone data."""
import re
import sqlite3
import tempfile
import subprocess
import sys
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parent.parent
class ReminderTests(unittest.TestCase):
    def test_real_native_query_preserves_unknown_and_opened(self):
        source = (ROOT / 'tool/BougaReminderReceiver.kt').read_text()
        query = re.search(r'db.rawQuery\("([^"]+)"', source).group(1)
        db = sqlite3.connect(':memory:')
        db.execute('CREATE TABLE links(id TEXT, open_state TEXT, last_seen INTEGER)')
        db.executemany('INSERT INTO links VALUES (?,?,?)', [('old','unopened',10),('recent','unopened',90),('unknown','unknown',1),('opened','opened',1),('undated','unopened',0)])
        self.assertEqual(db.execute(query, [50]).fetchall(), [('old',)])
        db.execute("UPDATE links SET open_state='opened' WHERE id='old'")
        self.assertEqual(db.execute(query, [50]).fetchall(), [])
    def test_adapter_manifest_and_existing_channels_survive(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            p = root/'android/app/src/main/kotlin/com/hafeza/bouga';p.mkdir(parents=True)
            (p/'MainActivity.kt').write_text('placeholder')
            manifest = root/'android/app/src/main/AndroidManifest.xml'
            manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application><activity android:name=".MainActivity" android:exported="true"/></application></manifest>')
            (root/'tool').mkdir()
            for name in ['configure_incoming_share.py','configure_reminders.py','BougaReminderReceiver.kt']:
                (root/'tool'/name).write_bytes((ROOT/'tool'/name).read_bytes())
            subprocess.run([sys.executable,'tool/configure_incoming_share.py'],cwd=root,check=True)
            subprocess.run([sys.executable,'tool/configure_reminders.py'],cwd=root,check=True)
            source=(p/'MainActivity.kt').read_text()
            for channel in ['bouga/updates','bouga/incoming_share','bouga/reminders']:
                self.assertIn(channel,source)
            self.assertIn('onRequestPermissionsResult',source)
            tree=ET.parse(manifest);a='{http://schemas.android.com/apk/res/android}'
            permissions=[v.get(a+'name') for v in tree.findall('uses-permission')]
            self.assertIn('android.permission.POST_NOTIFICATIONS',permissions)
            self.assertNotIn('android.permission.SCHEDULE_EXACT_ALARM',permissions)
            self.assertNotIn('android.permission.READ_EXTERNAL_STORAGE',permissions)
            receiver=tree.find('.//receiver');self.assertEqual(receiver.get(a+'exported'),'false')
            self.assertEqual((p/'BougaReminderReceiver.kt').read_bytes(),(ROOT/'tool/BougaReminderReceiver.kt').read_bytes())
if __name__ == '__main__': unittest.main()
