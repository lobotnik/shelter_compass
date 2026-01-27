class Shelter {
  final String id;
  final String address;
  final int capacity;
  final double latitude;
  final double longitude;

  Shelter({
    required this.id,
    required this.address,
    required this.capacity,
    required this.latitude,
    required this.longitude,
  });

  factory Shelter.fromJson(Map<String, dynamic> json) {
    final props = json['properties'];
    final geom = json['geometry']['coordinates'];
    return Shelter(
      id: props['Skyddsrumsnr'] ?? '',
      address: props['Gatuadress'] ?? 'Unknown',
      capacity: props['AntalPlatser'] ?? 0,
      latitude: geom[1].toDouble(),
      longitude: geom[0].toDouble(),
    );
  }
}
