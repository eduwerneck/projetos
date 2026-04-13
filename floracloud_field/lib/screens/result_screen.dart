import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../engine/vari_engine.dart';

class ResultScreen extends StatelessWidget {
  final VARIResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado VARI'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── VARI Map + Color Ramp ───────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mapa VARI',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // VARI map image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: RawImage(
                              image: result.variMap,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Color ramp legend
                        _ColorRamp(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── VARI Summary ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      result.mean.toStringAsFixed(4),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: result.vigorColor,
                      ),
                    ),
                    Text('VARI Médio',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: result.vigorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: result.vigorColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        result.vigorLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: result.vigorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Statistics ──────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estatísticas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 2.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _StatTile('Mediana', result.median.toStringAsFixed(4), Colors.teal),
                        _StatTile('Desv. Padrão', result.stdDev.toStringAsFixed(4), Colors.indigo),
                        _StatTile('Mínimo', result.min.toStringAsFixed(4), Colors.orange),
                        _StatTile('Máximo', result.max.toStringAsFixed(4), const Color(0xFF2E7D32)),
                        _StatTile('Pixels', _fmt(result.pixelCount), Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// Vertical color ramp from +1 (green) to -1 (red) with labels.
class _ColorRamp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          const Text('+1', style: TextStyle(fontSize: 10, color: Colors.green)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: const Size(24, 200),
              painter: _RampPainter(),
            ),
          ),
          const SizedBox(height: 2),
          const Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          const Text('-1', style: TextStyle(fontSize: 10, color: Colors.red)),
          const SizedBox(height: 8),
          const RotatedBox(
            quarterTurns: 3,
            child: Text('VARI', style: TextStyle(fontSize: 9, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _RampPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Top = +1 (green), middle = 0 (yellow), bottom = -1 (red)
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF00C800), // green  (+1)
        Color(0xFFFFFF00), // yellow (0)
        Color(0xFFFF0000), // red    (-1)
      ],
      stops: [0.0, 0.5, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
    // tick at midpoint (VARI = 0)
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(size.width, mid),
      Offset(size.width + 4, mid),
      Paint()..color = Colors.grey..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
