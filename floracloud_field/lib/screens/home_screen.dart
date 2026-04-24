import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../engine/vari_engine.dart';
import 'result_screen.dart';
import 'session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _calEntry;
  File? _calExit;
  File? _field;
  bool _processing = false;
  String? _error;

  final _picker = ImagePicker();

  Future<void> _pick(String slot) async {
    final source = await _showSourceDialog();
    if (source == null) return;
    final xFile = await _picker.pickImage(source: source, imageQuality: 95);
    if (xFile == null) return;
    final file = File(xFile.path);
    setState(() {
      if (slot == 'entry') _calEntry = file;
      if (slot == 'exit') _calExit = file;
      if (slot == 'field') _field = file;
      _error = null;
    });
  }

  Future<ImageSource?> _showSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2E7D32)),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2E7D32)),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _calReady => _calEntry != null && _calExit != null;

  Future<void> _analyzeSingle() async {
    if (!_calReady || _field == null) {
      setState(() => _error = 'Tire as 3 fotos antes de analisar.');
      return;
    }
    setState(() { _processing = true; _error = null; });
    try {
      final cal = await deriveCalibration(_calEntry!, _calExit!);
      final result = await computeVARI(_field!, cal);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } catch (e) {
      setState(() => _error = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _startSession() async {
    if (!_calReady) {
      setState(() => _error = 'Tire as fotos de calibração antes de iniciar a sessão.');
      return;
    }
    setState(() { _processing = true; _error = null; });
    try {
      final cal = await deriveCalibration(_calEntry!, _calExit!);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SessionScreen(calibration: cal)),
      );
    } catch (e) {
      setState(() => _error = 'Erro na calibração: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, size: 22),
            SizedBox(width: 8),
            Text('FloraField — VARI Campo'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calibration section
              const Text('Calibração',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Fotografe o painel de referência na entrada e na saída do campo.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              _PhotoSlot(
                label: 'Painel — Entrada',
                icon: Icons.login,
                file: _calEntry,
                onTap: () => _pick('entry'),
              ),
              const SizedBox(height: 10),
              _PhotoSlot(
                label: 'Painel — Saída',
                icon: Icons.logout,
                file: _calExit,
                onTap: () => _pick('exit'),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              if (_calReady) ...[
                // Mode A: single photo
                _ModeCard(
                  icon: Icons.grass,
                  title: 'Análise rápida',
                  subtitle: 'Uma foto, resultado imediato',
                  color: const Color(0xFF2E7D32),
                  child: Column(
                    children: [
                      _PhotoSlot(
                        label: 'Foto da Planta / Área',
                        icon: Icons.grass,
                        file: _field,
                        onTap: () => _pick('field'),
                      ),
                      const SizedBox(height: 12),
                      if (_processing)
                        const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                      else
                        FilledButton.icon(
                          onPressed: _field != null ? _analyzeSingle : null,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analisar'),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Mode B: field session
                _ModeCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Sessão de campo',
                  subtitle: 'Várias fotos, resultados individualizados',
                  color: const Color(0xFF1565C0),
                  child: _processing
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                      : FilledButton.icon(
                          onPressed: _startSession,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Iniciar sessão'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                          ),
                        ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Complete a calibração acima para começar',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        color: color.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                  Text(subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final String label;
  final IconData icon;
  final File? file;
  final VoidCallback onTap;

  const _PhotoSlot({
    required this.label,
    required this.icon,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final taken = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: taken ? const Color(0xFF2E7D32) : Colors.grey.shade300,
            width: taken ? 2 : 1,
          ),
          color: taken
              ? const Color(0xFF2E7D32).withValues(alpha: 0.05)
              : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
              child: taken
                  ? Image.file(file!, width: 80, height: 80, fit: BoxFit.cover)
                  : Container(
                      width: 80, height: 80,
                      color: Colors.grey.shade200,
                      child: Icon(icon, size: 32, color: Colors.grey.shade400),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: taken ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                    )),
                  const SizedBox(height: 3),
                  Text(
                    taken ? 'Foto capturada ✓' : 'Câmera ou galeria',
                    style: TextStyle(
                      fontSize: 11,
                      color: taken ? const Color(0xFF43A047) : Colors.grey.shade500,
                    )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(
                taken ? Icons.check_circle : Icons.camera_alt_outlined,
                color: taken ? const Color(0xFF2E7D32) : Colors.grey.shade400,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
