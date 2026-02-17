import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../services/shelter_service.dart';

/// Settings screen allowing the user to configure search parameters and access offline tools.
class SettingsScreen extends StatefulWidget {
  /// The currently selected search radius in kilometers.
  final double currentRadius;

  /// The maximum number of results to display.
  final int currentCap;

  /// The user's current GPS position (required for offline downloads).
  final Position? currentPosition;

  const SettingsScreen({
    super.key,
    required this.currentRadius,
    required this.currentCap,
    this.currentPosition,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _radius;
  late int _cap;
  bool _isDownloading = false;
  final ShelterService _shelterService = ShelterService();

  @override
  void initState() {
    super.initState();
    // Clamp radius to new max of 10km to avoid Slider errors
    _radius = widget.currentRadius.clamp(1.0, 10.0);
    _cap = widget.currentCap;
  }

  /// Downloads shelter data for the current location to cache.
  /// Allows the app to function without internet access later.
  Future<void> _downloadOfflineData() async {
    if (widget.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingen GPS-position tillgänglig')),
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final shelters = await _shelterService.fetchNearbyShelters(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
        radiusInMeters: _radius * 1000, // Convert km to meters
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${shelters.length} skyddsrum sparade för offline-läge',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid nedladdning: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  /// Displays a dialog with instructions on how to calibrate the compass.
  void _showCalibrationInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Kalibrera kompassen',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/infinity.png',
              height: 80,
              color: Colors.white.withOpacity(0.8),
              semanticLabel: 'Illustration av en telefon som rörs i en åtta',
            ),
            const SizedBox(height: 16),
            Text(
              'Rör telefonen i mönstret av en åtta för att kalibrera sensorerna.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inställningar', style: GoogleFonts.inter()),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Tillbaka',
          onPressed: () =>
              Navigator.pop(context, {'radius': _radius, 'cap': _cap}),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Sökinställningar'),
          const SizedBox(height: 16),
          _buildRadiusSlider(),
          const SizedBox(height: 24),
          _buildCapSlider(),

          const SizedBox(height: 16),
          Divider(
            height: 32,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          _buildSectionHeader('Offline & Verktyg'),
          const SizedBox(height: 16),
          _buildOfflineButton(),
          const SizedBox(height: 16),
          _buildCalibrationButton(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sökradie',
                style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
              ),
              Text(
                '${_radius.round()} km',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Sökradie',
          child: Slider(
            value: _radius,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) => setState(() => _radius = value),
            semanticFormatterCallback: (double value) {
              return '${value.round()} kilometer';
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCapSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Max antal träffar',
                style: GoogleFonts.inter(fontSize: 18, color: Colors.white),
              ),
              Text(
                '$_cap st',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Max antal träffar',
          child: Slider(
            value: _cap.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            onChanged: (value) => setState(() => _cap = value.toInt()),
            semanticFormatterCallback: (double value) {
              return '${value.toInt()} stycken';
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineButton() {
    return ElevatedButton.icon(
      onPressed: _isDownloading ? null : _downloadOfflineData,
      icon: _isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download),
      label: Text(
        _isDownloading ? 'Laddar ner...' : 'Ladda ner data för offline-läge',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildCalibrationButton() {
    return OutlinedButton.icon(
      onPressed: _showCalibrationInstructions,
      icon: const Icon(Icons.settings_input_antenna),
      label: const Text('Kalibreringsinstruktioner'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }
}
