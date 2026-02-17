import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/shelter.dart';

/// Handles all geospatial and compass-related calculations.
class CompassLogic {
  /// Calculates the distance in meters between two coordinates.
  /// Uses the Haversine formula via the Geolocator package.
  double calculateDistance(double userLat, double userLon, Shelter shelter) {
    return Geolocator.distanceBetween(
      userLat,
      userLon,
      shelter.latitude,
      shelter.longitude,
    );
  }

  /// Calculates the bearing in degrees (0-360) from user to shelter.
  /// Returns a value between 0° and 360°.
  double calculateBearing(double userLat, double userLon, Shelter shelter) {
    return Geolocator.bearingBetween(
      userLat,
      userLon,
      shelter.latitude,
      shelter.longitude,
    );
  }

  /// Finds the nearest shelter from a list.
  Shelter? findNearestShelter(
    double userLat,
    double userLon,
    List<Shelter> shelters,
  ) {
    if (shelters.isEmpty) return null;

    Shelter nearest = shelters.first;
    double minDistance = calculateDistance(userLat, userLon, nearest);

    for (int i = 1; i < shelters.length; i++) {
      double dist = calculateDistance(userLat, userLon, shelters[i]);
      if (dist < minDistance) {
        minDistance = dist;
        nearest = shelters[i];
      }
    }
    return nearest;
  }

  /// Returns a human-readable direction string based on relative bearing.
  String getDirectionDescription(double relativeBearing) {
    // Normalize relative bearing to -180..180
    double normalized = relativeBearing;
    while (normalized < -180) normalized += 360;
    while (normalized > 180) normalized -= 360;

    if (normalized.abs() < 22.5) {
      return 'rakt fram';
    } else if (normalized.abs() > 157.5) {
      return 'bakom dig';
    } else if (normalized > 0) {
      if (normalized < 67.5) return 'snett höger';
      if (normalized < 112.5) return 'höger';
      return 'snett bakåt höger';
    } else {
      if (normalized > -67.5) return 'snett vänster';
      if (normalized > -112.5) return 'vänster';
      return 'snett bakåt vänster';
    }
  }
}
