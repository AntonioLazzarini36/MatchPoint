/// A cluster of nearby tennis courts, treated as one club/facility on the
/// map. OSM barely tags actual "club" facilities in Spain (leisure=
/// sports_centre + sport=tennis returns almost nothing usable), but
/// individual courts (leisure=pitch + sport=tennis) are well mapped and
/// real clubs' courts are physically close together — so `OverpassService`
/// queries individual courts and groups them by proximity into these.
class TennisClub {
  final String id;
  final String name;
  final int courtCount;
  final double latitude;
  final double longitude;

  /// From OSM's `website` tag, if any court in the cluster has one — in
  /// practice almost never present (0/40 checked near Madrid), so this is
  /// an opportunistic extra, not something to rely on. The Google Maps
  /// link built from lat/lng is the reliable one.
  final String? website;

  const TennisClub({
    required this.id,
    required this.name,
    required this.courtCount,
    required this.latitude,
    required this.longitude,
    this.website,
  });
}
