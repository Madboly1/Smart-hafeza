from pathlib import Path

# GitHub-hosted runners can be throttled by Maven Central (HTTP 429).
# Route every generated Gradle Maven Central repository through Google's
# public Maven Central mirror while retaining the original repositories.
mirror = 'maven { url "https://maven-central.storage-download.googleapis.com/maven2/" }'
android = Path("android")

changed = []
for path in android.rglob("*"):
    if path.is_file() and path.name in {"build.gradle", "settings.gradle", "build.gradle.kts", "settings.gradle.kts"}:
        text = path.read_text(encoding="utf-8")
        updated = text.replace("mavenCentral()", mirror)
        updated = updated.replace("mavenCentral ()", mirror)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed.append(str(path))

if not changed:
    raise SystemExit("No mavenCentral() declarations found in generated Android Gradle files.")

print("Configured Google Maven Central mirror in:")
for name in changed:
    print(f" - {name}")
