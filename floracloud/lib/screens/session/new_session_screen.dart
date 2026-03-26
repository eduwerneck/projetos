import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../services/gps_service.dart';
import '../../config/app_theme.dart';

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  GpsMode _gpsMode = GpsMode.cellphone;
  GpsCoordinate? _gpsCoordinate;
  double _plotSize = 30.0;
  bool _isLoadingGps = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Parcela')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSection(
              icon: Icons.info_outline,
              title: 'Informações Básicas',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Parcela *',
                      hintText: 'Ex: Parcela A - Subosque Norte',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nome obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                      hintText: 'Condições de campo, espécies observadas...',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      labelText: 'Local / Sítio',
                      hintText: 'Ex: Reserva Florestal da ESALQ - Talhão 5',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.straighten,
              title: 'Parâmetros da Parcela',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tamanho da parcela: ${_plotSize.toInt()} × ${_plotSize.toInt()} metros',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Slider(
                    value: _plotSize,
                    min: 10,
                    max: 100,
                    divisions: 18,
                    label: '${_plotSize.toInt()}m',
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (v) => setState(() => _plotSize = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Padrão FloraCloud: 30×30m (900 m²)',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textLight),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _plotSize = 30.0),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24)),
                        child: const Text('Padrão',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.gps_fixed,
              title: 'Georreferenciamento',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modo GPS',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMedium),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _GpsChip(
                        label: 'GPS do Celular',
                        icon: Icons.smartphone,
                        selected: _gpsMode == GpsMode.cellphone,
                        onTap: () =>
                            setState(() => _gpsMode = GpsMode.cellphone),
                      ),
                      const SizedBox(width: 8),
                      _GpsChip(
                        label: 'GPS Geodésico',
                        icon: Icons.satellite_alt,
                        selected: _gpsMode == GpsMode.geodetic,
                        onTap: () =>
                            setState(() => _gpsMode = GpsMode.geodetic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_gpsMode == GpsMode.cellphone) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _gpsCoordinate == null
                              ? OutlinedButton.icon(
                                  onPressed: _isLoadingGps
                                      ? null
                                      : _captureGps,
                                  icon: _isLoadingGps
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(_isLoadingGps
                                      ? 'Obtendo localização...'
                                      : 'Capturar Localização'),
                                )
                              : _buildGpsResult(),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Coordenadas serão extraídas dos metadados EXIF das fotos ou inseridas manualmente no servidor.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Criar Parcela'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildGpsResult() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gpsCoordinate.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (_gpsCoordinate?.accuracy != null)
                  Text(
                    'Precisão: ±${_gpsCoordinate!.accuracy!.toStringAsFixed(1)}m',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textLight),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: _captureGps,
            tooltip: 'Recapturar',
          ),
        ],
      ),
    );
  }

  Future<void> _captureGps() async {
    setState(() => _isLoadingGps = true);
    final coords = await GpsService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _gpsCoordinate = coords;
        _isLoadingGps = false;
      });
      if (coords == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter localização. Verifique as permissões.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final session = FieldSession(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      gpsCoordinate: _gpsCoordinate,
      gpsMode: _gpsMode,
      createdAt: DateTime.now(),
      plotSizeMeters: _plotSize,
    );

    await context.read<SessionProvider>().addSession(session);

    if (mounted) {
      setState(() => _isSaving = false);
      context.pushReplacementNamed(
        'session-detail',
        pathParameters: {'id': session.id},
        extra: session,
      );
    }
  }
}

class _GpsChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GpsChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryGreen.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppTheme.primaryGreen : AppTheme.textMedium),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppTheme.primaryGreen : AppTheme.textMedium,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
