import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/vari_engine.dart';
import 'result_screen.dart';

class SessionResultsScreen extends StatefulWidget {
  final List<VARIResult> results;
  final List<File> photos;

  const SessionResultsScreen({
    super.key,
    required this.results,
    required this.photos,
  });

  @override
  State<SessionResultsScreen> createState() => _SessionResultsScreenState();
}

class _SessionResultsScreenState extends State<SessionResultsScreen> {
  bool _exporting = false;
  final List<GlobalKey> _exportKeys = [];

  @override
  void initState() {
    super.initState();
    _exportKeys.addAll(List.generate(widget.results.length, (_) => GlobalKey()));
  }

  Future<void> _exportAll() async {
    setState(() => _exporting = true);
    try {
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];

      for (int i = 0; i < _exportKeys.length; i++) {
        final boundary = _exportKeys[i].currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        final file = File('${dir.path}/florafield_vari_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        files.add(XFile(file.path, mimeType: 'image/png'));
      }

      final summary = widget.results.asMap().entries
          .map((e) => 'Foto ${e.key + 1}: ${e.value.mean.toStringAsFixed(4)} (${e.value.vigorLabel})')
          .join('\n');

      await Share.shareXFiles(files, text: 'Resultados VARI — FloraField\n$summary');
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.results.length} Resultado${widget.results.length > 1 ? 's' : ''}'),
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Exportar todos',
                  onPressed: _exportAll,
                ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary bar
            _SummaryBar(results: widget.results),
            const SizedBox(height: 16),

            // Individual result cards
            ...List.generate(widget.results.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ResultCard(
                index: i,
                result: widget.results[i],
                photo: widget.photos[i],
                exportKey: _exportKeys[i],
                onDetail: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(result: widget.results[i]),
                  ),
                ),
              ),
            )),

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _exporting ? null : _exportAll,
              icon: const Icon(Icons.ios_share),
              label: const Text('Exportar todos'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final List<VARIResult> results;
  const _SummaryBar({required this.results});

  @override
  Widget build(BuildContext context) {
    final mean = results.map((r) => r.mean).reduce((a, b) => a + b) / results.length;
    final min = results.map((r) => r.mean).reduce((a, b) => a < b ? a : b);
    final max = results.map((r) => r.mean).reduce((a, b) => a > b ? a : b);

    final tempResult = VARIResult(
      mean: mean, median: mean, stdDev: 0, min: min, max: max,
      pixelCount: 0, variMap: results.first.variMap,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tempResult.vigorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tempResult.vigorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Média da sessão',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(mean.toStringAsFixed(4),
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: tempResult.vigorColor)),
              ],
            ),
          ),
          _SmallStat('Mín', min.toStringAsFixed(4)),
          const SizedBox(width: 12),
          _SmallStat('Máx', max.toStringAsFixed(4)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tempResult.vigorColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(tempResult.vigorLabel,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: tempResult.vigorColor)),
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final int index;
  final VARIResult result;
  final File photo;
  final GlobalKey exportKey;
  final VoidCallback onDetail;

  const _ResultCard({
    required this.index,
    required this.result,
    required this.photo,
    required this.exportKey,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: exportKey,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDetail,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Original photo thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(photo, width: 72, height: 72, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                // VARI map thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72, height: 72,
                    child: RawImage(image: result.variMap, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                // Stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Foto ${index + 1}',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: result.vigorColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(result.vigorLabel,
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: result.vigorColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(result.mean.toStringAsFixed(4),
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: result.vigorColor)),
                      const SizedBox(height: 2),
                      Text(
                        'Mediana ${result.median.toStringAsFixed(4)}  ·  DP ${result.stdDev.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
