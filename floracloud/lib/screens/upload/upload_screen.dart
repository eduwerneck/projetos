import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../models/upload_progress.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../config/app_theme.dart';

class UploadScreen extends StatefulWidget {
  final FieldSession session;

  const UploadScreen({super.key, required this.session});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  UploadProgress _progress = const UploadProgress();
  bool _started = false;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar e Processar'),
        automaticallyImplyLeading: _progress.stage == UploadStage.idle ||
            _progress.stage == UploadStage.done ||
            _progress.stage == UploadStage.error,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSessionInfo(),
            const SizedBox(height: 24),
            _buildPipelineSteps(),
            const SizedBox(height: 24),
            if (_started) _buildProgressArea(),
            if (!_started) _buildStartButton(),
            if (_progress.stage == UploadStage.done) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.pushReplacementNamed(
                  'results',
                  pathParameters: {'id': widget.session.id},
                  extra: widget.session,
                ),
                icon: const Icon(Icons.analytics),
                label: const Text('Ver Resultados'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal),
              ),
            ],
            if (_progress.stage == UploadStage.error) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resetAndRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar Novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forest,
                  color: AppTheme.primaryGreen, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.session.photoCount} fotos de campo · '
                    '${widget.session.calibrationPhotos} de calibração',
                    style: const TextStyle(
                        color: AppTheme.textMedium, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineSteps() {
    final steps = [
      ('Upload das fotos', Icons.cloud_upload, UploadStage.uploading),
      ('Calibração radiométrica', Icons.tune, UploadStage.processing),
      ('Feature extraction SIFT', Icons.hub, UploadStage.processing),
      ('Structure from Motion', Icons.view_in_ar, UploadStage.processing),
      ('Depth Anything V2', Icons.layers, UploadStage.processing),
      ('Cálculo VARI', Icons.grass, UploadStage.processing),
      ('Exportação .ply + relatório', Icons.download, UploadStage.done),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pipeline FloraCloud',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textDark)),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isActive = _progress.stage == step.$3 &&
                  _progress.stage != UploadStage.idle;
              final isDone = _progress.stage == UploadStage.done ||
                  (_progress.stage == UploadStage.processing && i < 1) ||
                  (_progress.stage == UploadStage.queued && i < 1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppTheme.primaryGreen
                            : isActive
                                ? AppTheme.warningColor
                                : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : isActive
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(step.$2,
                        size: 16,
                        color: isDone
                            ? AppTheme.primaryGreen
                            : isActive
                                ? AppTheme.warningColor
                                : AppTheme.textLight),
                    const SizedBox(width: 8),
                    Text(
                      step.$1,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDone
                            ? AppTheme.primaryGreen
                            : isActive
                                ? AppTheme.textDark
                                : AppTheme.textLight,
                        fontWeight: isActive || isDone
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_progress.stage != UploadStage.done &&
                    _progress.stage != UploadStage.error)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryGreen),
                  ),
                if (_progress.stage == UploadStage.done)
                  const Icon(Icons.check_circle,
                      color: AppTheme.primaryGreen, size: 20),
                if (_progress.stage == UploadStage.error)
                  const Icon(Icons.error, color: AppTheme.errorColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _progress.stageLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress.stage == UploadStage.processing ||
                      _progress.stage == UploadStage.queued
                  ? null
                  : _progress.progress,
              backgroundColor: AppTheme.backgroundLight,
              color: _progress.stage == UploadStage.error
                  ? AppTheme.errorColor
                  : AppTheme.primaryGreen,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (_progress.stage == UploadStage.uploading) ...[
              const SizedBox(height: 8),
              Text(
                '${_progress.uploadedFiles} de ${_progress.totalFiles} arquivos enviados',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMedium),
              ),
            ],
            if (_progress.jobId != null) ...[
              const SizedBox(height: 6),
              Text(
                'Job ID: ${_progress.jobId}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textLight),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    final settings = context.watch<SettingsProvider>();
    return Column(
      children: [
        if (!settings.isConnected)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: AppTheme.warningColor, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Servidor offline. Configure o endereço nas configurações e certifique-se que o backend FloraCloud está rodando.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.warningColor),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton.icon(
          onPressed: settings.isConnected ? _startUpload : null,
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Iniciar Upload e Processamento'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  Future<void> _startUpload() async {
    setState(() => _started = true);
    final api = context.read<SettingsProvider>().apiService;
    final sessionProvider = context.read<SessionProvider>();

    try {
      // Update session status
      widget.session.status = SessionStatus.uploading;
      await sessionProvider.updateSession(widget.session);

      // For demo: create session on server then start processing
      final serverSessionId = await api.createSession(widget.session);

      setState(() => _progress = const UploadProgress(
            stage: UploadStage.uploading,
            progress: 0,
            message: 'Conectando ao servidor...',
          ));

      // Upload photos (in real app, pass actual File lists)
      await api.uploadPhotos(
        sessionId: serverSessionId,
        calibrationEntryPhotos: [],
        calibrationMidpointPhotos: [],
        calibrationExitPhotos: [],
        fieldPhotos: [],
        onProgress: (p) => setState(() => _progress = p),
      );

      setState(() => _progress = _progress.copyWith(
            stage: UploadStage.queued,
            progress: 1.0,
            message: 'Iniciando pipeline...',
          ));

      // Start processing
      final jobId = await api.startProcessing(serverSessionId);

      widget.session.serverJobId = jobId;
      widget.session.status = SessionStatus.processing;
      await sessionProvider.updateSession(widget.session);

      setState(() => _progress = _progress.copyWith(
            stage: UploadStage.processing,
            jobId: jobId,
            message: 'Pipeline em execução...',
          ));

      _startPolling(api, serverSessionId, jobId);
    } on ApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Erro inesperado: $e');
    }
  }

  void _startPolling(ApiService api, String sessionId, String jobId) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status = await api.getJobStatus(jobId);
        final jobStatus = status['status'] as String?;

        if (jobStatus == 'completed') {
          timer.cancel();
          final result = await api.getResults(sessionId);
          widget.session.status = SessionStatus.completed;
          widget.session.variResult = result;
          widget.session.processedAt = DateTime.now();
          if (!mounted) return;
          await context.read<SessionProvider>().updateSession(widget.session);
          if (mounted) {
            setState(() => _progress = _progress.copyWith(
                  stage: UploadStage.done,
                  progress: 1.0,
                  message: 'Processamento concluído!',
                ));
          }
        } else if (jobStatus == 'error' || jobStatus == 'failed') {
          timer.cancel();
          final errorMsg = status['error'] as String? ?? 'Erro no servidor';
          widget.session.status = SessionStatus.error;
          widget.session.errorMessage = errorMsg;
          if (!mounted) return;
          await context.read<SessionProvider>().updateSession(widget.session);
          _setError(errorMsg);
        }
      } catch (_) {
        // silently continue polling on transient errors
      }
    });
  }

  void _setError(String message) {
    if (mounted) {
      setState(() => _progress = _progress.copyWith(
            stage: UploadStage.error,
            errorMessage: message,
          ));
    }
  }

  void _resetAndRetry() {
    _pollingTimer?.cancel();
    setState(() {
      _started = false;
      _progress = const UploadProgress();
    });
  }
}
