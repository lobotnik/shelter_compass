import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/shelter.dart';
import 'services/shelter_service.dart';
import 'logic/compass_logic.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ShelterCompassApp());
}

class ShelterCompassApp extends StatelessWidget {
  const ShelterCompassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelter Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const ShelterCompassScreen(),
    );
  }
}

class ShelterCompassScreen extends StatefulWidget {
  const ShelterCompassScreen({super.key});

  @override
  State<ShelterCompassScreen> createState() => _ShelterCompassScreenState();
}

class _ShelterCompassScreenState extends State<ShelterCompassScreen> {
  final ShelterService _shelterService = ShelterService();
  final CompassLogic _logic = CompassLogic();

  Position? _currentPosition;
  List<Shelter> _shelters = [];
  Shelter? _nearestShelter;
  bool _isManualSelection = false;
  double _compassOffset = 0.0;
  bool _showMap = false;

  // Settings
  double _searchRadiusKm = 5.0;
  int _resultCap = 25;

  void _toggleMap() {
    setState(() {
      _showMap = !_showMap;
    });
  }

  double _smoothHeading = 0.0;
  final double _filterFactor = 0.15;

  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final status = await Permission.location.request();
    if (status.isDenied) {
      setState(() {
        _error = 'Location permission denied';
        _isLoading = false;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      await _refreshShelters();

      FlutterCompass.events?.listen((event) {
        if (!mounted || event.heading == null) return;

        double rawHeading = event.heading!;
        if (_currentPosition != null && _currentPosition!.speed > 1.0) {
          rawHeading = _currentPosition!.heading;
        }

        double diff = (rawHeading - _smoothHeading);
        while (diff < -180) diff += 360;
        while (diff > 180) diff -= 360;

        setState(() {
          _smoothHeading += diff * _filterFactor;
        });
      });

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            if (_shelters.isNotEmpty && !_isManualSelection) {
              _nearestShelter = _logic.findNearestShelter(
                pos.latitude,
                pos.longitude,
                _shelters,
              );
            }
          });
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshShelters() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);
    try {
      var shelters = await _shelterService.fetchNearbyShelters(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radiusInMeters: _searchRadiusKm * 1000,
      );

      // Sort by distance
      shelters.sort((a, b) {
        final distA = _logic.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a,
        );
        final distB = _logic.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b,
        );
        return distA.compareTo(distB);
      });

      // Cap results
      if (shelters.length > _resultCap) {
        shelters = shelters.take(_resultCap).toList();
      }

      setState(() {
        _shelters = shelters;
        _nearestShelter = shelters.isNotEmpty ? shelters.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch shelters';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          currentRadius: _searchRadiusKm,
          currentCap: _resultCap,
          currentPosition: _currentPosition,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _searchRadiusKm = result['radius'];
        _resultCap = result['cap'];
      });
      _refreshShelters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : _buildMainUI(),
    );
  }

  Widget _buildMainUI() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeaderActions(),
          if (_shelters.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Text(
                  'Inga skyddsrum hittades i ditt område.',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
                ),
              ),
            )
          else ...[
            // Fixed height or flexible compass section to prevent overlap
            Flexible(flex: 3, child: _buildCompassSection()),
            const SizedBox(height: 20),
            _buildGpsStatus(),
            // Expanded list for better performance and scrolling
            Expanded(flex: 2, child: _buildShelterList()),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: _refreshShelters,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Uppdatera',
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Inställningar',
          ),
        ],
      ),
    );
  }

  Widget _buildCompassSection() {
    if (_showMap) {
      return _buildMapSection();
    }

    if (_nearestShelter == null || _currentPosition == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final double bearing = _logic.calculateBearing(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _nearestShelter!,
    );

    final double distance = _logic.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _nearestShelter!,
    );

    double rotation =
        (bearing - _smoothHeading + _compassOffset) * (math.pi / 180);
    bool isGpsHeading = _currentPosition!.speed > 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate a responsive height for the arrow
          double arrowSize = (constraints.maxHeight * 0.5).clamp(120, 220);

          // Calculate relative direction description
          String directionDescription = '';
          double relativeBearing = bearing - _smoothHeading;
          while (relativeBearing < -180) relativeBearing += 360;
          while (relativeBearing > 180) relativeBearing -= 360;

          if (relativeBearing.abs() < 22.5) {
            directionDescription = 'rakt fram';
          } else if (relativeBearing.abs() > 157.5) {
            directionDescription = 'bakom dig';
          } else if (relativeBearing > 0) {
            if (relativeBearing < 67.5)
              directionDescription = 'snett höger';
            else if (relativeBearing < 112.5)
              directionDescription = 'höger';
            else
              directionDescription = 'snett bakåt höger';
          } else {
            if (relativeBearing > -67.5)
              directionDescription = 'snett vänster';
            else if (relativeBearing > -112.5)
              directionDescription = 'vänster';
            else
              directionDescription = 'snett bakåt vänster';
          }

          return Semantics(
            label:
                'Närmaste skyddsrum ligger ${distance.round()} meter bort, $directionDescription. Adress: ${_nearestShelter!.address}.',
            excludeSemantics: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: rotation,
                  child: Image.asset(
                    isGpsHeading
                        ? 'assets/navigation_arrow_active.png'
                        : 'assets/navigation_arrow.png',
                    height: arrowSize,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.05),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${distance.round()} meter',
                    style: GoogleFonts.outfit(
                      fontSize: 40,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nearestShelter!.address,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Kapacitet: ${_nearestShelter!.capacity} personer',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF9BA1A6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapSection() {
    if (_currentPosition == null || _nearestShelter == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final userPos = latlng.LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
    final targetPos = latlng.LatLng(
      _nearestShelter!.latitude,
      _nearestShelter!.longitude,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        key: ValueKey(_nearestShelter?.id),
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([userPos, targetPos]),
            padding: const EdgeInsets.all(100.0),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.compass',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [userPos, targetPos],
                strokeWidth: 4.0,
                color: Colors.blueAccent,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: userPos,
                width: 40,
                height: 40,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
              ),
              Marker(
                point: targetPos,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsStatus() {
    bool isGpsHeading = (_currentPosition?.speed ?? 0) > 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: FloatingActionButton.small(
                onPressed: _toggleMap,
                backgroundColor: const Color(0xFF2C3036),
                foregroundColor: Colors.white,
                elevation: 0,
                child: Icon(_showMap ? Icons.explore : Icons.map),
                tooltip: _showMap ? 'Visa Kompass' : 'Visa Karta',
              ),
            ),
          ),
          Row(
            children: [
              Text(
                isGpsHeading
                    ? 'GPS position aktiv'
                    : 'GPS startar vid 3,6 km/h',
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Icon(
                isGpsHeading ? Icons.gps_fixed : Icons.gps_not_fixed,
                size: 20,
                color: isGpsHeading ? const Color(0xFF40C4FF) : Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShelterList() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF191C20)),
      child: ListView.separated(
        itemCount: _shelters.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.white.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final shelter = _shelters[index];
          final distance = _logic.calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            shelter,
          );
          final bool isNearest = shelter.id == _nearestShelter?.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 4,
            ),
            leading: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isNearest
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF454B52),
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  isNearest ? Icons.star : Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
            title: Text(
              shelter.address,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              'Kapacitet: ${shelter.capacity} personer',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF9BA1A6),
              ),
            ),
            trailing: Text(
              distance < 1000
                  ? '${distance.round()} m'
                  : '${(distance / 1000).toStringAsFixed(1)} km',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF9BA1A6),
              ),
            ),
            onTap: () {
              setState(() {
                _nearestShelter = shelter;
                _isManualSelection = true;
                _scrollMainToTop();
              });
            },
          );
        },
      ),
    );
  }

  void _scrollMainToTop() {
    // Optional: add a scroll controller to the column if it was scrollable
  }
}
