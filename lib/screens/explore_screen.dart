import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/widgets/elora_components.dart';
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
  String? _locationMessage;
  String _searchQuery = '';

  LatLng? _userPosition;
  double _headingRadians = 0;
  double _smoothedHeading = 0;
  bool _compassHasData = false;

  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  DateTime _lastShakeTime = DateTime(2000);

  // =========================================================
  // DATA HELPERS
  // =========================================================

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  LatLng? _institutionPoint(Map<String, dynamic> institution) {
    final lat = _toDouble(institution['latitude']);
    final lng = _toDouble(institution['longitude']);

    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }

    return LatLng(lat, lng);
  }

  List<Map<String, dynamic>> get _filteredInstitutions {
    final query = _searchQuery.trim().toLowerCase();

    final result = institutions
        .where((item) {
          final name = (item['name'] ?? '').toString().toLowerCase();
          final type = (item['type'] ?? '').toString().toLowerCase();
          final location = (item['location'] ?? '').toString().toLowerCase();

          return query.isEmpty ||
              name.contains(query) ||
              type.contains(query) ||
              location.contains(query);
        })
        .where((item) => _institutionPoint(item) != null)
        .toList();

    if (_userPosition != null) {
      result.sort(
        (a, b) => _distanceInMeters(a).compareTo(_distanceInMeters(b)),
      );
    }

    return result;
  }

  double _distanceInMeters(Map<String, dynamic> institution) {
    final point = _institutionPoint(institution);

    if (_userPosition == null || point == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      point.latitude,
      point.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (!meters.isFinite) return 'Jarak tidak tersedia';
    if (meters < 1000) return '${meters.round()} m dari lokasi kamu';

    return '${(meters / 1000).toStringAsFixed(1)} km dari lokasi kamu';
  }

  // =========================================================
  // INITIALIZATION
  // =========================================================

  @override
  void initState() {
    super.initState();
    loadInstitutions();
    _startAccelerometer();
    _startCompass();
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

      if (_mapReady) {
        _fitInstitutionLocations();
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

  // =========================================================
  // MAP CAMERA
  // =========================================================

  void _fitInstitutionLocations() {
    if (!_mapReady) return;

    final points = _filteredInstitutions
        .map(_institutionPoint)
        .whereType<LatLng>()
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(45, 170, 45, 250),
        maxZoom: 10,
      ),
    );
  }

  void _zoomMap(double amount) {
    if (!_mapReady) return;

    final camera = _mapController.camera;
    final zoom = (camera.zoom + amount).clamp(2.0, 18.0);

    _mapController.move(camera.center, zoom);
  }

  void _focusInstitution(Map<String, dynamic> institution) {
    final point = _institutionPoint(institution);
    if (point == null || !_mapReady) return;

    _mapController.move(point, 13);
  }

  // =========================================================
  // ACCELEROMETER
  // =========================================================

  void _startAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        final magnitude =
            event.x * event.x + event.y * event.y + event.z * event.z;

        if (magnitude <= 18 * 18) return;

        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inSeconds < 3) return;

        _lastShakeTime = now;
        _refreshFromShake();
      },
      onError: (Object e) {
        debugPrint('Accelerometer error: $e');
      },
    );
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

  // =========================================================
  // COMPASS DAN MAGNETOMETER
  // =========================================================

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen(
      (event) {
        if (!mounted) return;

        final heading = event.heading;
        if (heading == null) return;

        _compassHasData = true;

        final raw = heading * math.pi / 180;

        // Haluskan sudut lewat komponen sin dan cos agar tidak loncat di batas 180 derajat
        final s = math.sin(_smoothedHeading) * 0.85 + math.sin(raw) * 0.15;
        final c = math.cos(_smoothedHeading) * 0.85 + math.cos(raw) * 0.15;
        _smoothedHeading = math.atan2(s, c);

        setState(() => _headingRadians = _smoothedHeading);
      },
      onError: (Object e) {
        debugPrint('Compass error: $e');
      },
    );
  }

  void _startMagnetometer() {
    _magnetometerSubscription =
        magnetometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          (event) {
            if (!mounted) return;

            // Fallback: hanya aktif kalau compass belum memberikan data
            if (_compassHasData) return;

            final raw = math.atan2(-event.x, event.y);

            final s = math.sin(_smoothedHeading) * 0.85 + math.sin(raw) * 0.15;
            final c = math.cos(_smoothedHeading) * 0.85 + math.cos(raw) * 0.15;
            _smoothedHeading = math.atan2(s, c);

            setState(() => _headingRadians = _smoothedHeading);
          },
          onError: (Object e) {
            debugPrint('Magnetometer error: $e');
          },
        );
  }

  // =========================================================
  // CURRENT LOCATION
  // =========================================================

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Aktifkan layanan lokasi perangkat terlebih dahulu.');
      }

      var permission = await Geolocator.checkPermission();

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

      final point = LatLng(position.latitude, position.longitude);

      setState(() {
        _userPosition = point;
        _locationMessage = 'Lokasi perangkat berhasil ditemukan.';
      });

      if (_mapReady) {
        _mapController.move(point, 14);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _locationMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  // =========================================================
  // NAVIGATION
  // =========================================================

  void _openInstitution(Map<String, dynamic> institution) {
    final point = _institutionPoint(institution);
    if (point == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstitutionPage(
          name: (institution['name'] ?? 'Institusi').toString(),
          type: (institution['type'] ?? '-').toString(),
          location: (institution['location'] ?? '-').toString(),
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      ),
    );
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    _accelerometerSubscription?.cancel();
    _compassSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // =========================================================
  // MAIN SCREEN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredInstitutions;

    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMap(filtered)),
            Positioned(top: 12, left: 18, right: 18, child: _buildTopPanel()),
            if (_locationMessage != null)
              Positioned(
                top: 155,
                left: 18,
                right: 18,
                child: _buildLocationMessage(),
              ),
            Positioned(top: 180, right: 16, child: _buildMapControls()),
            Positioned(left: 12, bottom: 205, child: _buildAttribution()),
            _buildInstitutionSheet(filtered),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MAP
  // =========================================================

  Widget _buildMap(List<Map<String, dynamic>> filtered) {
    final markers = <Marker>[
      for (final institution in filtered)
        if (_institutionPoint(institution) case final point?)
          Marker(
            point: point,
            width: 54,
            height: 54,
            child: GestureDetector(
              onTap: () => _openInstitution(institution),
              child: _institutionMarker(),
            ),
          ),
      if (_userPosition != null)
        Marker(
          point: _userPosition!,
          width: 54,
          height: 54,
          child: Transform.rotate(angle: _headingRadians, child: _userMarker()),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(-6.9, 110.0),
        initialZoom: 5,
        minZoom: 3,
        maxZoom: 18,
        onMapReady: () {
          _mapReady = true;
          _fitInstitutionLocations();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.elora.school',
          maxNativeZoom: 19,

          // Nonaktifkan cache bawaan yang memicu error path_provider.
          tileProvider: NetworkTileProvider(
            cachingProvider: const DisabledMapCachingProvider(),
          ),

          errorTileCallback: (tile, error, stackTrace) {
            debugPrint('OSM TILE ERROR: ${tile.coordinates} | $error');
          },
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _institutionMarker() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const CircleAvatar(
        backgroundColor: eloraPrimary,
        child: Icon(Icons.school_rounded, color: Colors.white, size: 23),
      ),
    );
  }

  Widget _userMarker() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: eloraPrimary.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: const CircleAvatar(
        backgroundColor: eloraPrimary,
        child: Icon(Icons.navigation_rounded, color: Colors.white, size: 25),
      ),
    );
  }

  // =========================================================
  // TOP PANEL
  // =========================================================

  Widget _buildTopPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: eloraPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: eloraPrimary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jelajahi Institusi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: eloraDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Temukan lokasi institusi ELORA',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: loadInstitutions,
                icon: const Icon(Icons.refresh_rounded, color: eloraPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSearchField(),
        ],
      ),
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearchField() {
    return EloraSearchField(
      controller: _searchController,
      hintText: 'Cari institusi atau lokasi...',
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
      suffixIcon: _searchQuery.isEmpty
          ? null
          : IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
    );
  }

  // =========================================================
  // LOCATION MESSAGE
  // =========================================================

  Widget _buildLocationMessage() {
    final success = _locationMessage!.contains('berhasil');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: success ? eloraPrimary : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _locationMessage!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: eloraDark,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _locationMessage = null);
            },
            icon: const Icon(Icons.close_rounded, size: 17),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAP CONTROLS
  // =========================================================

  Widget _buildMapControls() {
    return Column(
      children: [
        _mapButton(Icons.add_rounded, () => _zoomMap(1)),
        const SizedBox(height: 9),
        _mapButton(Icons.remove_rounded, () => _zoomMap(-1)),
        const SizedBox(height: 9),
        _mapButton(
          _isLoadingLocation
              ? Icons.hourglass_top_rounded
              : Icons.my_location_rounded,
          _getCurrentLocation,
          primary: true,
        ),
      ],
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap, {bool primary = false}) {
    return Material(
      color: primary ? eloraPrimary : Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: primary ? Colors.white : eloraPrimary,
            size: 23,
          ),
        ),
      ),
    );
  }

  Widget _buildAttribution() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
      ),
    );
  }

  // =========================================================
  // INSTITUTION BOTTOM SHEET
  // =========================================================

  Widget _buildInstitutionSheet(List<Map<String, dynamic>> filtered) {
    return DraggableScrollableSheet(
      initialChildSize: 0.31,
      minChildSize: 0.19,
      maxChildSize: 0.72,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: RefreshIndicator(
            color: eloraPrimary,
            onRefresh: loadInstitutions,
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildSheetHeader(filtered.length),
                const SizedBox(height: 16),

                if (_userPosition != null && filtered.isNotEmpty) ...[
                  _buildNearestInstitutionCard(filtered.first),
                  const SizedBox(height: 16),
                ],

                if (isLoadingInstitutions)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(color: eloraPrimary),
                    ),
                  )
                else if (filtered.isEmpty)
                  _buildEmptyState()
                else ...[
                  const Text(
                    'Daftar Institusi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: eloraDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...filtered.map(_buildInstitutionCard),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Institusi',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: eloraDark,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Temukan institusi di bawah yayasan',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: eloraPrimary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: eloraPrimary,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                '$count lokasi',
                style: const TextStyle(
                  fontSize: 11,
                  color: eloraPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // NEAREST INSTITUTION
  // =========================================================

  Widget _buildNearestInstitutionCard(Map<String, dynamic> institution) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F1F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8E2DF)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (institution['name'] ?? 'Institusi').toString(),
                  style: const TextStyle(
                    color: eloraDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatDistance(_distanceInMeters(institution)),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
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

  // =========================================================
  // INSTITUTION CARD
  // =========================================================

  Widget _buildInstitutionCard(Map<String, dynamic> institution) {
    return EloraCard(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(17),
      onTap: () => _openInstitution(institution),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: eloraPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (institution['name'] ?? 'Institusi').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: eloraDark,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  (institution['type'] ?? '-').toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: eloraPrimary,
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        (institution['location'] ?? '-').toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_userPosition != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _formatDistance(_distanceInMeters(institution)),
                    style: const TextStyle(
                      color: eloraPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tampilkan di peta',
            onPressed: () => _focusInstitution(institution),
            icon: const Icon(Icons.near_me_outlined, color: eloraPrimary),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    final hasError = institutionError != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: eloraBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            hasError ? Icons.cloud_off_outlined : Icons.search_off_rounded,
            color: eloraPrimary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(
            hasError
                ? 'Institusi tidak dapat dimuat'
                : 'Institusi tidak ditemukan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: eloraDark,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasError
                ? institutionError!
                : 'Coba gunakan nama institusi atau lokasi lain.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: loadInstitutions,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: OutlinedButton.styleFrom(foregroundColor: eloraPrimary),
          ),
        ],
      ),
    );
  }
}