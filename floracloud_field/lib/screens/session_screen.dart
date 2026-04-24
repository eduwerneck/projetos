import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../engine/vari_engine.dart';
import 'session_results_screen.dart';

class SessionScreen extends StatefulWidget {
  final CalibrationFactors calibration;
  const SessionScreen({super.key, required this.calibration});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final List<File> _fieldPhotos = [];
  bool _processing = false;
  final _picker = ImagePicker();

  Future<void> _addPhoto() async {
    final source = await _showSourceDialog();
    if (source == null) return;
    final xFile = await _picker.pickImage(source: source, imageQuality: 95);
    if (xFile == null) return;
    setState(() => _fieldPhotos.add(File(xFile.path)));
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

  void _removePhoto(int index) {
    setState(() => _fieldPhotos.removeAt(index));
  }

  Future<void> _analyze() async {
    if (_fieldPhotos.isEmpty) return;
    setState(() => _processing = true);
    try {
      final results = <VARIResult>[];
      for (final photo in _fieldPhotos) {
        final result = await computeVARI(photo, widget.calibration);
        results.add(result);
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionResultsScreen(
            results: results,
            photos: _fieldPhotos,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao analisar: $e')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos de Campo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Photo grid
            Expanded(
              child: _fieldPhotos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                            size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Adicione as fotos do campo',
                            style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          Text('A mesma calibração será usada para todas',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _fieldPhotos.length,
                      itemBuilder: (context, index) => _PhotoTile(
                        file: _fieldPhotos[index],
                        index: index,
                        onRemove: () => _removePhoto(index),
                      ),
                    ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                children: [
                  if (_fieldPhotos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${_fieldPhotos.length} foto${_fieldPhotos.length > 1 ? 's' : ''} adicionada${_fieldPhotos.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _processing ? null : _addPhoto,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Adicionar foto'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_fieldPhotos.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _processing
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                              : FilledButton.icon(
                                  onPressed: _analyze,
                                  icon: const Icon(Icons.analytics),
                                  label: const Text('Analisar'),
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;

  const _PhotoTile({required this.file, required this.index, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 4, left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
