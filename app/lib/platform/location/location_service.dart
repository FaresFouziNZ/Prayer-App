import 'package:geocoding/geocoding.dart' as geocoding;
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
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// The city (falling back to the administrative area) nearest a fix, or
  /// null if reverse geocoding is unsupported or finds nothing — callers
  /// fall back to showing raw coordinates in that case.
  Future<String?> resolveCityName(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.Geocoding().placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isEmpty) return null;
      final place = placemarks.first;
      final city = place.locality?.trim();
      if (city != null && city.isNotEmpty) return city;
      final area = place.administrativeArea?.trim();
      if (area != null && area.isNotEmpty) return area;
      return null;
    } catch (_) {
      return null;
    }
  }
}
