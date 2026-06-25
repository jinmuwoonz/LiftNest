import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/workout.dart';
import '../../../core/theme/app_theme.dart';
import 'workout_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public state — MainScreen calls showAddWorkoutSheet() via GlobalKey
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutContent extends StatefulWidget {
  const WorkoutContent({super.key});

  @override
  State<WorkoutContent> createState() => WorkoutContentState();
}

class WorkoutContentState extends State<WorkoutContent> {
  List<Workout> _workouts = [];
  final Map<int, int> _exerciseCounts = {};
  bool _isLoading = true;

  static const List<String> _kDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final workouts = await DatabaseHelper.instance.getAllWorkouts();
    final counts = <int, int>{};
    for (final w in workouts) {
      counts[w.id!] =
          await DatabaseHelper.instance.getExerciseCountForWorkout(w.id!);
    }
    if (!mounted) return;
    // Sort: Any day (null) first, then Mon → Sun order.
    workouts.sort((a, b) {
      final ai = a.day == null ? -1 : _kDays.indexOf(a.day!);
      final bi = b.day == null ? -1 : _kDays.indexOf(b.day!);
      return ai.compareTo(bi);
    });
    setState(() {
      _workouts = workouts;
      _exerciseCounts
        ..clear()
        ..addAll(counts);
      _isLoading = false;
    });
  }

  // ── Public FAB entry ─────────────────────────────────────────────────────
  void showAddWorkoutSheet() => _showSheet();

  // ── Add / Edit bottom sheet ──────────────────────────────────────────────
  Future<void> _showSheet({Workout? workout}) async {
    final nameCtrl = TextEditingController(text: workout?.name ?? '');
    final descCtrl = TextEditingController(text: workout?.description ?? '');
    String? selectedDay = workout?.day;
    final formKey = GlobalKey<FormState>();
    final isEdit = workout != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _SheetContainer(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Handle(),
                  const SizedBox(height: 20),
                  Text(
                    isEdit ? 'Edit Workout' : 'Create Workout',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Chest Day'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 20),

                  // Day selector
                  Text('Day',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DayChip(
                        label: 'Any day',
                        selected: selectedDay == null,
                        onTap: () =>
                            setSheet(() => selectedDay = null),
                      ),
                      ..._kDays.map((d) => _DayChip(
                            label: d,
                            selected: selectedDay == d,
                            onTap: () =>
                                setSheet(() => selectedDay = d),
                          )),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  _GradBtn(
                    label: isEdit ? 'Save Changes' : 'Create Workout',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final name = nameCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      if (isEdit) {
                        await DatabaseHelper.instance.updateWorkout(
                          workout.copyWith(
                            name: name,
                            description: desc.isEmpty ? '' : desc,
                            day: selectedDay,
                          ),
                        );
                      } else {
                        await DatabaseHelper.instance.insertWorkout(
                          Workout(
                            name: name,
                            description: desc.isEmpty ? '' : desc,
                            day: selectedDay,
                          ),
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete ───────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(Workout w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text(
            'Delete "${w.name}"?\nAll exercises inside will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteWorkout(w.id!);
      _load();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_workouts.isEmpty) return _EmptyWorkout();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
        itemCount: _workouts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final w = _workouts[i];
          return _WorkoutCard(
            workout: w,
            exerciseCount: _exerciseCounts[w.id!] ?? 0,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        WorkoutDetailScreen(workout: w)),
              );
              _load();
            },
            onEdit: () => _showSheet(workout: w),
            onDelete: () => _confirmDelete(w),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyWorkout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                  color: AppColors.accentDim, shape: BoxShape.circle),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('No Workouts Yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Tap the + button to create\nyour first workout.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Workout card
// ─────────────────────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final int exerciseCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkoutCard({
    required this.workout,
    required this.exerciseCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = workout.name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.accent.withValues(alpha: 0.07),
        highlightColor: AppColors.accent.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: AppColors.gradientBox(radius: 14),
                child: Center(
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(workout.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (workout.day != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentDim,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              workout.day!.substring(0, 3),
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      workout.description?.isNotEmpty == true
                          ? workout.description!
                          : '$exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 3-dot menu
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert,
                    color: AppColors.textMuted, size: 20),
                itemBuilder: (_) => [
                  _mi('edit', Icons.edit_outlined, 'Edit',
                      AppColors.textPrimary),
                  _mi('delete', Icons.delete_outline, 'Delete',
                      AppColors.error),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _mi(
      String val, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: val,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sheet sub-widgets (private)
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final Widget child;
  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: child,
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _GradBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GradBtn({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: AppColors.gradientBox(radius: 14),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
