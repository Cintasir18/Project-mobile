class InstitutionModel {
  final int id; final String name; final String type; final String location;
  final double latitude; final double longitude; final bool isActive;
  const InstitutionModel({required this.id, required this.name, required this.type, required this.location, required this.latitude, required this.longitude, this.isActive = true});
  factory InstitutionModel.fromMap(Map<String, dynamic> map) => InstitutionModel(
    id: int.tryParse('${map['id']}') ?? 0, name: map['name']?.toString() ?? '',
    type: map['type']?.toString() ?? '', location: map['location']?.toString() ?? '',
    latitude: double.tryParse('${map['latitude']}') ?? 0, longitude: double.tryParse('${map['longitude']}') ?? 0,
    isActive: map['is_active'] != false,
  );
}
