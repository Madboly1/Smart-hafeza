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
1. **Audit and specification** — inventory current screens, interactions, data fields, URL handling, share intents, reader behavior, and edge cases. Record the legacy `hl` schema.
2. **Foundation** — establish Flutter project structure, design tokens, navigation, error handling, and automated checks without changing the existing app.
3. **Data layer** — implement the new local database and a safe, repeatable importer for legacy `hl` data. Validate counts and field-level fidelity; never delete legacy data during import.
4. **Android MVP parity** — rebuild the existing core flows: save link, list, search/filter, categories, details, progress/notes, open link, delete, and supported reader/embed flows.
5. **Android integration** — share intents, app links, permissions, and packaging. Keep the existing Android application ID.
6. **Quality gate** — compare old/new behavior, test migration with representative data, and verify clean install plus upgrade scenarios.
7. **iOS and Windows** — enable and test each target after the shared core is stable; add platform-specific UX only where needed.
8. **Synchronization** — design account and cloud sync only after local data ownership, conflict rules, and offline behavior are defined.

## Current status
- Planning branch created from `feature/bouga-branding`.
- No existing application code or user data format has been changed by this plan.
- Next action: complete the legacy app and data-schema audit before scaffolding or replacing screens.
