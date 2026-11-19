# BOUGA Flutter Migration Plan

## Goal
Build BOUGA as a cross-platform product with one shared Flutter codebase for Android first, then iOS and Windows.

## Non-negotiable migration rules
- Keep the existing Capacitor application available and working until the Flutter replacement has passed feature and data-migration checks.
- Do not delete, overwrite, or silently reset existing user data.
- The current Android application uses package ID `com.hafeza.links`; preserve this ID for Android upgrade compatibility.
- The current web app stores its data in `localStorage` under the key `hl`. Treat this as a legacy import source and document its schema before implementing migration.
- Preserve existing working behavior; migrate feature-by-feature and verify each stage before moving on.
- Work on this migration branch independently. Do not merge it into the current release branch until explicitly reviewed.

## Proposed technical foundation
- Flutter + Dart
- Material 3 with a custom BOUGA design system (not default-looking Material screens)
- Feature-first structure with clear separation between presentation, application/state, domain, and data layers
- SQLite for durable on-device structured data
- Repository interfaces so local storage can later be combined with cloud synchronization
- Platform adapters for Android, iOS, and Windows capabilities

## Migration sequence
1. **Audit and specification** — inventory current screens, interactions, data fields, URL handling, share intents, reader behavior, update behavior, and edge cases. Record the legacy `hl` schema.
2. **Foundation** — establish Flutter project structure, design tokens, navigation, error handling, and automated checks without changing the existing app.
3. **Data layer** — implement the new local database and a safe, repeatable importer for legacy `hl` data. Validate counts and field-level fidelity; never delete legacy data during import.
4. **Android MVP parity** — rebuild the existing core flows: save link, list, search/filter, categories, details, progress/notes, open link, delete, and supported reader/embed flows.
5. **Update and release infrastructure** — establish signed production builds, versioning, release publication, update metadata, and in-app update UX before public rollout.
6. **Android integration** — share intents, app links, permissions, update checks/download/install flow, and packaging. Keep the existing Android application ID.
7. **Quality gate** — compare old/new behavior, test migration with representative data, and verify clean install, upgrade, update, and rollback/recovery scenarios.
8. **iOS and Windows** — enable and test each target after the shared core is stable; implement each platform's supported distribution/update mechanism.
9. **Synchronization** — design account and cloud sync only after local data ownership, conflict rules, and offline behavior are defined.

## App update system (required product feature)
BOUGA must ship with a real update mechanism, modeled on the user's WAQT update flow—not merely a GitHub Actions APK artifact.

### Android update experience
- The app checks a remotely hosted update manifest (for example, `update.json`) on launch or at a sensible periodic interval, with a manual "Check for updates" action in Settings.
- Manifest fields should include at minimum: `versionCode`, `versionName`, user-facing Arabic release message, APK download URL, and SHA-256 checksum. Include a minimum supported version / mandatory-update flag only when a release genuinely requires it.
- When a newer version is available, show a clear Arabic dialog/card with release notes and explicit **تحديث الآن** and **لاحقًا** actions. Do not silently download or install.
- Download only from the trusted release URL, verify the checksum, show download progress, handle network interruptions, and explain Android's package-installer confirmation step.
- Optional updates remain dismissible. A mandatory update may block use only when the release metadata explicitly marks it mandatory and the reason is justified; never make every update compulsory.
- Publish signed APKs through GitHub Releases using a dedicated production release workflow. The APK must be signed with the same stable signing identity across updates. A matching package ID alone does not make an APK upgrade-compatible.
- Publish/update the manifest automatically from the release workflow with version code/name, Arabic message, APK URL, checksum, and release timestamp. Do not point production users at debug APK artifacts.
- Keep update metadata backward-compatible and fail safely: if the manifest is unreachable or invalid, the installed app continues working and reports that update checking is temporarily unavailable.
- Do not overwrite local user data during an app update.

### Other platforms
- iOS updates must follow Apple's supported App Store/TestFlight distribution and update rules; do not attempt sideloaded APK-style updates on iOS.
- Windows updates should use a supported signed installer/package distribution channel with version checks and an explicit update action.
- Share release notes and version semantics across platforms, while keeping each platform's installation mechanism native and compliant.

### Update acceptance tests
- No update available.
- New optional update available; user can choose update now or later.
- Mandatory update (only when explicitly flagged).
- Manifest unavailable, malformed, or has an invalid version.
- Download interrupted and resumed/retried safely.
- Checksum mismatch prevents installation.
- APK install requires user confirmation and completes as an in-place upgrade.
- Existing BOUGA data survives app update.
- A release with a higher version code is detected; same/lower version is ignored.
- Manual update check works from Settings.

## Current status
- Planning branch created from `feature/bouga-branding`.
- Legacy application and data-contract audit completed in `docs/LEGACY_APP_AUDIT.md`.
- No existing application code or user data format has been changed by this plan.
- Next action: define the Flutter foundation and data migration tests from the audited legacy schema before implementing screens.
