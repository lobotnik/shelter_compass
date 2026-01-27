import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/shelter.dart';

class ShelterService {
  static const String _baseUrl = 'https://services6.arcgis.com/NThLsKaeOKhGxBBE/arcgis/rest/services/Skyddsrum_220225/FeatureServer/0/query';

  Future<List<Shelter>> fetchNearbyShelters(double lat, double lon, {double radiusInMeters = 5000}) async {
    final queryParams = {
      'where': '1=1',
      'geometry': '$lon,$lat',
      'geometryType': 'esriGeometryPoint',
      'spatialRel': 'esriSpatialRelIntersects',
      'distance': radiusInMeters.toString(),
      'units': 'esriSRUnit_Meter',
      'outFields': 'Skyddsrumsnr,Gatuadress,AntalPlatser',
      'outSR': '4326',
      'f': 'geojson',
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        return features.map((f) => Shelter.fromJson(f)).toList();
      } else {
        throw Exception('Failed to load shelters: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching shelters: $e');
      return [];
    }
  }
}
