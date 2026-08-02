import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small on/off flags persisted on-device, per install (not synced to the
/// backend — nothing here is sensitive or worth a DB column). Reuses the
/// same secure storage `TokenStorage` already depends on instead of
/// pulling in a new package (shared_preferences) just for this.
class LocalFlags {
  static const _storage = FlutterSecureStorage();
  static const _seenDiscoveryIntroKey = 'seen_discovery_intro';

  /// Whether the user has already dismissed the "what is Discovery for"
  /// explainer — see status.md, "Reposicionamiento de producto" (item 3,
  /// landing softer instead of dumping straight into swipe cards).
  static Future<bool> hasSeenDiscoveryIntro() async {
    return (await _storage.read(key: _seenDiscoveryIntroKey)) == 'true';
  }

  static Future<void> setSeenDiscoveryIntro() async {
    await _storage.write(key: _seenDiscoveryIntroKey, value: 'true');
  }
}
