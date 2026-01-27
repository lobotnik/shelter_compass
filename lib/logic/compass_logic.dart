import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../models/shelter.dart';

class CompassLogic {
  /// Calculates the distance in meters between user and shelter.
  double calculateDistance(double userLat, double userLon, Shelter shelter) {
    return Geolocator.distanceBetween(userLat, userLon, shelter.latitude, shelter.longitude);
  }

  /// Calculates the bearing in degrees (0-360) from user to shelter.
  double calculateBearing(double userLat, double userLon, Shelter shelter) {
    return Geolocator.bearingBetween(userLat, userLon, shelter.latitude, shelter.longitude);
  }

  /// Finds the nearest shelter from a list.
  Shelter? findNearestShelter(double userLat, double userLon, List<Shelter> shelters) {
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
}
