enum PhotoType { calibrationEntry, calibrationMidpoint, calibrationExit, field }

class FieldPhoto {
  final String id;
  final String sessionId;
  final String localPath;
  final PhotoType type;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  bool isUploaded;

  FieldPhoto({
    required this.id,
    required this.sessionId,
    required this.localPath,
    required this.type,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.isUploaded = false,
  });

  factory FieldPhoto.fromJson(Map<String, dynamic> json) {
    return FieldPhoto(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      localPath: json['local_path'] as String,
      type: PhotoType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => PhotoType.field,
      ),
      capturedAt: DateTime.parse(json['captured_at']),
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      isUploaded: json['is_uploaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'local_path': localPath,
        'type': type.name,
        'captured_at': capturedAt.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'is_uploaded': isUploaded,
      };

  String get typeLabel {
    switch (type) {
      case PhotoType.calibrationEntry:
        return 'Painel - Entrada';
      case PhotoType.calibrationMidpoint:
        return 'Painel - Percurso';
      case PhotoType.calibrationExit:
        return 'Painel - Saída';
      case PhotoType.field:
        return 'Campo';
    }
  }

  bool get isCalibration =>
      type == PhotoType.calibrationEntry ||
      type == PhotoType.calibrationMidpoint ||
      type == PhotoType.calibrationExit;
}
