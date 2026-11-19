/// Contract shared by the Capacitor export button and Flutter importer.
///
/// Export envelope:
/// {
///   "schemaVersion": 1,
///   "source": "bouga-capacitor-hl",
///   "exportedAt": "...",
///   "data": {"links": [...], "cats": [...]}
/// }
///
/// The Capacitor app keeps the original localStorage key `hl` unchanged.
/// Users can export a JSON backup from the header control. Flutter accepts
/// either this envelope or the raw legacy `hl` object.
abstract final class LegacyBackupContract {
  static const schemaVersion = 1;
  static const source = 'bouga-capacitor-hl';
}
