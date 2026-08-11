import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gestor_escolar_app/data/models/planner_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/planner_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: unused_local_variable
    final user = ref.watch(authStateProvider).value;
    final groupsAsync = ref.watch(groupsProvider);
    final plannerAsync = ref.watch(plannerProvider);
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE d \'de\' MMMM', 'es_MX').format(today);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Control de Clase',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            _greeting(ref, dateStr),
            const SizedBox(height: 20),

            // Tarjetas resumen
            groupsAsync.when(
              data: (groups) => _summaryCards(context, groups.length),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),

            // Accesos rápidos
            Text('Accesos rápidos',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _quickAccess(context, ref),
            const SizedBox(height: 24),

            // Actividades de hoy
            Text('Actividades de hoy',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            plannerAsync.when(
              data: (entries) {
                final todayEntries = entries
                    .where((e) =>
                        e.date.year == today.year &&
                        e.date.month == today.month &&
                        e.date.day == today.day)
                    .toList();
                if (todayEntries.isEmpty) {
                  return _emptyPlanner(context);
                }
                return Column(
                  children:
                      todayEntries.map((e) => _plannerTile(e, ref)).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _greeting(WidgetRef ref, String date) {
    // Obtener nombre desde Firestore directamente
    final user = ref.watch(authStateProvider).value;

    return FutureBuilder<String>(
      future: _getUserName(user?.uid),
      builder: (context, snap) {
        final name = snap.data ??
            user?.displayName ??
            user?.email?.split('@').first ??
            'Profesor';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buenos días,',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 14)),
              Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(date,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Future<String> _getUserName(String? uid) async {
    if (uid == null) return 'Profesor';
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['displayName'] ?? 'Profesor';
    } catch (_) {
      return 'Profesor';
    }
  }

  Widget _summaryCards(BuildContext context, int groupCount) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.group,
            label: 'Grupos',
            value: '$groupCount',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.today,
            label: 'Hoy',
            value: DateFormat('d MMM', 'es_MX').format(DateTime.now()),
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  //aqui
  Widget _quickAccess(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final items = [
      (
        icon: Icons.group,
        label: 'Grupos',
        color: AppColors.primary,
        onTap: () => context.go('/groups'),
      ),
      (
        icon: Icons.check_circle_outline,
        label: 'Asistencia',
        color: AppColors.accent,
        onTap: () => _goToGroupPicker(context, ref, groupsAsync, 'attendance'),
      ),
      (
        icon: Icons.grade,
        label: 'Calificaciones',
        color: AppColors.warning,
        onTap: () => _goToGroupPicker(context, ref, groupsAsync, 'grades'),
      ),
      (
        icon: Icons.calendar_month,
        label: 'Planeador',
        color: AppColors.secondary,
        onTap: () => context.go('/planner'),
      ),
      (
        icon: Icons.upload_file,
        label: 'Exportar',
        color: Colors.purple,
        onTap: () => context.go('/export'),
      ),
      (
        icon: Icons.festival,
        label: 'Taller',
        color: AppColors.accent,
        onTap: () => context.go('/workshop'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: items.map((item) {
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: item.color.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: item.color, size: 32),
                const SizedBox(height: 8),
                Text(item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _goToGroupPicker(BuildContext context, WidgetRef ref,
      AsyncValue groupsAsync, String destination) {
    final groups = groupsAsync.maybeWhen(
      data: (g) => g,
      orElse: () => [],
    );

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero crea un grupo'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (groups.length == 1) {
      final route = destination == 'attendance'
          ? '/attendance/${groups[0].id}'
          : '/grades/${groups[0].id}';
      context.go(route);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ← clave para que no se corte
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9, // ← puede expandirse hasta 90% de pantalla
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    destination == 'attendance'
                        ? '¿A qué grupo tomar asistencia?'
                        : '¿A qué grupo registrar calificaciones?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),
                // Lista scrollable
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final g = groups[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            g.name.isNotEmpty ? g.name[0] : 'G',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(g.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(g.subject),
                        onTap: () {
                          Navigator.of(ctx, rootNavigator: true).pop();
                          final route = destination == 'attendance'
                              ? '/attendance/${g.id}'
                              : '/grades/${g.id}';
                          context.go(route);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _emptyPlanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text('Sin actividades para hoy',
              style: TextStyle(color: Colors.grey[500])),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/planner'),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Widget _plannerTile(PlannerModel entry, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: entry.isCompleted ? Colors.grey[300]! : AppColors.accent,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              await ref
                  .read(plannerRepositoryProvider)!
                  .updateEntry(entry.copyWith(isCompleted: !entry.isCompleted));
            },
            child: Icon(
              entry.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: entry.isCompleted ? Colors.grey : AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.title,
              style: TextStyle(
                decoration:
                    entry.isCompleted ? TextDecoration.lineThrough : null,
                color: entry.isCompleted ? Colors.grey : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
