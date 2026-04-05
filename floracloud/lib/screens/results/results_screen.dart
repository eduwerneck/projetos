import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../config/app_theme.dart';
import '../../widgets/vari_indicator.dart';
import '../../providers/settings_provider.dart';

class ResultsScreen extends StatelessWidget {
  final FieldSession session;

  const ResultsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final result = session.variResult;

    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados — ${session.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Exportar',
            onPressed: () => _showExportOptions(context),
          ),
        ],
      ),
      body: result == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 64, color: AppTheme.textLight),
                  SizedBox(height: 16),
                  Text('Resultados ainda não disponíveis.',
                      style: TextStyle(color: AppTheme.textMedium)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildVARISummaryCard(result),
                const SizedBox(height: 16),
                _buildVariMapCard(context),
                const SizedBox(height: 16),
                _buildStatisticsCard(result),
                const SizedBox(height: 16),
                if (result.stratifiedByHeight.isNotEmpty)
                  _buildStratifiedChart(result),
                const SizedBox(height: 16),
                _buildSessionInfoCard(),
                const SizedBox(height: 16),
                _buildExportCard(context, result),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildVARISummaryCard(VARIResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Índice VARI Médio',
              style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            VARIIndicator(value: result.mean, size: 120),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                result.vigorLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Parcela ${session.plotSizeMeters.toInt()}×${session.plotSizeMeters.toInt()}m · '
              '${result.pointCount} pontos 3D',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariMapCard(BuildContext context) {
    final serverUrl = context.read<SettingsProvider>().serverUrl;
    final mapUrl = '$serverUrl/api/sessions/${session.id}/vari-map';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.image_outlined,
              title: 'Mapa VARI — Imagem Colorida',
            ),
            const SizedBox(height: 6),
            const Text(
              'Vermelho = estresse  ·  Amarelo = neutro  ·  Verde = vigor',
              style: TextStyle(fontSize: 11, color: AppTheme.textLight),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                mapUrl,
                fit: BoxFit.contain,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(height: 8),
                        const Text('Carregando mapa...',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textLight)),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stack) => Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined,
                          color: AppTheme.textLight, size: 32),
                      SizedBox(height: 8),
                      Text('Mapa não disponível ainda',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(VARIResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
                icon: Icons.analytics_outlined,
                title: 'Estatísticas VARI'),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _StatCard(
                    label: 'Média',
                    value: result.mean.toStringAsFixed(4),
                    icon: Icons.bar_chart,
                    color: AppTheme.primaryGreen),
                _StatCard(
                    label: 'Mediana',
                    value: result.median.toStringAsFixed(4),
                    icon: Icons.waterfall_chart,
                    color: Colors.teal),
                _StatCard(
                    label: 'Desv. Padrão',
                    value: result.stdDev.toStringAsFixed(4),
                    icon: Icons.show_chart,
                    color: Colors.indigo),
                _StatCard(
                    label: 'Mínimo',
                    value: result.min.toStringAsFixed(4),
                    icon: Icons.arrow_downward,
                    color: Colors.orange),
                _StatCard(
                    label: 'Máximo',
                    value: result.max.toStringAsFixed(4),
                    icon: Icons.arrow_upward,
                    color: AppTheme.accentGreen),
                _StatCard(
                    label: 'Pontos 3D',
                    value: _formatNumber(result.pointCount),
                    icon: Icons.scatter_plot,
                    color: Colors.deepPurple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStratifiedChart(VARIResult result) {
    final entries = result.stratifiedByHeight.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final barGroups = entries.asMap().entries.map((e) {
      final index = e.key;
      final value = e.value.value;
      final color = _variColor(value);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: color,
            width: 22,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.layers_outlined,
              title: 'VARI por Estrato Vertical',
            ),
            const SizedBox(height: 6),
            const Text(
              'Análise do índice por altura na nuvem de pontos',
              style: TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 0.1,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(2),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textLight),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              entries[i].key,
                              style: const TextStyle(
                                  fontSize: 9, color: AppTheme.textLight),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${entries[group.x].key}\nVARI: ${rod.toY.toStringAsFixed(4)}',
                        const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
                icon: Icons.map_outlined, title: 'Informações da Parcela'),
            const SizedBox(height: 12),
            _InfoRow('Nome', session.name),
            if (session.location != null)
              _InfoRow('Local', session.location!),
            _InfoRow('Área',
                '${session.plotSizeMeters.toInt()}×${session.plotSizeMeters.toInt()}m (${(session.plotSizeMeters * session.plotSizeMeters).toInt()} m²)'),
            _InfoRow('Modo GPS',
                session.gpsMode == GpsMode.cellphone ? 'Celular' : 'Geodésico'),
            if (session.gpsCoordinate != null)
              _InfoRow('Coordenadas', session.gpsCoordinate.toString()),
            if (session.variResult?.processedAt != null)
              _InfoRow(
                  'Processado em',
                  DateFormat('dd/MM/yyyy HH:mm')
                      .format(session.variResult!.processedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, VARIResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
                icon: Icons.download, title: 'Exportar Dados'),
            const SizedBox(height: 12),
            _ExportButton(
              icon: Icons.view_in_ar,
              label: 'Nuvem de pontos (.ply)',
              description: 'Compatível com CloudCompare e QGIS',
              onTap: () => _showDownloadInfo(
                  context, 'Nuvem de pontos .ply', result.plyFilePath),
            ),
            const SizedBox(height: 10),
            _ExportButton(
              icon: Icons.description,
              label: 'Relatório JSON',
              description: 'Metadados completos da sessão + estatísticas VARI',
              onTap: () => _showDownloadInfo(
                  context, 'Relatório JSON', result.reportJsonPath),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Exportar',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.view_in_ar,
                  color: AppTheme.primaryGreen),
              title: const Text('Nuvem de pontos (.ply)'),
              subtitle: const Text('Para CloudCompare / QGIS'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Iniciando download do .ply...'),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.description,
                  color: Colors.indigo),
              title: const Text('Relatório JSON'),
              subtitle: const Text('Metadados e estatísticas completas'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Iniciando download do relatório...'),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloadInfo(
      BuildContext context, String name, String? path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: Text(path != null
            ? 'Arquivo disponível em:\n$path'
            : 'Arquivo disponível no servidor. Use o endereço de download da API.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Color _variColor(double value) {
    if (value >= 0.3) return const Color(0xFF1B5E20);
    if (value >= 0.2) return const Color(0xFF2E7D32);
    if (value >= 0.1) return const Color(0xFF43A047);
    if (value >= 0.0) return const Color(0xFFA5D6A7);
    if (value >= -0.1) return const Color(0xFFFFF176);
    return const Color(0xFFEF5350);
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textLight)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textLight)),
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

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textLight)),
                ],
              ),
            ),
            const Icon(Icons.download,
                color: AppTheme.primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }
}
