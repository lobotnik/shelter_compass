/// Represents a Civil Defense Shelter (Skyddsrum).
///
/// Contains location data, capacity, and address information
/// parsed from the MSB Open Data API.
class Shelter {
  /// Unique identifier for the shelter
  final String id;

  /// Latitude in decimal degrees
  final double latitude;

  /// Longitude in decimal degrees
  final double longitude;

  /// Street address of the shelter
  final String address;

  /// City/Municipality
  final String city;

  /// Number of people the shelter can accommodate
  final int capacity;

  /// Status of the shelter (3 = Active, 7 = Other)
  final int statusId;

  Shelter({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.capacity,
    required this.statusId,
  });

  /// Factory method to create a Shelter from a JSON object.
  /// Used when parsing API responses.
  factory Shelter.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    final geom = json['geometry']['coordinates'];
    return Shelter(
      id: props['Skyddsrumsnr'] ?? '',
      address: props['Gatuadress'] ?? 'Unknown',
      capacity: props['AntalPlatser'] ?? 0,
      city: props['Kommun'] ?? '',
      statusId: props['StatusID'] ?? 0,
      latitude: geom[1].toDouble(),
      longitude: geom[0].toDouble(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'properties': {
        'Skyddsrumsnr': id,
        'Gatuadress': address,
        'AntalPlatser': capacity,
        'StatusID': statusId,
      },
      'geometry': {
        'coordinates': [longitude, latitude],
      },
    };
  }
}
