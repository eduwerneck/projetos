import 'package:flutter/material.dart';
import '../models/session.dart';
import '../config/app_theme.dart';

class SessionStatusBadge extends StatelessWidget {
  final SessionStatus status;
  final bool small;

  const SessionStatusBadge({super.key, required this.status, this.small = false});

  Color get _color {
    switch (status) {
      case SessionStatus.created:
        return Colors.grey;
      case SessionStatus.capturing:
        return Colors.blue;
      case SessionStatus.captured:
        return Colors.orange;
      case SessionStatus.uploading:
        return Colors.purple;
      case SessionStatus.processing:
        return AppTheme.warningColor;
      case SessionStatus.completed:
        return AppTheme.primaryGreen;
      case SessionStatus.error:
        return AppTheme.errorColor;
    }
  }

  IconData get _icon {
    switch (status) {
      case SessionStatus.created:
        return Icons.add_circle_outline;
      case SessionStatus.capturing:
        return Icons.camera_alt;
      case SessionStatus.captured:
        return Icons.check_circle_outline;
      case SessionStatus.uploading:
        return Icons.cloud_upload;
      case SessionStatus.processing:
        return Icons.settings;
      case SessionStatus.completed:
        return Icons.check_circle;
      case SessionStatus.error:
        return Icons.error;
    }
  }

  String get _label {
    switch (status) {
      case SessionStatus.created:
        return 'Criada';
      case SessionStatus.capturing:
        return 'Capturando';
      case SessionStatus.captured:
        return 'Capturada';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: small ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
