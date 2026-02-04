import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shelter.dart';

class ShelterService {
  static const String _baseUrl =
      'https://services6.arcgis.com/NThLsKaeOKhGxBBE/arcgis/rest/services/Skyddsrum_220225/FeatureServer/0/query';

  Future<List<Shelter>> fetchNearbyShelters(
    double lat,
    double lon, {
    double radiusInMeters = 5000,
  }) async {
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
        final shelters = features.map((f) => Shelter.fromJson(f)).toList();

        // Cache the successful result
        await _cacheShelters(shelters);

        return shelters;
      } else {
        throw Exception('Failed to load shelters: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching shelters: $e');
      // On error, try to load from cache
      return await _loadCachedShelters();
    }
  }

  Future<void> _cacheShelters(List<Shelter> shelters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        shelters.map((s) => s.toJson()).toList(),
      );
      await prefs.setString('cached_shelters', encoded);
    } catch (e) {
      print('Error caching shelters: $e');
    }
  }

  Future<List<Shelter>> _loadCachedShelters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encoded = prefs.getString('cached_shelters');

      if (encoded != null) {
        final List<dynamic> decoded = json.decode(encoded);
        return decoded.map((item) => Shelter.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error loading cached shelters: $e');
    }
    return [];
  }
}
