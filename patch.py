import re
import xml.etree.ElementTree as ET
from pathlib import Path
import cairosvg

ROOT = Path(".")
SVG_PATH = ROOT / "www/assets/bouga-icon.svg"
RES = ROOT / "android/app/src/main/res"
svg_bytes = SVG_PATH.read_bytes()

# Legacy launchers: rasterize the COMPLETE approved SVG, including its
# gradient background, circular detail, stick, bundle, folds and knot.
for density, size in {"mdpi":48, "hdpi":72, "xhdpi":96, "xxhdpi":144, "xxxhdpi":192}.items():
    folder = RES / f"mipmap-{density}"
    folder.mkdir(parents=True, exist_ok=True)
    png = cairosvg.svg2png(bytestring=svg_bytes, output_width=size, output_height=size)
    (folder / "bouga_launcher.png").write_bytes(png)
    (folder / "bouga_launcher_round.png").write_bytes(png)

# Adaptive foreground: retain EVERY original SVG element. Scale the complete
# artwork uniformly into Android's central safe area; do not crop/extract paths.
source = ET.fromstring(svg_bytes)
tag = "{http://www.w3.org/2000/svg}"
foreground = ET.Element(tag + "svg", {"xmlns":"http://www.w3.org/2000/svg", "viewBox":"0 0 512 512"})
defs = source.find(tag + "defs")
if defs is not None:
    foreground.append(ET.fromstring(ET.tostring(defs)))
group = ET.SubElement(foreground, tag + "g", {"transform":"translate(85.333 85.333) scale(0.666667)"})
for child in list(source):
    if child.tag != tag + "defs":
        group.append(ET.fromstring(ET.tostring(child)))
foreground_png = cairosvg.svg2png(bytestring=ET.tostring(foreground, encoding="utf-8"), output_width=432, output_height=432)
# Use a uniquely named drawable-nodpi resource so Capacitor's generated
# drawable-anydpi-v24/ic_launcher_foreground.xml cannot win resource lookup.
fg_dir = RES / "drawable-nodpi"
fg_dir.mkdir(parents=True, exist_ok=True)
(fg_dir / "bouga_launcher_foreground.png").write_bytes(foreground_png)

# Remove old app-local launcher assets from previous iterations. The
# application manifest below points only to uniquely named BOUGA resources.
for density in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
    folder = RES / f"mipmap-{density}"
    for stale_name in ("ic_launcher.png", "ic_launcher_round.png"):
        stale = folder / stale_name
        if stale.exists():
            stale.unlink()

adaptive_dir = RES / "mipmap-anydpi-v26"
adaptive_dir.mkdir(parents=True, exist_ok=True)
adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/bouga_icon_background"/>
    <foreground android:drawable="@drawable/bouga_launcher_foreground"/>
</adaptive-icon>
"""
(adaptive_dir / "bouga_launcher.xml").write_text(adaptive, encoding="utf-8")
(adaptive_dir / "bouga_launcher_round.xml").write_text(adaptive, encoding="utf-8")
values = RES / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "bouga_icon_colors.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources><color name="bouga_icon_background">#061c28</color></resources>
""", encoding="utf-8")

manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")
text = re.sub(r'android:icon="[^"]+"', 'android:icon="@mipmap/bouga_launcher"', text, count=1)
text = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@mipmap/bouga_launcher_round"', text, count=1)
if "android:icon=" not in text:
    text = text.replace("<application", '<application android:icon="@mipmap/bouga_launcher"', 1)
if "android:roundIcon=" not in text:
    text = text.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/bouga_launcher" android:roundIcon="@mipmap/bouga_launcher_round"', 1)
if 'android:name="android.intent.action.SEND"' not in text:
    filt = '<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="text/plain"/></intent-filter>'
    text = text.replace("</activity>", filt + "</activity>", 1)
if "android:launchMode=" not in text:
    text = text.replace("<activity", '<activity android:launchMode="singleTask"', 1)
manifest.write_text(text, encoding="utf-8")

java_dir = ROOT / "android/app/src/main/java/com/hafeza/links"
java_dir.mkdir(parents=True, exist_ok=True)
(java_dir / "MainActivity.java").write_text('''package com.hafeza.links;
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
''', encoding="utf-8")
