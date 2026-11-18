import os
import re
import xml.etree.ElementTree as ET
from pathlib import Path

import cairosvg

ROOT = Path(".")
SVG_PATH = ROOT / "www/assets/bouga-icon.svg"
RES = ROOT / "android/app/src/main/res"

# Generate legacy launcher PNGs directly from the approved brand SVG.
svg_bytes = SVG_PATH.read_bytes()
densities = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
for density, size in densities.items():
    out = RES / f"mipmap-{density}" / "ic_launcher.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=svg_bytes, write_to=str(out), output_width=size, output_height=size)
    (out.parent / "ic_launcher_round.png").write_bytes(out.read_bytes())

# Build a transparent adaptive foreground from the same SVG artwork.
# The 0.84 scale keeps the complete illustration inside Android's safe zone.
tree = ET.parse(SVG_PATH)
source_root = tree.getroot()
ns = "{http://www.w3.org/2000/svg}"
foreground = ET.Element(ns + "svg", {
    "xmlns": "http://www.w3.org/2000/svg",
    "viewBox": "0 0 512 512"
})
defs = source_root.find(ns + "defs")
if defs is not None:
    foreground.append(defs)
group = ET.SubElement(foreground, ns + "g", {"transform": "translate(41 41) scale(0.84)"})
for element in list(source_root):
    if element.tag == ns + "path":
        group.append(element)
foreground_svg = ET.tostring(foreground, encoding="utf-8", xml_declaration=True)
adaptive_dir = RES / "mipmap-xxxhdpi"
adaptive_dir.mkdir(parents=True, exist_ok=True)
cairosvg.svg2png(bytestring=foreground_svg, write_to=str(adaptive_dir / "ic_launcher_foreground.png"),
                 output_width=432, output_height=432)

# Adaptive icon layers (Android 8.0+).
anydpi = RES / "mipmap-anydpi-v26"
anydpi.mkdir(parents=True, exist_ok=True)
adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/bouga_icon_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
(anydpi / "ic_launcher.xml").write_text(adaptive_xml, encoding="utf-8")
(anydpi / "ic_launcher_round.xml").write_text(adaptive_xml, encoding="utf-8")

colors = RES / "values"
colors.mkdir(parents=True, exist_ok=True)
(colors / "bouga_icon_colors.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bouga_icon_background">#07313A</color>
</resources>
""", encoding="utf-8")

# Point the actual Android application at the generated mipmap launcher icons.
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
s = manifest.read_text(encoding="utf-8")
s = re.sub(r'android:icon="[^"]+"', 'android:icon="@mipmap/ic_launcher"', s, count=1)
s = re.sub(r'android:roundIcon="[^"]+"', 'android:roundIcon="@mipmap/ic_launcher_round"', s, count=1)
if 'android:icon=' not in s:
    s = s.replace("<application", '<application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"', 1)
if 'android:roundIcon=' not in s:
    s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"', 1)

# Preserve the existing Android share-intent behavior without duplicating its filter.
if 'android:name="android.intent.action.SEND"' not in s:
    filt = '<intent-filter><action android:name="android.intent.action.SEND"/><category android:name="android.intent.category.DEFAULT"/><data android:mimeType="text/plain"/></intent-filter>'
    s = s.replace("</activity>", filt + "</activity>", 1)
if "android:launchMode=" not in s:
    s = s.replace("<activity", '<activity android:launchMode="singleTask"', 1)
manifest.write_text(s, encoding="utf-8")

# Keep the existing share-intent bridge intact.
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
