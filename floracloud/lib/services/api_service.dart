import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/session.dart';
import '../models/upload_progress.dart';

class ApiService {
  static const String _defaultBaseUrl = 'http://localhost:8000';

  final Dio _dio;
  final Logger _logger = Logger();
  String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl, _dio = Dio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    );
    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
    ));
  }

  // -------- Sessions --------

  Future<String> createSession(FieldSession session) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/sessions',
        data: session.toJson(),
      );
      return response.data['session_id'] as String;
    } on DioException catch (e) {
      _logger.e('Error creating session', error: e);
      throw ApiException('Erro ao criar sessão: ${e.message}');
    }
  }

  Future<List<FieldSession>> listSessions() async {
    try {
      final response = await _dio.get('$baseUrl/api/sessions');
      final list = response.data as List<dynamic>;
      return list.map((e) => FieldSession.fromJson(e)).toList();
    } on DioException catch (e) {
      _logger.e('Error listing sessions', error: e);
      throw ApiException('Erro ao listar sessões: ${e.message}');
    }
  }

  Future<FieldSession> getSession(String sessionId) async {
    try {
      final response = await _dio.get('$baseUrl/api/sessions/$sessionId');
      return FieldSession.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Error getting session', error: e);
      throw ApiException('Erro ao obter sessão: ${e.message}');
    }
  }

  // -------- Photo Upload --------

  Future<void> uploadPhotos({
    required String sessionId,
    required List<File> calibrationEntryPhotos,
    required List<File> calibrationMidpointPhotos,
    required List<File> calibrationExitPhotos,
    required List<File> fieldPhotos,
    required Function(UploadProgress) onProgress,
  }) async {
    final allFiles = [
      ...calibrationEntryPhotos.map((f) => MapEntry('calibration_entry', f)),
      ...calibrationMidpointPhotos.map((f) => MapEntry('calibration_midpoint', f)),
      ...calibrationExitPhotos.map((f) => MapEntry('calibration_exit', f)),
      ...fieldPhotos.map((f) => MapEntry('field', f)),
    ];

    final total = allFiles.length;
    int uploaded = 0;

    onProgress(UploadProgress(
      stage: UploadStage.uploading,
      progress: 0,
      totalFiles: total,
      uploadedFiles: 0,
      message: 'Iniciando upload...',
    ));

    for (final entry in allFiles) {
      final photoType = entry.key;
      final file = entry.value;

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
        'type': photoType,
      });

      await _dio.post(
        '$baseUrl/api/sessions/$sessionId/photos',
        data: formData,
        onSendProgress: (sent, total) {
          // per-file progress ignored here
        },
      );

      uploaded++;
      onProgress(UploadProgress(
        stage: UploadStage.uploading,
        progress: uploaded / total,
        totalFiles: total,
        uploadedFiles: uploaded,
        message: 'Enviando fotos...',
      ));
    }
  }

  // -------- Pipeline --------

  Future<String> startProcessing(String sessionId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/sessions/$sessionId/process',
      );
      return response.data['job_id'] as String;
    } on DioException catch (e) {
      _logger.e('Error starting processing', error: e);
      throw ApiException('Erro ao iniciar processamento: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      final response = await _dio.get('$baseUrl/api/jobs/$jobId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _logger.e('Error getting job status', error: e);
      throw ApiException('Erro ao verificar status: ${e.message}');
    }
  }

  Future<VARIResult?> getResults(String sessionId) async {
    try {
      final response = await _dio.get('$baseUrl/api/sessions/$sessionId/results');
      if (response.statusCode == 200 && response.data != null) {
        return VARIResult.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      _logger.e('Error getting results', error: e);
      throw ApiException('Erro ao buscar resultados: ${e.message}');
    }
  }

  Future<String> getPlyDownloadUrl(String sessionId) {
    return Future.value('$baseUrl/api/sessions/$sessionId/export/ply');
  }

  Future<String> getReportDownloadUrl(String sessionId) {
    return Future.value('$baseUrl/api/sessions/$sessionId/export/report');
  }

  Future<bool> checkHealth() async {
    final response = await _dio.get(
      '$baseUrl/health',
      options: Options(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    return response.statusCode == 200;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
