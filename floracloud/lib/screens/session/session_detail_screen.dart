import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/session_status_badge.dart';
import '../../widgets/vari_indicator.dart';

class SessionDetailScreen extends StatelessWidget {
  final FieldSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, _) {
        final current = provider.getById(session.id) ?? session;
        return Scaffold(
          appBar: AppBar(
            title: Text(current.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar',
                onPressed: provider.loadSessions,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(context, current),
              const SizedBox(height: 16),
              _buildInfoCard(context, current),
              const SizedBox(height: 16),
              if (current.variResult != null) ...[
                _buildResultsPreviewCard(context, current),
                const SizedBox(height: 16),
              ],
              _buildActionsCard(context, current),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, FieldSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status da sessão',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textLight)),
                      const SizedBox(height: 6),
                      SessionStatusBadge(status: session.status),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Parcela',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textLight)),
                    const SizedBox(height: 4),
                    Text(
                      '${session.plotSizeMeters.toInt()}×${session.plotSizeMeters.toInt()}m',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (session.status == SessionStatus.processing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                backgroundColor: AppTheme.backgroundLight,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: 6),
              const Text('Pipeline FloraCloud em execução...',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMedium)),
            ],
            if (session.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.errorColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.errorColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, FieldSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.info_outline, title: 'Informações'),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Criada em',
              value: DateFormat('dd/MM/yyyy HH:mm').format(session.createdAt),
            ),
            if (session.location != null)
              _InfoRow(
                icon: Icons.place_outlined,
                label: 'Local',
                value: session.location!,
              ),
            if (session.description != null)
              _InfoRow(
                icon: Icons.notes,
                label: 'Descrição',
                value: session.description!,
              ),
            _InfoRow(
              icon: Icons.photo_library_outlined,
              label: 'Fotos de campo',
              value: '${session.photoCount}',
            ),
            _InfoRow(
              icon: Icons.tune,
              label: 'Fotos de calibração',
              value: '${session.calibrationPhotos}',
            ),
            _InfoRow(
              icon: session.gpsMode == GpsMode.cellphone
                  ? Icons.smartphone
                  : Icons.satellite_alt,
              label: 'Modo GPS',
              value: session.gpsMode == GpsMode.cellphone
                  ? 'GPS do celular'
                  : 'GPS Geodésico',
            ),
            if (session.gpsCoordinate != null)
              _InfoRow(
                icon: Icons.gps_fixed,
                label: 'Coordenadas',
                value: session.gpsCoordinate.toString(),
              ),
            if (session.serverJobId != null)
              _InfoRow(
                icon: Icons.tag,
                label: 'Job ID',
                value: session.serverJobId!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPreviewCard(BuildContext context, FieldSession session) {
    final result = session.variResult!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
                icon: Icons.analytics_outlined, title: 'Resultado VARI'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                VARIIndicator(value: result.mean, size: 90),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatItem(label: 'Média', value: result.mean.toStringAsFixed(4)),
                    _StatItem(label: 'Mediana', value: result.median.toStringAsFixed(4)),
                    _StatItem(label: 'Desv. Padrão', value: result.stdDev.toStringAsFixed(4)),
                    _StatItem(
                        label: 'Pontos 3D',
                        value: result.pointCount.toString()),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.pushNamed(
                  'results',
                  pathParameters: {'id': session.id},
                  extra: session,
                ),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Ver relatório completo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context, FieldSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.play_arrow, title: 'Ações'),
            const SizedBox(height: 12),
            if (session.canCapture)
              _ActionButton(
                icon: Icons.camera_alt,
                label: 'Capturar Fotos',
                description:
                    'Protocolo: painel de calibração + fotos da parcela',
                color: AppTheme.primaryGreen,
                onTap: () => context.pushNamed(
                  'capture',
                  pathParameters: {'id': session.id},
                  extra: session,
                ),
              ),
            if (session.canUpload) ...[
              if (session.canCapture) const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.cloud_upload,
                label: 'Enviar e Processar',
                description: 'Upload das fotos + execução do pipeline SfM/VARI',
                color: Colors.deepPurple,
                onTap: () => context.pushNamed(
                  'upload',
                  pathParameters: {'id': session.id},
                  extra: session,
                ),
              ),
            ],
            if (session.hasResults) ...[
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.analytics,
                label: 'Ver Resultados',
                description: 'Nuvem 3D, mapa VARI, análise estratificada',
                color: Colors.teal,
                onTap: () => context.pushNamed(
                  'results',
                  pathParameters: {'id': session.id},
                  extra: session,
                ),
              ),
            ],
            if (!session.canCapture && !session.canUpload && !session.hasResults)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    session.status == SessionStatus.processing
                        ? 'Aguardando conclusão do processamento...'
                        : 'Nenhuma ação disponível neste momento.',
                    style: const TextStyle(color: AppTheme.textLight),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textLight),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMedium)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textLight)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMedium)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
