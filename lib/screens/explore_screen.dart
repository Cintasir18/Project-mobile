import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/institution_service.dart';

import 'institution_detail_screen.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> institutions = [];

  bool isLoadingInstitutions = true;
  bool _isLoadingLocation = false;
  bool _mapReady = false;
  bool _isRefreshingFromShake = false;

  String? institutionError;
  String _searchQuery = '';
  String? _locationMessage;

  LatLng _mapCenter = const LatLng(-6.9, 110.0);
  double _mapZoom = 5.0;
  LatLng? _userPosition;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _lastShakeTime = DateTime(2000);

  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  double _headingRadians = 0.0;

  List<Map<String, dynamic>> get _filteredInstitutions {
    final query = _searchQuery.trim().toLowerCase();

    final result = institutions.where((institution) {
      final name = (institution['name'] ?? '').toString().toLowerCase();
      final type = (institution['type'] ?? '').toString().toLowerCase();
      final location = (institution['location'] ?? '').toString().toLowerCase();

      return query.isEmpty ||
          name.contains(query) ||
          type.contains(query) ||
          location.contains(query);
    }).toList();

    if (_userPosition != null) {
      result.sort(
        (a, b) => _distanceInMeters(a).compareTo(_distanceInMeters(b)),
      );
    }

    return result;
  }

  double _distanceInMeters(Map<String, dynamic> institution) {
    final latitude = double.tryParse('${institution['latitude'] ?? ''}');
    final longitude = double.tryParse('${institution['longitude'] ?? ''}');

    if (_userPosition == null || latitude == null || longitude == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      latitude,
      longitude,
    );
  }

  String _formatDistance(double meters) {
    if (!meters.isFinite) return 'Jarak tidak tersedia';
    if (meters < 1000) return '${meters.round()} m dari lokasi kamu';
    return '${(meters / 1000).toStringAsFixed(1)} km dari lokasi kamu';
  }

  @override
  void initState() {
    super.initState();
    loadInstitutions();
    _startAccelerometer();
    _startMagnetometer();
  }

  Future<void> loadInstitutions() async {
    if (!mounted) return;

    setState(() {
      isLoadingInstitutions = true;
      institutionError = null;
    });

    try {
      final result = await InstitutionService.instance.fetchInstitutions();

      if (!mounted) return;

      setState(() {
        institutions = result;
        isLoadingInstitutions = false;
        institutionError = result.isEmpty
            ? 'Belum ada institusi aktif dengan koordinat yang valid.'
            : null;
      });

      if (result.isNotEmpty) {
        _fitInstitutionLocations(result);
      }
    } catch (e, stackTrace) {
      debugPrint('EXPLORE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        isLoadingInstitutions = false;
        institutionError = e.toString();
      });
    }
  }

  void _fitInstitutionLocations(List<Map<String, dynamic>> data) {
    if (data.isEmpty || !_mapReady) return;

    final points = <LatLng>[];
    for (final institution in data) {
      final lat = double.tryParse('${institution['latitude'] ?? ''}');
      final lng = double.tryParse('${institution['longitude'] ?? ''}');
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
    }
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(45),
        maxZoom: 10,
      ),
    );
  }

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final mag = event.x * event.x + event.y * event.y + event.z * event.z;
      if (mag > 18 * 18) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds < 3) return;
        _lastShakeTime = now;
        _refreshFromShake();
      }
    }, onError: (Object e) => debugPrint('Accelerometer error: $e'));
  }

  Future<void> _refreshFromShake() async {
    if (_isRefreshingFromShake || !mounted) return;
    setState(() => _isRefreshingFromShake = true);
    await loadInstitutions();
    if (!mounted) return;
    setState(() => _isRefreshingFromShake = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          institutionError == null
              ? 'Data institusi berhasil diperbarui.'
              : 'Gagal memperbarui data: $institutionError',
        ),
      ),
    );
  }

  void _startMagnetometer() {
    _magnetometerSubscription =
        magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
            .listen((event) {
              if (!mounted) return;

              final heading = math.atan2(event.x, event.y);
              setState(() => _headingRadians = heading);
            }, onError: (Object e) => debugPrint('Magnetometer error: $e'));
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Aktifkan layanan lokasi perangkat terlebih dahulu.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi belum diberikan.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi ditolak permanen. Ubah melalui pengaturan.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;

      final userPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _userPosition = userPos;
        _mapCenter = userPos;
        _mapZoom = 14;
        _locationMessage = 'Lokasi perangkat berhasil ditemukan.';
      });

      if (_mapReady) _mapController.move(userPos, 14);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _openInstitution(Map<String, dynamic> institution) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstitutionPage(
          name: (institution['name'] ?? 'Institusi').toString(),
          type: (institution['type'] ?? '-').toString(),
          location: (institution['location'] ?? '-').toString(),
          latitude: (institution['latitude'] as num).toDouble(),
          longitude: (institution['longitude'] as num).toDouble(),
        ),
      ),
    );
  }

  void _focusInstitution(Map<String, dynamic> institution) {
    final pos = LatLng(
      (institution['latitude'] as num).toDouble(),
      (institution['longitude'] as num).toDouble(),
    );
    setState(() {
      _mapCenter = pos;
      _mapZoom = 13;
    });
    if (_mapReady) _mapController.move(pos, 13);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInstitutions;

    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: eloraPrimary,
          onRefresh: loadInstitutions,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            children: [
              const Text(
                'Explore',
                style: TextStyle(
                  color: eloraDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Explore institutions under the foundation',
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 22),
              _buildMapCard(filtered),
              if (_userPosition != null && filtered.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildNearestInstitutionCard(filtered.first),
              ],
              if (_locationMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _locationMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _locationMessage!.contains('berhasil')
                        ? eloraPrimary
                        : Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Institutions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: eloraDark,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length} locations',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildSearchField(),
              const SizedBox(height: 14),
              if (isLoadingInstitutions)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: CircularProgressIndicator(color: eloraPrimary),
                  ),
                )
              else if (filtered.isEmpty)
                _buildEmptyState()
              else
                ...filtered.map(_buildInstitutionCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard(List<Map<String, dynamic>> filtered) {
    final markers = <Marker>[];

    for (final inst in filtered) {
      final lat = inst['latitude'];
      final lng = inst['longitude'];
      if (lat is! num || lng is! num) continue;

      markers.add(
        Marker(
          point: LatLng(lat.toDouble(), lng.toDouble()),
          width: 150,
          height: 70,
          child: GestureDetector(
            onTap: () => _openInstitution(inst),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    inst['name'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: eloraDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.location_on, color: eloraPrimary, size: 30),
              ],
            ),
          ),
        ),
      );
    }

    if (_userPosition != null) {
      markers.add(
        Marker(
          point: _userPosition!,
          width: 48,
          height: 48,
          child: Transform.rotate(
            angle: _headingRadians,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 340,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
                onMapReady: () {
                  _mapReady = true;
                  if (institutions.isNotEmpty) {
                    _fitInstitutionLocations(institutions);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.elora.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            Positioned(top: 15, left: 15, child: _mapLabel()),

            Positioned(
              left: 15,
              bottom: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filtered.length} locations',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            Positioned(
              right: 15,
              bottom: 15,
              child: Column(
                children: [
                  _mapButton(
                    icon: Icons.add,
                    onTap: () {
                      _mapZoom = (_mapZoom + 1).clamp(2, 18).toDouble();
                      _mapController.move(_mapCenter, _mapZoom);
                    },
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    icon: Icons.remove,
                    onTap: () {
                      _mapZoom = (_mapZoom - 1).clamp(2, 18).toDouble();
                      _mapController.move(_mapCenter, _mapZoom);
                    },
                  ),
                  const SizedBox(height: 8),
                  _mapButton(
                    icon: _isLoadingLocation
                        ? Icons.hourglass_top
                        : Icons.my_location,
                    onTap: _getCurrentLocation,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: eloraPrimary, size: 19),
          SizedBox(width: 7),
          Text(
            'Foundation Locations',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _mapButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: eloraPrimary, size: 25),
        ),
      ),
    );
  }

  Widget _buildNearestInstitutionCard(Map<String, dynamic> institution) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F1F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8E2DF)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.near_me_rounded, color: eloraPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Institusi Terdekat',
                  style: TextStyle(
                    color: eloraPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (institution['name'] ?? 'Institusi').toString(),
                  style: const TextStyle(
                    color: eloraDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDistance(_distanceInMeters(institution)),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Lihat di peta',
            onPressed: () => _focusInstitution(institution),
            icon: const Icon(Icons.map_outlined, color: eloraPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search institution or location',
        prefixIcon: const Icon(Icons.search, color: eloraPrimary),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: eloraPrimary),
        ),
      ),
    );
  }

  Widget _buildInstitutionCard(Map<String, dynamic> institution) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openInstitution(institution),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: eloraPrimary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      institution['name'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: eloraDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      institution['type'].toString(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: eloraPrimary,
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            institution['location'].toString(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_userPosition != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            color: eloraPrimary,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDistance(_distanceInMeters(institution)),
                              style: const TextStyle(
                                color: eloraPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Show on map',
                onPressed: () => _focusInstitution(institution),
                icon: const Icon(Icons.near_me_outlined, color: eloraPrimary),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isError = institutionError != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.cloud_off_outlined : Icons.search_off_rounded,
            color: eloraPrimary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            isError
                ? 'Institutions could not be loaded'
                : 'Institution not found',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isError
                ? institutionError!
                : 'Try another institution name or location.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: loadInstitutions,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
