/// A place picked from the geocoding search — Hinge-style manual location,
/// not device GPS. `displayName` is what gets shown/stored (e.g. "Málaga,
/// España"); `latitude`/`longitude` are what the backend uses to compute
/// distance in /discover.
class LocationResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}
