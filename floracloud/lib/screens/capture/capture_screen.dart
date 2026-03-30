import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../models/field_photo.dart';
import '../../providers/session_provider.dart';
import '../../config/app_theme.dart';
import 'package:uuid/uuid.dart';

enum _CaptureStep { calibrationEntry, field, calibrationExit }

class CaptureScreen extends StatefulWidget {
  final FieldSession session;

  const CaptureScreen({super.key, required this.session});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  _CaptureStep _currentStep = _CaptureStep.calibrationEntry;
  final ImagePicker _picker = ImagePicker();

  final List<FieldPhoto> _calibrationEntryPhotos = [];
  final List<FieldPhoto> _fieldPhotos = [];
  final List<FieldPhoto> _calibrationExitPhotos = [];

  bool _isSaving = false;

  List<FieldPhoto> get _currentPhotos {
    switch (_currentStep) {
      case _CaptureStep.calibrationEntry:
        return _calibrationEntryPhotos;
      case _CaptureStep.field:
        return _fieldPhotos;
      case _CaptureStep.calibrationExit:
        return _calibrationExitPhotos;
    }
  }

  int get _stepIndex {
    return _currentStep.index;
  }

  String get _stepTitle {
    switch (_currentStep) {
      case _CaptureStep.calibrationEntry:
        return 'Calibração — Entrada';
      case _CaptureStep.field:
        return 'Fotos da Parcela';
      case _CaptureStep.calibrationExit:
        return 'Calibração — Saída';
    }
  }

  String get _stepInstructions {
    switch (_currentStep) {
      case _CaptureStep.calibrationEntry:
        return 'Fotografe o painel de reflectância ANTES de entrar na parcela. '
            'Capture pelo menos 3 fotos com ângulos ligeiramente diferentes, '
            'garantindo que o painel ocupe >50% do quadro.';
      case _CaptureStep.field:
        return 'Percorra a parcela (${widget.session.plotSizeMeters.toInt()}×'
            '${widget.session.plotSizeMeters.toInt()}m) fotografando a vegetação '
            'em sobreposição de 60-80%. Capture de múltiplas alturas e ângulos. '
            'Mínimo recomendado: 50 fotos.';
      case _CaptureStep.calibrationExit:
        return 'Fotografe o painel de reflectância APÓS concluir a parcela. '
            'Mínimo 3 fotos para detecção de deriva de luz.';
    }
  }

  int get _minPhotos {
    switch (_currentStep) {
      case _CaptureStep.calibrationEntry:
        return 3;
      case _CaptureStep.field:
        return 10;
      case _CaptureStep.calibrationExit:
        return 3;
    }
  }

  bool get _stepComplete => _currentPhotos.length >= _minPhotos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Captura — ${widget.session.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_stepIndex + 1) / 3,
            backgroundColor: Colors.white30,
            color: AppTheme.accentGreen,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInstructionCard(),
                const SizedBox(height: 16),
                _buildPhotoGrid(),
                const SizedBox(height: 16),
                _buildCaptureButtons(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Painel\nEntrada', 'Parcela\nCampo', 'Painel\nSaída'];
    return Container(
      color: AppTheme.primaryGreen,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _stepIndex;
          final isDone = i < _stepIndex;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppTheme.accentGreen
                              : isActive
                                  ? Colors.white
                                  : Colors.white30,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? AppTheme.primaryGreen
                                        : Colors.white60,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? Colors.white : Colors.white60,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 20,
                    height: 1,
                    color: Colors.white30,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppTheme.primaryGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                _stepTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _stepComplete
                      ? AppTheme.accentGreen
                      : AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPhotos.length}/$_minPhotos mín.',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _stepInstructions,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textMedium, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_currentPhotos.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 36, color: AppTheme.textLight),
              SizedBox(height: 8),
              Text('Nenhuma foto ainda',
                  style: TextStyle(color: AppTheme.textLight)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _currentPhotos.length,
      itemBuilder: (context, index) {
        final photo = _currentPhotos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photo.localPath),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => setState(() => _currentPhotos.removeAt(index)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _captureWithCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Câmera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeria'),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final canProceed = _currentStep == _CaptureStep.calibrationEntry
        ? _stepComplete
        : _currentStep == _CaptureStep.field
            ? _stepComplete
            : _stepComplete;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          if (_stepIndex > 0)
            TextButton.icon(
              onPressed: () => setState(
                () => _currentStep =
                    _CaptureStep.values[_stepIndex - 1],
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            ),
          const Spacer(),
          if (_currentStep != _CaptureStep.calibrationExit)
            ElevatedButton.icon(
              onPressed: canProceed
                  ? () => setState(() =>
                      _currentStep = _CaptureStep.values[_stepIndex + 1])
                  : null,
              icon: const Icon(Icons.arrow_forward),
              label: Text(_currentStep == _CaptureStep.calibrationEntry
                  ? 'Ir para Parcela'
                  : 'Ir para Saída'),
            )
          else
            ElevatedButton.icon(
              onPressed: (canProceed && !_isSaving) ? _finishCapture : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Concluir Captura'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen),
            ),
        ],
      ),
    );
  }

  Future<void> _captureWithCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xFile != null) {
      _addPhoto(xFile.path);
    }
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 95);
    for (final f in files) {
      _addPhoto(f.path);
    }
  }

  void _addPhoto(String path) {
    final type = _currentStep == _CaptureStep.calibrationEntry
        ? PhotoType.calibrationEntry
        : _currentStep == _CaptureStep.field
            ? PhotoType.field
            : PhotoType.calibrationExit;

    final photo = FieldPhoto(
      id: const Uuid().v4(),
      sessionId: widget.session.id,
      localPath: path,
      type: type,
      capturedAt: DateTime.now(),
    );

    setState(() => _currentPhotos.add(photo));
  }

  Future<void> _finishCapture() async {
    setState(() => _isSaving = true);

    final totalPhotos = _fieldPhotos.length;
    final totalCalibration =
        _calibrationEntryPhotos.length + _calibrationExitPhotos.length;

    final updated = widget.session
      ..photoCount = totalPhotos
      ..calibrationPhotos = totalCalibration
      ..status = SessionStatus.captured
      ..fieldPhotoPaths = _fieldPhotos.map((p) => p.localPath).toList()
      ..calibrationEntryPhotoPaths = _calibrationEntryPhotos.map((p) => p.localPath).toList()
      ..calibrationExitPhotoPaths = _calibrationExitPhotos.map((p) => p.localPath).toList();

    await context.read<SessionProvider>().updateSession(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$totalPhotos fotos de campo + $totalCalibration de calibração capturadas!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      context.pop();
    }
  }
}
