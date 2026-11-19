# BOUGA Legacy Application Audit

Audit target: `feature/bouga-branding` at commit `820b0fc1ab2c602f84b45303822ba63628a4e76d`.

## 1. Repository and build layout
- The active web application is `www/index.html`, because `capacitor.config.json` sets `webDir` to `www`.
- The root `index.html` is an older, separate implementation and is not the configured Capacitor web entry point. Do not use it as the migration source of truth.
- Capacitor app ID: `com.hafeza.links`. Preserve this Android application ID when replacing the implementation if in-place Android upgrades are required.
- Capacitor 6 dependencies: core, Android, Browser, and `@supernotes/capacitor-send-intent`.
- CI workflow: `.github/workflows/build.yml`; it generates a fresh Android project, applies `patch.py`, syncs Capacitor, builds a debug APK, and uploads `bouga-apk`.
- The current workflow push trigger includes `main` and `feature/bouga-branding`, not this migration branch. The migration branch currently contains planning documentation only.

## 2. Current feature inventory
### Home and navigation
- Arabic RTL, dark teal visual theme, responsive single-column layout.
- Header/brand, welcome copy, search, three summary counters.
- Quick filters: all, video, article, post.
- Bottom navigation: home, groups, completed.
- Floating add button and empty states.

### Saved items
- Add a URL, validate HTTP/HTTPS, reject duplicate URLs.
- Infer content kind (video/post/article) from URL patterns.
- Attempt to fetch title and Open Graph thumbnail metadata.
- YouTube thumbnail fallback.
- Save selected group, progress, note, and last-seen timestamp.
- Saved-item cards show thumbnail/icon, title, group, type, completion status, and progress.

### Details and reading
- Detail modal with title and URL.
- Embed URL generation for YouTube, TikTok, Instagram, and Facebook.
- Progress slider (0–100 in steps of 5), quick states (0/50/100), note field, group selector.
- Open original URL through Capacitor Browser when available; otherwise window.open.
- Delete with confirmation.
- Basic article extraction attempt using article/body headings and paragraphs.

### Groups and reminders
- Default groups: `مونتاج`, `رياضة`, `أخرى`.
- Create a group through prompt; group selection on add and detail.
- Old-item reminder for unfinished items not revisited for more than seven days.

### Android sharing
- Share-intent package is declared.
- `patch.py` modifies the generated Android manifest and MainActivity to receive ACTION_SEND text/plain and dispatch a JavaScript event.
- The web app then calls the SendIntent plugin to inspect the received share payload.

## 3. Legacy data contract (must preserve)
Storage key: `hl` in browser localStorage.

Top-level structure:
```json
{
  "links": [
    {
      "id": "timestamp-like string",
      "url": "https://...",
      "k": "فيديو | بوست | مقال",
      "c": "group name",
      "title": "display title",
      "img": "thumbnail URL",
      "p": 0,
      "note": "",
      "seen": 0
    }
  ],
  "cats": ["مونتاج", "رياضة", "أخرى"]
}
```

Observed normalization/defaults:
- `links` and `cats` must be arrays or the app resets the in-memory structure to defaults.
- Each link's `p` is coerced to a number (default 0).
- `seen` defaults to the current timestamp.
- `c` defaults to `أخرى`; `title`, `url`, and `note` default to empty strings.
- `أخرى` is always included in categories.
- Existing fields beyond the known fields should be retained during import where possible; the current normalization uses object spread and does not intentionally discard extra link fields.
- IDs are compared as strings in the current active implementation.

Migration requirements:
1. Read the original `hl` value without changing it.
2. Parse and validate defensively; preserve malformed/raw data for recovery instead of overwriting it.
3. Import all links and categories into the new local database in a transaction.
4. Make import idempotent (re-running it must not duplicate items).
5. Verify item counts, IDs, URLs, notes, progress, timestamps, and groups.
6. Only mark migration complete after successful verification. Never clear localStorage as part of migration.

