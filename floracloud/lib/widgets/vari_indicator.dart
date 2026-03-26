import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class VARIIndicator extends StatelessWidget {
  final double value;
  final double size;
  final bool showLabel;

  const VARIIndicator({
    super.key,
    required this.value,
    this.size = 80,
    this.showLabel = true,
  });

  Color get _color {
    if (value >= 0.3) return const Color(0xFF1B5E20);
    if (value >= 0.2) return const Color(0xFF2E7D32);
    if (value >= 0.1) return const Color(0xFF43A047);
    if (value >= 0.0) return const Color(0xFFA5D6A7);
    if (value >= -0.1) return const Color(0xFFFFF176);
    return const Color(0xFFEF5350);
  }

  String get _label {
    if (value >= 0.3) return 'Excelente';
    if (value >= 0.2) return 'Alto';
    if (value >= 0.1) return 'Moderado';
    if (value >= 0.0) return 'Baixo';
    if (value >= -0.1) return 'Estresse';
    return 'Crítico';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withValues(alpha: 0.15),
            border: Border.all(color: _color, width: 3),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toStringAsFixed(3),
                  style: TextStyle(
                    fontSize: size * 0.18,
                    fontWeight: FontWeight.bold,
                    color: _color,
                  ),
                ),
                Text(
                  'VARI',
                  style: TextStyle(
                    fontSize: size * 0.12,
                    color: AppTheme.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _label,
              style: TextStyle(
                color: _color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
