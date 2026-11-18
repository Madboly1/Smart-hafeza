import os
import re
import shutil

# Apply BOUGA launcher icon to the freshly generated Capacitor Android project.
manifest = 'android/app/src/main/AndroidManifest.xml'
with open(manifest, encoding='utf-8') as f:
    s = f.read()
filt = '<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="text/plain"/></intent-filter>'
s = s.replace('</activity>', filt + '</activity>', 1)
if 'launchMode' not in s:
    s = s.replace('<activity', '<activity android:launchMode="singleTask"', 1)
s = re.sub(r'android:icon="[^"]+"', 'android:icon="@drawable/bouga_icon"', s, count=1)
s = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@drawable/bouga_icon"', s, count=1)
if 'android:icon=' not in s:
    s = s.replace('<application', '<application android:icon="@drawable/bouga_icon"', 1)
open(manifest, 'w', encoding='utf-8').write(s)

# Copy the branded icon into Android resources.
os.makedirs('android/app/src/main/res/drawable', exist_ok=True)
shutil.copyfile('resources/bouga_icon.xml', 'android/app/src/main/res/drawable/bouga_icon.xml')

# Keep the existing share-intent integration intact.
d = 'android/app/src/main/java/com/hafeza/links'
os.makedirs(d, exist_ok=True)
with open(d + '/MainActivity.java', 'w', encoding='utf-8') as f:
    f.write('''package com.hafeza.links;\nimport android.content.Intent;\nimport com.getcapacitor.BridgeActivity;\npublic class MainActivity extends BridgeActivity {\n  @Override protected void onNewIntent(Intent intent){\n    super.onNewIntent(intent);\n    String a=intent.getAction(); String t=intent.getType();\n    if(Intent.ACTION_SEND.equals(a) && t!=null){\n      bridge.getActivity().setIntent(intent);\n      bridge.eval("window.dispatchEvent(new Event('sendIntentReceived'))", v->{});\n    }\n  }\n}\n''')
