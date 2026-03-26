import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_theme.dart';
import '../../widgets/session_status_badge.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().loadSessions();
      context.read<SettingsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forest, color: Colors.white.withValues(alpha: 0.9), size: 24),
            const SizedBox(width: 8),
            const Text('FloraCloud'),
          ],
        ),
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                Icons.circle,
                size: 14,
                color: settings.isConnected ? AppTheme.accentGreen : Colors.red,
              ),
              tooltip: settings.isConnected ? 'Servidor conectado' : 'Servidor offline',
              onPressed: () => _showServerSettings(context, settings),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => _showServerSettings(
              context,
              context.read<SettingsProvider>(),
            ),
          ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: provider.loadSessions,
            color: AppTheme.primaryGreen,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildSummaryCards(provider)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'Sessões de Campo',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                    ),
                  ),
                ),
                if (provider.sessions.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _SessionCard(
                          session: provider.sessions[index],
                          onTap: () => context.pushNamed(
                            'session-detail',
                            pathParameters: {'id': provider.sessions[index].id},
                            extra: provider.sessions[index],
                          ),
                          onDelete: () => _confirmDelete(
                            context,
                            provider,
                            provider.sessions[index],
                          ),
                        ),
                        childCount: provider.sessions.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed('new-session'),
        icon: const Icon(Icons.add),
        label: const Text('Nova Parcela'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildSummaryCards(SessionProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _SummaryCard(
            label: 'Total',
            value: '${provider.totalSessions}',
            icon: Icons.map_outlined,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Concluídas',
            value: '${provider.completedSessions}',
            icon: Icons.check_circle_outline,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Em andamento',
            value: '${provider.processingSessions}',
            icon: Icons.autorenew,
            color: AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forest, size: 72, color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Nenhuma sessão ainda',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textMedium,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crie sua primeira parcela de campo\npara começar o mapeamento 3D',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textLight),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.pushNamed('new-session'),
            icon: const Icon(Icons.add),
            label: const Text('Criar Primeira Parcela'),
          ),
        ],
      ),
    );
  }

  void _showServerSettings(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.serverUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar Servidor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL do servidor',
                hintText: 'http://192.168.1.100:8000',
                prefixIcon: Icon(Icons.cloud),
              ),
            ),
            const SizedBox(height: 12),
            if (settings.isConnected)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 16),
                  SizedBox(width: 6),
                  Text('Servidor conectado', style: TextStyle(color: AppTheme.primaryGreen)),
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 16),
                  SizedBox(width: 6),
                  Text('Servidor offline', style: TextStyle(color: Colors.red)),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await settings.setServerUrl(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, SessionProvider provider, FieldSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir sessão?'),
        content: Text('Tem certeza que deseja excluir "${session.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              provider.deleteSession(session.id);
              Navigator.pop(ctx);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final FieldSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  SessionStatusBadge(status: session.status),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textLight),
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (session.location != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(
                      session.location!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLight),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.photo_library_outlined,
                    label: '${session.photoCount} fotos',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.straighten,
                    label: '${session.plotSizeMeters.toInt()}×${session.plotSizeMeters.toInt()}m',
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy').format(session.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textLight),
                  ),
                ],
              ),
              if (session.variResult != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.grass,
                        size: 14, color: AppTheme.primaryGreen),
                    const SizedBox(width: 4),
                    Text(
                      'VARI médio: ${session.variResult!.mean.toStringAsFixed(3)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.variResult!.vigorLabel,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMedium),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMedium),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }
}
