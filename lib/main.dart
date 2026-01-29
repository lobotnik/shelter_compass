import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/shelter.dart';
import 'services/shelter_service.dart';
import 'logic/compass_logic.dart';

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
        colorSchemeSeed: Colors.blue,
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
  double _compassOffset = 0.0; // Manual software calibration offset

  // High-accuracy compass states
  double _smoothHeading = 0.0;
  final double _filterFactor =
      0.15; // Lower = smoother, but laggy. 0.15 is snappy.

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

      // Compass listener with smoothing and speed-based logic
      FlutterCompass.events?.listen((event) {
        if (!mounted || event.heading == null) return;

        // Use GPS Heading if moving, else Magnetometer
        double rawHeading = event.heading!;
        if (_currentPosition != null && _currentPosition!.speed > 1.0) {
          // > 3.6km/h
          rawHeading = _currentPosition!.heading;
        }

        double diff = (rawHeading - _smoothHeading);
        while (diff < -180) diff += 360;
        while (diff > 180) diff -= 360;

        setState(() {
          _smoothHeading += diff * _filterFactor;
        });
      });

      // Continuous location updates
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
      final shelters = await _shelterService.fetchNearbyShelters(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _shelters = shelters;
        _nearestShelter = _logic.findNearestShelter(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          shelters,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch shelters';
        _isLoading = false;
      });
    }
  }

  void _showCalibrationDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calibrate Compass',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Hardware Calibration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Move your phone in a figure-8 pattern as shown below to recalibrate the hardware sensors.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/calibration_8.png',
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '2. Software Offset',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Adjust if the needle is still consistently off.',
                    textAlign: TextAlign.center,
                  ),
                  Slider(
                    value: _compassOffset,
                    min: -180,
                    max: 180,
                    divisions: 360,
                    label: '${_compassOffset.round()}°',
                    onChanged: (value) {
                      setModalState(() => _compassOffset = value);
                      setState(() => _compassOffset = value);
                    },
                  ),
                  Text('Offset: ${_compassOffset.round()} degrees'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Shelters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_overscan),
            tooltip: 'Calibrate Compass',
            onPressed: _showCalibrationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshShelters,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : _buildMainUI(),
    );
  }

  Widget _buildMainUI() {
    if (_shelters.isEmpty) {
      return const Center(child: Text('No shelters found in your area.'));
    }

    return Column(
      children: [
        Expanded(flex: 2, child: _buildCompassSection()),
        const Divider(height: 1),
        Expanded(flex: 3, child: _buildShelterList()),
      ],
    );
  }

  Widget _buildCompassSection() {
    if (_nearestShelter == null || _currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
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

    // Use our smoothed heading and add the manual offset
    double rotation =
        (bearing - _smoothHeading + _compassOffset) * (math.pi / 180);

    // Check if we are currently using GPS heading (speed > 1.0 m/s)
    bool isGpsHeading = _currentPosition!.speed > 1.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 4,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: rotation,
                  child: const Icon(
                    Icons.north,
                    size: 80,
                    color: Colors.redAccent,
                  ),
                ),
                if (isGpsHeading)
                  const Positioned(
                    bottom: 0,
                    child: Icon(Icons.gps_fixed, size: 16, color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Target Shelter',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                      if (isGpsHeading)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            '(GPS)',
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${distance.round()} meters',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _nearestShelter!.address,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelterList() {
    return ListView.builder(
      itemCount: _shelters.length,
      itemBuilder: (context, index) {
        final shelter = _shelters[index];
        final distance = _logic.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          shelter,
        );

        final bool isNearest = shelter.id == _nearestShelter?.id;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isNearest ? Colors.redAccent : Colors.blueGrey,
            child: Icon(
              isNearest ? Icons.star : Icons.location_on,
              color: Colors.white,
            ),
          ),
          title: Text(shelter.address),
          subtitle: Text('Capacity: ${shelter.capacity} people'),
          trailing: Text('${(distance / 1000).toStringAsFixed(1)} km'),
          onTap: () {
            setState(() {
              _nearestShelter = shelter;
              _isManualSelection = true;
            });
          },
        );
      },
    );
  }
}
