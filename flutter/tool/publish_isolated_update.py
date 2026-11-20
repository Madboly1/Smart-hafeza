"""Prepare checked release assets, never include signing material or user data."""
from pathlib import Path
import hashlib,json,os,re,subprocess

root=Path('build/app/outputs/flutter-apk')
tag=f"bouga-isolated-{os.environ['GITHUB_RUN_NUMBER']}"
repo='Madboly1/Smart-hafeza'
sdk=Path(os.environ['ANDROID_HOME'])/'build-tools'
versions=sorted([p for p in sdk.iterdir() if (p/'apksigner').exists()],reverse=True)
assert versions
bin=versions[0]
for abi in ['arm64-v8a','armeabi-v7a','x86_64']:
 apk=root/f'app-{abi}-release.apk'
 signature=subprocess.check_output([str(bin/'apksigner'),'verify','--print-certs',str(apk)],text=True)
 assert '5abedd4dafc3df4a732f97aa27af7aeb6df24c452ac5d2af8b5f4e2b4db97d3d' in signature
 metadata=subprocess.check_output([str(bin/'aapt'),'dump','badging',str(apk)],text=True)
 assert "name='com.hafeza.links.trial'" in metadata
 code=int(re.search(r"versionCode='(\d+)'",metadata)[1])
 offset={"armeabi-v7a":1000,"arm64-v8a":2000,"x86_64":4000}[abi]
 assert code == 3000 + int(os.environ["GITHUB_RUN_NUMBER"]) + offset
 assert code > 3002 + offset
 manifest={
 'versionCode':code,'versionName':f'1.0.{os.environ["GITHUB_RUN_NUMBER"]}',
 'releaseMessage':'مجموعات فارغة تنشئها بنفسك، استقبال المشاركات، عرض مضمّن للمحتوى العام المدعوم، وتحديثات مع التحقق من الملف.',
 'apkUrl':f'https://github.com/{repo}/releases/download/{tag}/{apk.name}',
 'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
 'packageName':'com.hafeza.links.trial','certificateSha256':'5abedd4dafc3df4a732f97aa27af7aeb6df24c452ac5d2af8b5f4e2b4db97d3d',
 }
 (root/f'update-{abi}.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(tag)
