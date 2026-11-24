import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elora_school/theme/colors.dart';

class InstitutionPage extends StatelessWidget {
  final String name;
  final String type;
  final String location;
  final double latitude;
  final double longitude;

  const InstitutionPage({
    super.key,
    required this.name,
    required this.type,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  Future<void> _openGoogleMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps?q=$latitude,$longitude',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Cannot launch Maps URL: $uri');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(latitude, longitude);

    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: eloraDark,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Institution Detail',
                  style: TextStyle(
                    color: eloraDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: eloraPrimary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    type,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _infoCard(
              title: 'Institution Information',
              children: [
                _infoItem(Icons.location_on_outlined, 'Location', location),
                _infoItem(
                  Icons.account_balance_outlined,
                  'Foundation',
                  'ELORA Education Foundation',
                ),
                _infoItem(Icons.school_outlined, 'Institution Type', type),
              ],
            ),
            const SizedBox(height: 18),
            _infoCard(
              title: 'Institution Location',
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    height: 230,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.elora.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: position,
                              width: 60,
                              height: 60,
                              child: const Icon(
                                Icons.location_on,
                                color: eloraPrimary,
                                size: 44,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _infoItem(
                  Icons.pin_drop_outlined,
                  'Coordinates',
                  '${latitude.toStringAsFixed(4)}, '
                      '${longitude.toStringAsFixed(4)}',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View map coordinates'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: eloraPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required List<Widget> children,
  }) {
    return EloraCard(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      borderRadius: BorderRadius.circular(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: eloraDark,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: eloraPrimary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: eloraDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
