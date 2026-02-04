import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF191C20),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  children: [
                    Text(
                      'Kalibrera kompassen',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Image.asset(
                        'assets/infinity.png',
                        height: 100,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Rör telefonen i mönstret av en åtta för att kalibrera sensorerna.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        color: const Color(0xFF9BA1A6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      'Manuell justering',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Justera om kompassnålen konsekvent visar i fel riktning.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: const Color(0xFF9BA1A6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    StatefulBuilder(
                      builder: (context, setModalState) {
                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.white.withOpacity(0.2),
                                inactiveTrackColor: Colors.white.withOpacity(
                                  0.1,
                                ),
                                thumbColor: Colors.white,
                                trackHeight: 32,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 16,
                                ),
                                overlayColor: Colors.white.withOpacity(0.1),
                              ),
                              child: Slider(
                                value: _compassOffset,
                                min: -180,
                                max: 180,
                                divisions: 360,
                                onChanged: (value) {
                                  setModalState(() => _compassOffset = value);
                                  setState(() => _compassOffset = value);
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_compassOffset.round()} graders förskjutning',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Klar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            onPressed: _showCalibrationDialog,
            icon: const Icon(Icons.settings_input_antenna, color: Colors.white),
            tooltip: 'Kalibrera',
          ),
          IconButton(
            onPressed: _refreshShelters,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Uppdatera',
          ),
        ],
      ),
    );
  }

  Widget _buildCompassSection() {
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

          return Column(
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
          );
        },
      ),
    );
  }

  Widget _buildGpsStatus() {
    bool isGpsHeading = (_currentPosition?.speed ?? 0) > 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            isGpsHeading ? 'GPS position aktiv' : 'GPS startar vid 3,6 km/h',
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
    );
  }

  Widget _buildShelterList() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF191C20)),
      child: ListView.separated(
        itemCount: _shelters.length,
        padding: const EdgeInsets.symmetric(vertical: 8),
        separatorBuilder: (context, index) => const SizedBox(height: 1),
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
              vertical: 8,
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
              '${(distance / 1000).toStringAsFixed(1)} km',
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
