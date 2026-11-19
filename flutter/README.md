# BOUGA Flutter foundation

This directory is the new cross-platform application. The existing Capacitor app at the repository root and in `www/` remains untouched and is still the legacy production source.

## Local development

Install Flutter stable, then:

```sh
cd flutter
flutter pub get
flutter test
flutter analyze
```

Generate native platform folders when ready to build:

```sh
flutter create --platforms=android,windows,web --org com.hafeza --project-name bouga .
```

Android must retain application ID `com.hafeza.links`. Do not ship an Android update until the existing production signing keystore is located and the signing identity is proven to match.

## Legacy data safety

The pure Dart parser reads a JSON export of the old `localStorage.hl` object. It preserves unknown link properties in the field map. The SQLite contract stores those properties in `extra_json`. The import operation must run in a single database transaction and must be idempotent; the old `hl` value must remain untouched until imported counts and fields have been verified.

The legacy Capacitor app currently has no explicit export interface. The next migration step is to add a user-initiated JSON export/bridge to the old app, then connect it to this importer. Do not attempt to read Capacitor WebView localStorage directly from a fresh Flutter install.

## Platform and update notes

The existing package ID is `com.hafeza.links`; signing continuity is not yet established. This foundation intentionally does not create a production signing workflow, APK release, or update manifest until a stable signing key and release channel are confirmed. The update requirements are tracked in `../docs/FLUTTER_MIGRATION.md`.