## 4. Risks and defects to account for before feature parity
### High priority
- The active `www/index.html` still builds several inline event handlers by inserting JSON-stringified values into HTML attributes. Some category and reminder handlers, and handlers generated inside the detail modal, can produce invalid/broken attributes when IDs or group names contain quotes or special characters. The saved-card tap handler was changed to event delegation, but this did not eliminate every unsafe inline-handler pattern.
- Metadata extraction and article reading use browser `fetch(url)` against arbitrary third-party sites. Cross-origin restrictions, bot protection, and site policies mean this will fail for many URLs. A reliable cross-platform design needs a controlled metadata/reader service or a clear fallback to opening the original URL.
- Embeds are provider-specific and can be blocked by provider policies, cookies, login requirements, or WebView restrictions. Do not promise universal in-app playback.
- The current UI has no visible backup, export, account, or sync mechanism. Local-only data loss remains a product risk.

### Medium priority
- The category creation flow uses `prompt()`, which is not a polished or consistent mobile/desktop experience.
- Group deletion/rename and link reassignment rules are not implemented.
- Search is a simple substring match over title, URL, and group.
- No explicit sorting options, tags, favorites, archive, or bulk actions were found.
- There is no formal automated test suite visible in the repository.
- The app stores only a single progress percentage and free-text note; no playback-position integration or article reading-position tracking exists.
- The old root `index.html` differs from `www/index.html`; future maintenance should make the active entry point unambiguous and avoid accidentally editing the stale copy.

### Android integration/build concerns
- `patch.py` edits a generated AndroidManifest and writes a Java MainActivity on each CI build. This is fragile compared with a maintained native plugin/custom Capacitor project template; test manifest assumptions against the generated Capacitor version.
- The share filter accepts `text/plain`. Validate real share payloads from browsers and social apps, including text with a URL, URL-only text, multiple URLs, and ACTION_SEND_MULTIPLE if needed.
- The JavaScript event handler calls the plugin's receive-check method. Validate both cold-start sharing and sharing while the app is already open.
- The configured CapacitorHttp option does not itself provide arbitrary website scraping or bypass browser CORS; avoid relying on it as a universal metadata solution.

## 5. Recommended Flutter architecture
- Flutter + Dart, feature-first organization.
- Presentation: screens/widgets and a BOUGA design system.
- Application: state/controllers and use cases.
- Domain: entities and repository contracts.
- Data: SQLite-backed repositories, import/export, and future sync adapters.
- Store saved content and groups locally first; design cloud sync later with explicit conflict rules.
- Keep platform-specific code behind adapters: Android share intents, iOS share extension/deep links, Windows URL launching and file/system integrations.
- Use a stable local database ID strategy while retaining each legacy ID as an import/source identifier to prevent duplicate imports.
- Preserve `com.hafeza.links` for Android if the Flutter app is intended to upgrade the installed Capacitor app. Confirm signing-key continuity separately; matching package ID alone is not sufficient for an in-place update.

## 6. Proposed parity checklist
- [ ] Safe import of existing `hl` data
- [ ] Home, counters, empty states
- [ ] Add URL and duplicate validation
- [ ] Metadata lookup with robust fallback
- [ ] Search and content-type filters
- [ ] Groups: create, select, rename/delete with safe reassignment rules
- [ ] Item detail screen
- [ ] Progress, notes, and last-opened tracking
- [ ] Open external URL
- [ ] Supported embeds with clear fallback
- [ ] Reader mode only where extraction is permitted/reliable
- [ ] Completed view and stale-item reminders
- [ ] Android share receiving (cold start and warm start)
- [ ] Automated data migration and regression tests
- [ ] Android upgrade test using the same application ID and signing identity
- [ ] iOS and Windows platform validation

## 7. Audit conclusion
BOUGA is a compact, local-first link collection app, not yet a large platform. Its core value is saving links, organizing them, finding them again, and tracking progress. Flutter is a reasonable foundation for the stated Android + iOS + Windows roadmap, provided the migration is incremental and data-first.

Do not start by recreating every visual detail. First lock down the data contract and migration tests, then build the local data layer and the core save/list/detail flows. Keep the existing Capacitor app untouched until the Flutter build passes parity and upgrade/data-preservation gates.
