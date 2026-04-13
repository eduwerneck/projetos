import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/vari_engine.dart';

class ResultScreen extends StatefulWidget {
  final VARIResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _exportKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final boundary = _exportKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/florafield_vari_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Resultado VARI — FloraField\nMédia: ${widget.result.mean.toStringAsFixed(4)} (${widget.result.vigorLabel})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado VARI'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Exportar imagem',
                  onPressed: _export,
                ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Exportable card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _exportKey,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Map + color ramp
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: RawImage(image: r.variMap, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _ColorRamp(),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats block
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    r.mean.toStringAsFixed(4),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: r.vigorColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: r.vigorColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: r.vigorColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(r.vigorLabel,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: r.vigorColor, fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _MiniStat('Mediana', r.median.toStringAsFixed(4)),
                                  _MiniStat('Desv. Padrão', r.stdDev.toStringAsFixed(4)),
                                  _MiniStat('Mín', r.min.toStringAsFixed(4)),
                                  _MiniStat('Máx', r.max.toStringAsFixed(4)),
                                  _MiniStat('Pixels', _fmt(r.pixelCount)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Watermark
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            'FloraField',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Export button
            FilledButton.icon(
              onPressed: _exporting ? null : _export,
              icon: const Icon(Icons.ios_share),
              label: const Text('Exportar / Compartilhar'),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(text: '$label  ', style: TextStyle(color: Colors.grey.shade500)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ColorRamp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
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
          const SizedBox(height: 6),
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
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF00C800),
        Color(0xFFFFFF00),
        Color(0xFFFF0000),
      ],
      stops: [0.0, 0.5, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      paint,
    );
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
