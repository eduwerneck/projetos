import 'dart:convert';

enum SessionStatus {
  created,
  capturing,
  captured,
  uploading,
  processing,
  completed,
  error,
}

enum GpsMode { cellphone, geodetic }

class GpsCoordinate {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;

  GpsCoordinate({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
  });

  factory GpsCoordinate.fromJson(Map<String, dynamic> json) {
    return GpsCoordinate(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble(),
      accuracy: json['accuracy']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'accuracy': accuracy,
      };

  @override
  String toString() =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

class FieldSession {
  final String id;
  String name;
  String? description;
  String? location;
  GpsCoordinate? gpsCoordinate;
  GpsMode gpsMode;
  DateTime createdAt;
  DateTime? processedAt;
  SessionStatus status;
  int photoCount;
  int calibrationPhotos;
  String? serverJobId;
  String? errorMessage;
  VARIResult? variResult;
  double plotSizeMeters;
  List<String> fieldPhotoPaths;
  List<String> calibrationEntryPhotoPaths;
  List<String> calibrationExitPhotoPaths;

  FieldSession({
    required this.id,
    required this.name,
    this.description,
    this.location,
    this.gpsCoordinate,
    this.gpsMode = GpsMode.cellphone,
    required this.createdAt,
    this.processedAt,
    this.status = SessionStatus.created,
    this.photoCount = 0,
    this.calibrationPhotos = 0,
    this.serverJobId,
    this.errorMessage,
    this.variResult,
    this.plotSizeMeters = 30.0,
    this.fieldPhotoPaths = const [],
    this.calibrationEntryPhotoPaths = const [],
    this.calibrationExitPhotoPaths = const [],
  });

  factory FieldSession.fromJson(Map<String, dynamic> json) {
    return FieldSession(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      gpsCoordinate: json['gps_coordinate'] != null
          ? GpsCoordinate.fromJson(json['gps_coordinate'])
          : null,
      gpsMode: GpsMode.values.firstWhere(
        (e) => e.name == json['gps_mode'],
        orElse: () => GpsMode.cellphone,
      ),
      createdAt: DateTime.parse(json['created_at']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      status: SessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SessionStatus.created,
      ),
      photoCount: json['photo_count'] as int? ?? 0,
      calibrationPhotos: json['calibration_photos'] as int? ?? 0,
      serverJobId: json['server_job_id'] as String?,
      errorMessage: json['error_message'] as String?,
      variResult: json['vari_result'] != null
          ? VARIResult.fromJson(json['vari_result'])
          : null,
      plotSizeMeters: json['plot_size_meters']?.toDouble() ?? 30.0,
      fieldPhotoPaths: List<String>.from(json['field_photo_paths'] ?? []),
      calibrationEntryPhotoPaths: List<String>.from(json['calibration_entry_photo_paths'] ?? []),
      calibrationExitPhotoPaths: List<String>.from(json['calibration_exit_photo_paths'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'location': location,
        'gps_coordinate': gpsCoordinate?.toJson(),
        'gps_mode': gpsMode.name,
        'created_at': createdAt.toIso8601String(),
        'processed_at': processedAt?.toIso8601String(),
        'status': status.name,
        'photo_count': photoCount,
        'calibration_photos': calibrationPhotos,
        'server_job_id': serverJobId,
        'error_message': errorMessage,
        'vari_result': variResult?.toJson(),
        'plot_size_meters': plotSizeMeters,
        'field_photo_paths': fieldPhotoPaths,
        'calibration_entry_photo_paths': calibrationEntryPhotoPaths,
        'calibration_exit_photo_paths': calibrationExitPhotoPaths,
      };

  String toJsonString() => jsonEncode(toJson());

  factory FieldSession.fromJsonString(String jsonString) =>
      FieldSession.fromJson(jsonDecode(jsonString));

  String get statusLabel {
    switch (status) {
      case SessionStatus.created:
        return 'Criada';
      case SessionStatus.capturing:
        return 'Capturando';
      case SessionStatus.captured:
        return 'Fotos Capturadas';
      case SessionStatus.uploading:
        return 'Enviando';
      case SessionStatus.processing:
        return 'Processando';
      case SessionStatus.completed:
        return 'Concluída';
      case SessionStatus.error:
        return 'Erro';
    }
  }

  bool get canCapture =>
      status == SessionStatus.created || status == SessionStatus.capturing;
  bool get canUpload =>
      status == SessionStatus.captured && photoCount > 0;
  bool get hasResults => status == SessionStatus.completed && variResult != null;
}

class VARIResult {
  final double mean;
  final double median;
  final double stdDev;
  final double min;
  final double max;
  final int pointCount;
  final Map<String, double> stratifiedByHeight;
  final String? plyFilePath;
  final String? reportJsonPath;
  final DateTime processedAt;

  VARIResult({
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.min,
    required this.max,
    required this.pointCount,
    required this.stratifiedByHeight,
    this.plyFilePath,
    this.reportJsonPath,
    required this.processedAt,
  });

  factory VARIResult.fromJson(Map<String, dynamic> json) {
    final strat = <String, double>{};
    if (json['stratified_by_height'] != null) {
      (json['stratified_by_height'] as Map<String, dynamic>).forEach((k, v) {
        strat[k] = v?.toDouble() ?? 0.0;
      });
    }
    return VARIResult(
      mean: json['mean']?.toDouble() ?? 0.0,
      median: json['median']?.toDouble() ?? 0.0,
      stdDev: json['std_dev']?.toDouble() ?? 0.0,
      min: json['min']?.toDouble() ?? 0.0,
      max: json['max']?.toDouble() ?? 0.0,
      pointCount: json['point_count'] as int? ?? 0,
      stratifiedByHeight: strat,
      plyFilePath: json['ply_file_path'] as String?,
      reportJsonPath: json['report_json_path'] as String?,
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mean': mean,
        'median': median,
        'std_dev': stdDev,
        'min': min,
        'max': max,
        'point_count': pointCount,
        'stratified_by_height': stratifiedByHeight,
        'ply_file_path': plyFilePath,
        'report_json_path': reportJsonPath,
        'processed_at': processedAt.toIso8601String(),
      };

  String get vigorLabel {
    if (mean >= 0.3) return 'Alto vigor vegetativo';
    if (mean >= 0.1) return 'Vigor moderado';
    if (mean >= 0.0) return 'Baixo vigor';
    return 'Estresse vegetativo';
  }
}
