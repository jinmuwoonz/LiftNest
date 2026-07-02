import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/exercise_workout.dart';
import '../../../core/models/exercise_inventory.dart';
import '../../../core/models/inventory.dart';
import '../../../core/models/weight.dart';
import '../../../core/models/workout.dart';
import '../../../core/services/plate_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/barbell_visualizer.dart';
import 'add_exercise_screen.dart';
import '../../../core/services/preferences_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data class
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseRow {
  final Exercise exercise;
  final List<Inventory> inventories;
  final List<ExerciseInventory> exerciseInventories;
  final PlateResult? pooledResult;
  final List<PlateResult>? individualResults;
  final bool isManual;

  const _ExerciseRow({
    required this.exercise,
    required this.inventories,
    this.exerciseInventories = const [],
    this.pooledResult,
    this.individualResults,
    this.isManual = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;
  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;
  List<_ExerciseRow> _exercises = [];
  bool _isLoading = true;
  bool _useKg = true;
  bool _fabExpanded = false;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _useKg = await PreferencesService.instance.getUseKg();
    await _loadExercises();
  }

  // ── Load ─────────────────────────────────────────────────────────────────
  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);

    final exercises =
        await DatabaseHelper.instance.getExercisesForWorkout(_workout.id!);
    final rows = <_ExerciseRow>[];

    for (final ex in exercises) {
      final invs =
          await DatabaseHelper.instance.getInventoriesForExercise(ex.id!);

      PlateResult? pooledResult;
      List<PlateResult>? individualResults;
      bool isManual = false;

      if (ex.needsWeight) {
        if (ex.poolInventories || invs.length <= 1) {
          isManual = ex.manualPlatesJson != null;
          if (isManual) {
            try {
              final manualRaw = jsonDecode(ex.manualPlatesJson!);
              final weights = <Weight>[];
              for (final inv in invs) {
                weights.addAll(await DatabaseHelper.instance.getWeightsForInventory(inv.id!));
              }
              pooledResult = PlateCalculator.calculateManual(manualRaw, weights);
            } catch (_) {}
          } else if (ex.targetWeightKg != null) {
            final weights = <Weight>[];
            for (final inv in invs) {
              weights.addAll(await DatabaseHelper.instance.getWeightsForInventory(inv.id!));
            }
            pooledResult = PlateCalculator.calculate(
              targetWeightKg: ex.targetWeightKg!,
              includeBarWeight: ex.includeBarWeight,
              barWeightKg: ex.barWeightKg ?? 0,
              isDualBar: ex.isDualBar,
              availableWeights: weights,
            );
          }
        } else {
          // Multi-inventory (no pool)
          final eiList = await DatabaseHelper.instance.getExerciseInventories(ex.id!);
          isManual = eiList.any((ei) => ei.manualPlatesJson != null);
          individualResults = [];
          
          final sortedEiList = <ExerciseInventory>[];
          
          for (int i = 0; i < invs.length; i++) {
            final inv = invs[i];
            final ei = eiList.firstWhere((e) => e.inventoryId == inv.id, orElse: () => ExerciseInventory(exerciseId: ex.id!, inventoryId: inv.id!));
            final weights = await DatabaseHelper.instance.getWeightsForInventory(inv.id!);
            
            sortedEiList.add(ei);
            
            if (ei.manualPlatesJson != null) {
              try {
                final manualRaw = jsonDecode(ei.manualPlatesJson!);
                individualResults.add(PlateCalculator.calculateManual(manualRaw, weights));
              } catch (_) {
                individualResults.add(PlateCalculator.calculateManual({}, weights));
              }
            } else if (ei.targetWeightKg != null) {
              individualResults.add(PlateCalculator.calculate(
                targetWeightKg: ei.targetWeightKg!,
                includeBarWeight: ex.includeBarWeight,
                barWeightKg: ex.barWeightKg ?? 0,
                isDualBar: ex.isDualBar,
                availableWeights: weights,
              ));
            } else {
              individualResults.add(PlateCalculator.calculateManual({}, weights));
            }
          }
        }
      }

      rows.add(_ExerciseRow(
        exercise: ex,
        inventories: invs,
        exerciseInventories: ex.poolInventories || invs.length <= 1 ? [] : await DatabaseHelper.instance.getExerciseInventories(ex.id!),
        pooledResult: pooledResult,
        individualResults: individualResults,
        isManual: isManual,
      ));
    }

    if (!mounted) return;
    setState(() {
      _exercises = rows;
      _isLoading = false;
    });
  }

  // ── Navigate to Add / Edit ───────────────────────────────────────────────
  Future<void> _openAddExercise({Exercise? exercise}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddExerciseScreen(
          workoutId: _workout.id!,
          exercise: exercise,
        ),
      ),
    );
    _loadExercises();
  }

  // ── Pick existing exercise ───────────────────────────────────────────────
  Future<void> _openPickExistingExercise() async {
    setState(() => _fabExpanded = false);

    // All exercises already in this workout
    final linked = _exercises.map((r) => r.exercise.id).toSet();
    // All exercises in DB
    final all = await DatabaseHelper.instance.getAllExercises();
    final available = all.where((e) => !linked.contains(e.id)).toList();

    if (!mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other exercises available. Create a new one first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show picker bottom-sheet
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => _SheetContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              const SizedBox(height: 16),
              Text('Add Existing Exercise',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Select an exercise to add to this workout.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final ex = available[i];
                    return ListTile(
                      onTap: () => Navigator.pop(ctx, ex),
                      leading: Container(
                        width: 38, height: 38,
                        decoration: AppColors.gradientBox(radius: 10),
                        child: Center(
                          child: Text(
                            ex.name.trim().split(' ').take(2)
                                .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
                                .join(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      title: Text(ex.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: ex.needsWeight
                          ? (ex.targetWeightKg != null
                              ? Text(
                                  '${_useKg ? _fmtKg(ex.targetWeightKg!) : _fmtKg(ex.targetWeightKg! * 2.20462)} ${_useKg ? 'kg' : 'lb'}  ·  '
                                  '${ex.needsReps ? '${ex.sets ?? '?'} × ${ex.repetitions ?? '?'}' : '${ex.sets ?? '?'} × ${_fmtRest(ex.durationSeconds ?? 0)}'}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 12))
                              : (ex.manualPlatesJson != null
                                  ? Text(
                                      'Manual Plates  ·  '
                                      '${ex.needsReps ? '${ex.sets ?? '?'} × ${ex.repetitions ?? '?'}' : '${ex.sets ?? '?'} × ${_fmtRest(ex.durationSeconds ?? 0)}'}',
                                      style: const TextStyle(
                                          color: AppColors.textMuted, fontSize: 12))
                                  : null))
                          : Text(
                              'Bodyweight  ·  ${ex.needsReps ? '${ex.sets ?? '?'} × ${ex.repetitions ?? '?'}' : '${ex.sets ?? '?'} × ${_fmtRest(ex.durationSeconds ?? 0)}'}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                      trailing: const Icon(Icons.add_circle_outline,
                          color: AppColors.accent),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked != null) {
      await DatabaseHelper.instance.insertExerciseWorkout(
        ExerciseWorkout(exerciseId: picked.id!, workoutId: _workout.id!),
      );
      _loadExercises();
    }
  }

  // ── Delete (unlink) exercise ─────────────────────────────────────────────
  Future<void> _confirmDeleteExercise(_ExerciseRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Exercise'),
        content: Text(
            'Remove "${row.exercise.name}" from this workout?\n\n'
            'The exercise will not be deleted — it can still be added to other workouts.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: AppColors.textMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      final exId = row.exercise.id!;
      // Unlink from this workout.
      await DatabaseHelper.instance.deleteExerciseWorkout(exId, _workout.id!);
      // If not in any other workout, delete the exercise entirely.
      final remaining =
          await DatabaseHelper.instance.getWorkoutCountForExercise(exId);
      if (remaining == 0) {
        await DatabaseHelper.instance.deleteExercise(exId);
      }
      _loadExercises();
    }
  }

  // ── Edit workout metadata ────────────────────────────────────────────────
  Future<void> _editWorkout() async {
    final nameCtrl = TextEditingController(text: _workout.name);
    final descCtrl =
        TextEditingController(text: _workout.description ?? '');
    String? selectedDay = _workout.day;
    final formKey = GlobalKey<FormState>();

    const kDays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];

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
                  Text('Edit Workout',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 20),
                  Text('Day', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _DayChip(label: 'Any day', selected: selectedDay == null,
                          onTap: () => setSheet(() => selectedDay = null)),
                      ...kDays.map((d) => _DayChip(
                            label: d, selected: selectedDay == d,
                            onTap: () => setSheet(() => selectedDay = d),
                          )),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _GradBtn(
                    label: 'Save Changes',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final updated = _workout.copyWith(
                        name: nameCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty
                            ? '' : descCtrl.text.trim(),
                        day: selectedDay,
                      );
                      await DatabaseHelper.instance.updateWorkout(updated);
                      if (!mounted) return;
                      setState(() => _workout = updated);
                      if (ctx.mounted) Navigator.pop(ctx);
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

  // ── Delete workout ───────────────────────────────────────────────────────
  Future<void> _confirmDeleteWorkout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workout'),
        content: Text(
            'Delete "${_workout.name}"? All exercises will be removed.'),
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
      await DatabaseHelper.instance.deleteWorkout(_workout.id!);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_workout.name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            if (_workout.day != null)
              Text(_workout.day!,
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editWorkout();
              if (v == 'delete') _confirmDeleteWorkout();
            },
            icon: const Icon(Icons.more_vert,
                color: AppColors.textPrimary),
            itemBuilder: (_) => [
              _mi('edit', Icons.edit_outlined, 'Edit workout',
                  AppColors.textPrimary),
              _mi('delete', Icons.delete_outline, 'Delete workout',
                  AppColors.error),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _exercises.isEmpty
              ? _EmptyExercise()
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                  itemCount: _exercises.length,
                  onReorderItem: (oldIndex, newIndex) async {
                    final rows = List<_ExerciseRow>.from(_exercises);
                    final moved = rows.removeAt(oldIndex);
                    rows.insert(newIndex, moved);
                    setState(() => _exercises = rows);
                    await DatabaseHelper.instance.updateExerciseOrder(
                      _workout.id!,
                      rows.map((r) => r.exercise.id!).toList(),
                    );
                  },
                  proxyDecorator: (child, index, animation) =>
                      AnimatedBuilder(
                    animation: animation,
                    builder: (ctx, _) => Material(
                      elevation: 8,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    ),
                  ),
                  itemBuilder: (ctx, i) => Padding(
                    key: ValueKey(_exercises[i].exercise.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ExerciseCard(
                      row: _exercises[i],
                      useKg: _useKg,
                      onEdit: () => _openAddExercise(
                          exercise: _exercises[i].exercise),
                      onDelete: () =>
                          _confirmDeleteExercise(_exercises[i]),
                    ),
                  ),
                ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          // ── Mini action: Add existing ────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('Add Existing',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'fab_existing',
                onPressed: _openPickExistingExercise,
                backgroundColor: AppColors.surface,
                child: const Icon(Icons.library_add_outlined,
                    color: AppColors.accent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Mini action: New exercise ────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('New Exercise',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: 'fab_new',
                onPressed: () {
                  setState(() => _fabExpanded = false);
                  _openAddExercise();
                },
                backgroundColor: AppColors.surface,
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.accent, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        // ── Main FAB ──────────────────────────────────────────────────
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: _fabExpanded ? 0.125 : 0,
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
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
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyExercise extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                  color: AppColors.accentDim, shape: BoxShape.circle),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('No exercises yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Tap + to add your first exercise.',
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
// Exercise card
// ─────────────────────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final _ExerciseRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool useKg;

  const _ExerciseCard(
      {required this.row, required this.onEdit, required this.onDelete, required this.useKg});

  @override
  Widget build(BuildContext context) {
    final ex = row.exercise;

    final initials = ex.name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 42, height: 42,
                  decoration: AppColors.gradientBox(radius: 12),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (ex.needsWeight && (row.individualResults == null || row.individualResults!.isEmpty) && ex.targetWeightKg != null && !row.isManual)
                            _Pill('${useKg ? _fmtKg(ex.targetWeightKg!) : _fmtKg(ex.targetWeightKg! * 2.20462)} ${useKg ? 'kg' : 'lb'}'),
                          if (ex.needsWeight && (row.individualResults == null || row.individualResults!.isEmpty) && row.isManual)
                            _Pill('Manual Weight', color: AppColors.accent),
                          if (!ex.needsWeight)
                            _Pill('Bodyweight', color: AppColors.accentDim),
                          if (ex.sets != null || ex.repetitions != null || ex.durationSeconds != null)
                            _Pill(ex.needsReps 
                                ? '${ex.sets ?? '?'} × ${ex.repetitions ?? '?'}' 
                                : '${ex.sets ?? '?'} × ${_fmtRest(ex.durationSeconds ?? 0)}'),
                          if (ex.restTimeSeconds != null)
                            _Pill(_fmtRest(ex.restTimeSeconds!)),
                        ],
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
                    _mi('delete', Icons.delete_outline, 'Remove',
                        AppColors.error),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Barbell visual ────────────────────────────────────────
            if (ex.needsWeight) ...[
              if (row.pooledResult != null) ...[
                _buildResult(context, row.pooledResult!, row.inventories.length == 1 ? row.inventories.first.name : 'Pooled Inventories', ex.isDualBar, isManual: row.isManual, barKg: ex.barWeightKg),
              ] else if (row.individualResults != null && row.individualResults!.isNotEmpty) ...[
                _CarouselVisualizer(
                  results: row.individualResults!,
                  inventories: row.inventories,
                  exerciseInventories: row.exerciseInventories,
                  useKg: useKg,
                ),
              ] else if (!row.isManual)
                const Text('No target weight set',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, PlateResult result, String inventoryName, bool isDualBar, {bool isManual = false, double? barKg}) {
    double finalTotalKg = isManual ? result.perSideKg * (isDualBar ? 2 : 1) : (result.totalLoadedKgPerSide * 2) * (isDualBar ? 2 : 1) + (barKg ?? 0) * (isDualBar ? 2 : 1);
    String totalStr = useKg ? '${_fmtKg(finalTotalKg)} kg' : '${_fmtKg(finalTotalKg * 2.20462)} lb';
    String sideStr = useKg ? '${_fmtKg(result.perSideKg)} kg' : '${_fmtKg(result.perSideKg * 2.20462)} lb';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 78,
          child: BarbellVisualizer(
            result: result,
            compact: true,
            isDualBar: isDualBar,
            drawBar: !isManual,
            useKg: useKg,
          ),
        ),
        const SizedBox(height: 10),
        // Per-side summary
        if (result.isOk)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Icon(Icons.horizontal_split_rounded,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text(
              isManual 
                  ? (isDualBar ? 'Total: $totalStr (Plates total: $sideStr)' : 'Total: $totalStr')
                  : (result.perSideKg > 0
                      ? 'Total: $totalStr (Per side: $sideStr)'
                      : 'Bar only'),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
            const Text('  ·  ',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            const Icon(Icons.inventory_2_outlined,
                size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                inventoryName,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
      ],
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
// Small pill chip
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String text;
  final Color? color;
  const _Pill(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sheet helpers (private)
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
        width: 40, height: 4,
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
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtKg(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  String s = v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

String _fmtRest(int secs) {
  if (secs < 60) return '${secs}s';
  final m = secs ~/ 60;
  final s = secs % 60;
  return s == 0 ? '${m}m' : '${m}m${s}s';
}

class _CarouselVisualizer extends StatefulWidget {
  final List<PlateResult> results;
  final List<Inventory> inventories;
  final List<ExerciseInventory> exerciseInventories;
  final bool useKg;

  const _CarouselVisualizer({
    required this.results,
    required this.inventories,
    required this.exerciseInventories,
    required this.useKg,
  });

  @override
  State<_CarouselVisualizer> createState() => _CarouselVisualizerState();
}

class _CarouselVisualizerState extends State<_CarouselVisualizer> {
  final _pageCtrl = PageController();
  int _curr = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) => setState(() => _curr = idx),
            itemCount: widget.results.length,
            itemBuilder: (ctx, idx) {
              final res = widget.results[idx];
              final inv = widget.inventories[idx];
              // fallback if not found, though it should exist
              final ei = widget.exerciseInventories.firstWhere(
                (e) => e.inventoryId == inv.id,
              );
              final isManual = ei.manualPlatesJson != null;
              final isDualBar = ei.isDualBar ?? false;
              final barKg = ei.barWeightKg ?? 0.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 78,
                    child: BarbellVisualizer(
                      result: res,
                      compact: true,
                      isDualBar: isDualBar,
                      drawBar: !isManual,
                      useKg: widget.useKg,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (ei.targetWeightKg != null && !isManual)
                        _Pill('${widget.useKg ? _fmtKg(ei.targetWeightKg!) : _fmtKg(ei.targetWeightKg! * 2.20462)} ${widget.useKg ? 'kg' : 'lb'}'),
                      if (isManual)
                        _Pill('Manual Weight', color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Per-side summary & Inventory name
                  if (res.isOk)
                    Builder(builder: (context) {
                      double finalTotalKg = isManual ? res.perSideKg * (isDualBar ? 2 : 1) : (res.totalLoadedKgPerSide * 2) * (isDualBar ? 2 : 1) + barKg * (isDualBar ? 2 : 1);
                      String totalStr = widget.useKg ? '${_fmtKg(finalTotalKg)} kg' : '${_fmtKg(finalTotalKg * 2.20462)} lb';
                      String sideStr = widget.useKg ? '${_fmtKg(res.perSideKg)} kg' : '${_fmtKg(res.perSideKg * 2.20462)} lb';
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.horizontal_split_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            isManual 
                                ? (isDualBar ? 'Total: $totalStr (Plates total: $sideStr)' : 'Total: $totalStr')
                                : (res.perSideKg > 0
                                    ? 'Total: $totalStr (Per side: $sideStr)'
                                    : 'Bar only'),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        const Text('  ·  ',
                            style: TextStyle(color: AppColors.textMuted)),
                        Text(
                          inv.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.results.length, (idx) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _curr == idx ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _curr == idx ? AppColors.accent : AppColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
