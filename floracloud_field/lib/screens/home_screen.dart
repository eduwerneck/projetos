import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../engine/vari_engine.dart';
import 'result_screen.dart';

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

  Future<void> _analyze() async {
    if (_calEntry == null || _calExit == null || _field == null) {
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

  @override
  Widget build(BuildContext context) {
    final ready = _calEntry != null && _calExit != null && _field != null;

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
              // Intro card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Como usar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    SizedBox(height: 8),
                    Text('1. Fotografe o painel de calibração na entrada do campo\n'
                         '2. Fotografe o painel de calibração na saída do campo\n'
                         '3. Fotografe a planta ou área a analisar',
                         style: TextStyle(fontSize: 13, height: 1.6)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Photo slots
              _PhotoSlot(
                label: 'Painel — Entrada',
                icon: Icons.login,
                file: _calEntry,
                onTap: () => _pick('entry'),
              ),
              const SizedBox(height: 12),
              _PhotoSlot(
                label: 'Painel — Saída',
                icon: Icons.logout,
                file: _calExit,
                onTap: () => _pick('exit'),
              ),
              const SizedBox(height: 12),
              _PhotoSlot(
                label: 'Foto da Planta / Área',
                icon: Icons.grass,
                file: _field,
                onTap: () => _pick('field'),
              ),
              const SizedBox(height: 28),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              if (_processing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2E7D32)),
                      SizedBox(height: 12),
                      Text('Calculando VARI...', style: TextStyle(color: Color(0xFF2E7D32))),
                    ],
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: ready ? _analyze : null,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Analisar VARI'),
                ),
            ],
          ),
        ),
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
        height: 90,
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
            // Thumbnail or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
              child: taken
                  ? Image.file(file!, width: 90, height: 90, fit: BoxFit.cover)
                  : Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey.shade200,
                      child: Icon(icon, size: 36, color: Colors.grey.shade400),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: taken ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                    )),
                  const SizedBox(height: 4),
                  Text(
                    taken ? 'Foto capturada ✓' : 'Toque para fotografar',
                    style: TextStyle(
                      fontSize: 12,
                      color: taken ? const Color(0xFF43A047) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                taken ? Icons.check_circle : Icons.camera_alt_outlined,
                color: taken ? const Color(0xFF2E7D32) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
