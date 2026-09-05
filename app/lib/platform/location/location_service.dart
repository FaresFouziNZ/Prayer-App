import 'package:geolocator/geolocator.dart';

/// One-shot coarse location fetch (SRS FR-PT-03: "coarse is sufficient").
/// Never polls in the background (NFR-05) — callers fetch on demand, e.g.
/// from a "use current location" button in Settings.
class LocationFix {
  final double latitude;
  final double longitude;

  const LocationFix({required this.latitude, required this.longitude});
}

class LocationServiceDisabledException implements Exception {}

class LocationPermissionDeniedException implements Exception {}

class LocationService {
  Future<LocationFix> getCurrentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    return LocationFix(latitude: position.latitude, longitude: position.longitude);
  }
}
