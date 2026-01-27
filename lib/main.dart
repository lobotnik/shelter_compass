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

      // Periodically update location in real-time
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            // Only re-calculate nearest if we have shelters
            if (_shelters.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Shelters'),
        actions: [
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
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Compass Error'));

        final direction = snapshot.data?.heading;
        if (direction == null ||
            _nearestShelter == null ||
            _currentPosition == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Resulting angle to rotate the needle
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

        // Normalize heading and bearing to 0-360
        double heading = direction;
        double targetBearing = bearing;

        // Needle should rotate by (Target Bearing - Current Heading)
        double rotation = (targetBearing - heading) * (math.pi / 180);

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
                        Icons
                            .north, // Use north icon which points straight up (0 deg)
                        size: 80,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Nearest Shelter',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
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
      },
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
            });
          },
        );
      },
    );
  }
}
