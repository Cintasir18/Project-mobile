class UserModel {
  final String id;
  final String nama;
  final String? email;
  final String? studentId;
  final int? institutionId;
  final String? institution;
  final String? role;
  final bool isActive;

  const UserModel({required this.id, required this.nama, this.email, this.studentId, this.institutionId, this.institution, this.role, this.isActive = true});
  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id']?.toString() ?? '', nama: map['nama']?.toString() ?? map['full_name']?.toString() ?? '',
    email: map['email']?.toString(), studentId: map['student_id']?.toString(),
    institutionId: map['institution_id'] is num ? (map['institution_id'] as num).toInt() : int.tryParse('${map['institution_id']}'),
    institution: map['institution']?.toString(), role: map['role']?.toString(), isActive: map['is_active'] != false,
  );
}
