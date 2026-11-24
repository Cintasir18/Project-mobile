
import 'package:flutter/material.dart';
import 'package:elora_school/widgets/elora_components.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/services/institution_service.dart';

class AdminInstitutionPage extends StatefulWidget {
  const AdminInstitutionPage({super.key});

  @override
  State<AdminInstitutionPage> createState() => _AdminInstitutionPageState();
}

class _AdminInstitutionPageState extends State<AdminInstitutionPage> {

  List<Institution> _institutions = [];
  bool _loading = true;
  bool _saving = false;
  String _search = '';
  String? _error;

  List<Institution> get _filteredInstitutions {
    final query = _search.trim().toLowerCase();

    if (query.isEmpty) return _institutions;

    return _institutions.where((institution) {
      return institution.name.toLowerCase().contains(query) ||
          institution.type.toLowerCase().contains(query) ||
          institution.location.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }


  Future<void> _loadInstitutions() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final rawData = await InstitutionService.instance.fetchAllForAdmin();
      final institutions = rawData.map(Institution.fromJson).toList();
      if (!mounted) return;
      setState(() { _institutions = institutions; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _cleanError(e); });
    }
  }

  Future<void> _openForm({Institution? institution}) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: institution?.name ?? '');
    final typeController = TextEditingController(text: institution?.type ?? '');
    final locationController = TextEditingController(
      text: institution?.location ?? '',
    );
    final latitudeController = TextEditingController(
      text: institution?.latitude.toString() ?? '',
    );
    final longitudeController = TextEditingController(
      text: institution?.longitude.toString() ?? '',
    );

    final isEditing = institution != null;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Institusi' : 'Tambah Institusi'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _formField(
                          controller: nameController,
                          label: 'Nama institusi',
                          hint: 'Contoh: SMA Harapan',
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: typeController,
                          label: 'Tipe institusi',
                          hint: 'Contoh: Senior High School',
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: locationController,
                          label: 'Lokasi',
                          hint: 'Contoh: Yogyakarta',
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: latitudeController,
                          label: 'Latitude',
                          hint: '-7.7956',
                          numeric: true,
                          validator: _validateLatitude,
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: longitudeController,
                          label: 'Longitude',
                          hint: '110.3695',
                          numeric: true,
                          validator: _validateLongitude,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: eloraPrimary),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {});
                          final payload = <String, dynamic>{
                            if (isEditing) 'id': institution.id,
                            'name': nameController.text.trim(),
                            'type': typeController.text.trim(),
                            'location': locationController.text.trim(),
                            'latitude': double.parse(
                              latitudeController.text.trim(),
                            ),
                            'longitude': double.parse(
                              longitudeController.text.trim(),
                            ),
                          };

                          Navigator.pop(dialogContext, true);

                          await _saveInstitution(payload, isEditing: isEditing);
                        },
                  child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    typeController.dispose();
    locationController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();

    if (result == true && mounted) {

    }
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool numeric = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label wajib diisi.';
            }
            return null;
          },
    );
  }

  String? _validateLatitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');

    if (number == null || !number.isFinite) {
      return 'Masukkan angka latitude yang valid.';
    }
    if (number < -90 || number > 90) {
      return 'Latitude harus antara -90 sampai 90.';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final number = double.tryParse(value?.trim() ?? '');

    if (number == null || !number.isFinite) {
      return 'Masukkan angka longitude yang valid.';
    }
    if (number < -180 || number > 180) {
      return 'Longitude harus antara -180 sampai 180.';
    }
    return null;
  }

  Future<void> _saveInstitution(
    Map<String, dynamic> payload, {
    required bool isEditing,
  }) async {
    if (!mounted) return;

    setState(() => _saving = true);

    try {
      if (isEditing) {
        await InstitutionService.instance.update(int.parse(payload['id'].toString()), payload);
      } else {
        await InstitutionService.instance.create(payload);
      }

      _showMessage(
        isEditing
            ? 'Data institusi berhasil diperbarui.'
            : 'Institusi berhasil ditambahkan.',
      );

      await _loadInstitutions();
    } catch (e) {
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivateInstitution(Institution institution) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan institusi?'),
        content: Text(
          'Institusi "${institution.name}" tidak akan muncul lagi '
          'di daftar institusi aktif. Data tidak dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    try {
      await InstitutionService.instance.deactivate(institution.id);

      _showMessage('Institusi berhasil dinonaktifkan.');
      await _loadInstitutions();
    } catch (e) {
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : eloraPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final institutions = _filteredInstitutions;

    return Scaffold(
      backgroundColor: eloraBackground,
      appBar: AppBar(
        backgroundColor: eloraPrimary,
        foregroundColor: Colors.white,
        title: const Text(
          'Kelola Institusi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading || _saving ? null : _loadInstitutions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openForm(),
        backgroundColor: eloraPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Institusi'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EloraSectionHeader(
                    title: 'Institusi Pendidikan',
                    subtitle: 'Kelola informasi institusi dalam yayasan ELORA.',
                  ),
                  const SizedBox(height: 16),
                  EloraSearchField(
                    hintText: 'Cari nama, tipe, atau lokasi...',
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.apartment, color: eloraPrimary),
                      const SizedBox(width: 8),
                      Text(
                        '${_institutions.length} institusi aktif',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent(institutions)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Institution> institutions) {
    if (_loading) {
      return const EloraLoadingState(message: 'Memuat data institusi...');
    }

    if (_error != null && _institutions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadInstitutions,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (institutions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apartment_outlined,
                size: 58,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                _search.isEmpty
                    ? 'Belum ada institusi aktif.'
                    : 'Institusi tidak ditemukan.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInstitutions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: institutions.length,
        itemBuilder: (context, index) {
          final institution = institutions[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: eloraPrimary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: eloraPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              institution.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              institution.type,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    institution.location,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: eloraBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Koordinat: ${institution.latitude}, '
                      '${institution.longitude}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _openForm(institution: institution),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _deactivateInstitution(institution),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.block_outlined, size: 18),
                        label: const Text('Nonaktifkan'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class Institution {
  final int id;
  final String name;
  final String type;
  final String location;
  final double latitude;
  final double longitude;

  const Institution({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
    );
  }
}
