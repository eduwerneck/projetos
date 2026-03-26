enum UploadStage {
  idle,
  compressing,
  uploading,
  queued,
  processing,
  done,
  error,
}

class UploadProgress {
  final UploadStage stage;
  final double progress; // 0.0 to 1.0
  final String message;
  final int uploadedFiles;
  final int totalFiles;
  final String? jobId;
  final String? errorMessage;

  const UploadProgress({
    this.stage = UploadStage.idle,
    this.progress = 0.0,
    this.message = '',
    this.uploadedFiles = 0,
    this.totalFiles = 0,
    this.jobId,
    this.errorMessage,
  });

  UploadProgress copyWith({
    UploadStage? stage,
    double? progress,
    String? message,
    int? uploadedFiles,
    int? totalFiles,
    String? jobId,
    String? errorMessage,
  }) {
    return UploadProgress(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      uploadedFiles: uploadedFiles ?? this.uploadedFiles,
      totalFiles: totalFiles ?? this.totalFiles,
      jobId: jobId ?? this.jobId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get stageLabel {
    switch (stage) {
      case UploadStage.idle:
        return 'Aguardando';
      case UploadStage.compressing:
        return 'Comprimindo imagens';
      case UploadStage.uploading:
        return 'Enviando ($uploadedFiles/$totalFiles)';
      case UploadStage.queued:
        return 'Na fila de processamento';
      case UploadStage.processing:
        return 'Processando pipeline';
      case UploadStage.done:
        return 'Concluído';
      case UploadStage.error:
        return 'Erro: $errorMessage';
    }
  }
}
