import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/planner_model.dart';
import '../../providers/planner_provider.dart';
//import '../../providers/groups_provider.dart';
import '../../../core/utils/back_handler.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _filterDate = DateTime.now();
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final plannerAsync = ref.watch(plannerProvider);

    return BackHandler(
        backRoute: '/dashboard',
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('Planeador',
                style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => _showAll = !_showAll),
                child: Text(
                  _showAll ? 'Ver día' : 'Ver todo',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nueva actividad'),
            onPressed: () => _showEntryDialog(context, ref, null),
          ),
          body: plannerAsync.when(
            data: (entries) {
              // Filtrar por fecha si no es "ver todo"
              final filtered = _showAll
                  ? entries
                  : entries
                      .where((e) =>
                          e.date.year == _filterDate.year &&
                          e.date.month == _filterDate.month &&
                          e.date.day == _filterDate.day)
                      .toList();

              return Column(
                children: [
                  // Selector de fecha (solo visible en modo día)
                  if (!_showAll) _datePicker(context),
                  // Lista
                  Expanded(
                    child: filtered.isEmpty
                        ? _emptyState()
                        : _showAll
                            ? _groupedList(entries)
                            : _dayList(filtered),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ));
  }

  Widget _datePicker(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() =>
                _filterDate = _filterDate.subtract(const Duration(days: 1))),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('es', 'MX'),
              );
              if (picked != null) setState(() => _filterDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE d MMM yyyy', 'es_MX').format(_filterDate),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(
                () => _filterDate = _filterDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _dayList(List<PlannerModel> entries) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, i) => _entryCard(context, ref, entries[i]),
    );
  }

  Widget _groupedList(List<PlannerModel> entries) {
    // Agrupar por fecha
    final Map<String, List<PlannerModel>> grouped = {};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, i) {
        final key = sortedKeys[i];
        final dayEntries = grouped[key]!;
        final date = DateTime.parse(key);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                DateFormat('EEEE d \'de\' MMMM', 'es_MX').format(date),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 14),
              ),
            ),
            ...dayEntries.map((e) => _entryCard(context, ref, e)),
          ],
        );
      },
    );
  }

  Widget _entryCard(BuildContext context, WidgetRef ref, PlannerModel entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: entry.isCompleted ? Colors.grey[300]! : AppColors.accent,
            width: 5,
          ),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
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
            size: 28,
          ),
        ),
        title: Text(
          entry.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: entry.isCompleted ? TextDecoration.lineThrough : null,
            color: entry.isCompleted ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null && entry.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(entry.description!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM yyyy', 'es_MX').format(entry.date),
              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.secondary, size: 20),
              onPressed: () => _showEntryDialog(context, ref, entry),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 20),
              onPressed: () => _confirmDelete(context, ref, entry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _showAll
                ? 'No hay actividades planeadas'
                : 'Sin actividades para este día',
            style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text('Toca el botón para agregar una',
              style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _showEntryDialog(
      BuildContext context, WidgetRef ref, PlannerModel? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDate = existing?.date ?? _filterDate;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Nueva actividad' : 'Editar actividad',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Título de la actividad',
                    prefixIcon:
                        const Icon(Icons.event_note, color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    prefixIcon:
                        const Icon(Icons.notes, color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Selector de fecha
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      locale: const Locale('es', 'MX'),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('d MMM yyyy', 'es_MX')
                              .format(selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = ref.read(plannerRepositoryProvider)!;
                if (existing == null) {
                  await repo.addEntry(PlannerModel(
                    id: '',
                    date: selectedDate,
                    title: titleCtrl.text.trim(),
                    description:
                        descCtrl.text.isEmpty ? null : descCtrl.text.trim(),
                  ));
                } else {
                  await repo.updateEntry(existing.copyWith(
                    title: titleCtrl.text.trim(),
                    description:
                        descCtrl.text.isEmpty ? null : descCtrl.text.trim(),
                  ));
                }
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: Text(existing == null ? 'Agregar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, PlannerModel entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar actividad'),
        content: Text('¿Eliminar "${entry.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(plannerRepositoryProvider)!.deleteEntry(entry.id);
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
