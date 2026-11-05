import os
p='android/app/src/main/AndroidManifest.xml'
s=open(p,encoding='utf-8').read()
f='<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="text/plain"/></intent-filter>'
s=s.replace('</activity>',f+'</activity>',1)
if 'launchMode' not in s: s=s.replace('<activity','<activity android:launchMode="singleTask"',1)
open(p,'w',encoding='utf-8').write(s)
d='android/app/src/main/java/com/hafeza/links'
os.makedirs(d,exist_ok=True)
open(d+'/MainActivity.java','w').write('''package com.hafeza.links;
import android.content.Intent;
import com.getcapacitor.BridgeActivity;
public class MainActivity extends BridgeActivity {
  @Override protected void onNewIntent(Intent intent){
    super.onNewIntent(intent);
    String a=intent.getAction(); String t=intent.getType();
    if(Intent.ACTION_SEND.equals(a) && t!=null){
      bridge.getActivity().setIntent(intent);
      bridge.eval("window.dispatchEvent(new Event('sendIntentReceived'))", v->{});
    }
  }
}
''')
