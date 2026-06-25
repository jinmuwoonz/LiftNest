import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/exercise.dart';
import '../../../core/models/exercise_inventory.dart';
import '../../../core/models/exercise_workout.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/app_theme.dart';

const double _kgToLb = 2.20462;
const double _lbToKg = 0.453592;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AddExerciseScreen extends StatefulWidget {
  final int workoutId;

  /// Non-null when editing an existing exercise.
  final Exercise? exercise;

  const AddExerciseScreen({
    super.key,
    required this.workoutId,
    this.exercise,
  });

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _barCtrl   = TextEditingController();
  final _restCtrl  = TextEditingController();

  bool _useKg           = true;
  int  _sets            = 3;
  int  _reps            = 10;
  bool _isDualBar       = false;
  bool _includeBarWeight = false;

  List<Inventory> _inventories    = [];
  List<int> _selectedInvIds       = []; // ordered; first = primary
  bool _poolInventories           = true;
  bool _isLoading = true;
  bool _isSaving  = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _targetCtrl.dispose();
    _barCtrl.dispose();
    _restCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    final invs = await DatabaseHelper.instance.getAllInventories();

    List<int> linkedIds = [];
    if (_isEditing) {
      final e = widget.exercise!;
      final linked =
          await DatabaseHelper.instance.getInventoriesForExercise(e.id!);
      linkedIds = linked.map((i) => i.id!).toList();

      _nameCtrl.text  = e.name;
      _descCtrl.text  = e.description ?? '';
      _targetCtrl.text =
          e.targetWeightKg != null ? _fmtKg(e.targetWeightKg!) : '';
      _barCtrl.text   =
          e.barWeightKg != null ? _fmtKg(e.barWeightKg!) : '';
      _restCtrl.text  =
          e.restTimeSeconds != null ? '${e.restTimeSeconds}' : '';
      _sets            = e.sets ?? 3;
      _reps            = e.repetitions ?? 10;
      _isDualBar       = e.isDualBar;
      _includeBarWeight = e.includeBarWeight;
      _poolInventories  = e.poolInventories;
    }

    if (!mounted) return;
    setState(() {
      _inventories    = invs;
      _selectedInvIds = linkedIds;
      _isLoading      = false;
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final targetRaw = double.parse(_targetCtrl.text.trim());
      final targetKg  = _useKg ? targetRaw : targetRaw * _lbToKg;
      final targetLb  = _useKg ? targetRaw * _kgToLb : targetRaw;

      double barKg = 0, barLb = 0;
      if (_barCtrl.text.trim().isNotEmpty) {
        final raw = double.tryParse(_barCtrl.text.trim()) ?? 0;
        barKg = _useKg ? raw : raw * _lbToKg;
        barLb = _useKg ? raw * _kgToLb : raw;
      }

      final restSecs = int.tryParse(_restCtrl.text.trim());
      final desc = _descCtrl.text.trim();

      final exercise = Exercise(
        id: widget.exercise?.id,
        name: _nameCtrl.text.trim(),
        description: desc.isEmpty ? '' : desc,
        targetWeightKg: targetKg,
        targetWeightLb: targetLb,
        sets: _sets,
        repetitions: _reps,
        restTimeSeconds: (restSecs != null && restSecs > 0) ? restSecs : null,
        isDualBar: _isDualBar,
        includeBarWeight: _includeBarWeight,
        poolInventories: _poolInventories,
        barWeightKg: barKg > 0 ? barKg : null,
        barWeightLb: barLb > 0 ? barLb : null,
      );

      if (!_isEditing) {
        final id = await DatabaseHelper.instance.insertExercise(exercise);
        await DatabaseHelper.instance.insertExerciseWorkout(
          ExerciseWorkout(exerciseId: id, workoutId: widget.workoutId),
        );
        for (final invId in _selectedInvIds) {
          await DatabaseHelper.instance.insertExerciseInventory(
            ExerciseInventory(exerciseId: id, inventoryId: invId),
          );
        }
      } else {
        await DatabaseHelper.instance.updateExercise(exercise);
        await DatabaseHelper.instance
            .deleteExerciseInventoryByExercise(widget.exercise!.id!);
        for (final invId in _selectedInvIds) {
          await DatabaseHelper.instance.insertExerciseInventory(
            ExerciseInventory(
                exerciseId: widget.exercise!.id!, inventoryId: invId),
          );
        }
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _isEditing ? 'Edit Exercise' : 'Add Exercise',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Section: Basic Info ─────────────────────────────
                    _SectionHeader('Basic Info'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: 'Exercise Name',
                          hintText: 'e.g. Bench Press'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Description (optional)'),
                    ),

                    const SizedBox(height: 28),

                    // ── Section: Target Weight ──────────────────────────
                    _SectionHeader('Target Weight'),
                    const SizedBox(height: 12),
                    _UnitToggle(
                      useKg: _useKg,
                      onToggle: (toKg) {
                        setState(() {
                          final cur =
                              double.tryParse(_targetCtrl.text.trim());
                          _useKg = toKg;
                          if (cur != null && cur > 0) {
                            _targetCtrl.text = toKg
                                ? _fmtKg(cur * _lbToKg)
                                : _fmtKg(cur * _kgToLb);
                          }
                          final barCur =
                              double.tryParse(_barCtrl.text.trim());
                          if (barCur != null && barCur > 0) {
                            _barCtrl.text = toKg
                                ? _fmtKg(barCur * _lbToKg)
                                : _fmtKg(barCur * _kgToLb);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _targetCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'Target Weight',
                        hintText: '0.0',
                        suffixText: _useKg ? 'kg' : 'lb',
                        suffixStyle: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Target weight is required';
                        }
                        final n = double.tryParse(v);
                        if (n == null) return 'Enter a valid number';
                        if (n <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── Section: Training ───────────────────────────────
                    _SectionHeader('Training'),
                    const SizedBox(height: 14),
                    _StepperRow(
                      label: 'Sets',
                      value: _sets,
                      min: 1,
                      max: 20,
                      onChanged: (v) => setState(() => _sets = v),
                    ),
                    const SizedBox(height: 12),
                    _StepperRow(
                      label: 'Reps',
                      value: _reps,
                      min: 1,
                      max: 100,
                      onChanged: (v) => setState(() => _reps = v),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _restCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Rest time (optional)',
                        hintText: '90',
                        suffixText: 'sec',
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Section: Bar Setup ──────────────────────────────
                    _SectionHeader('Bar Setup'),
                    const SizedBox(height: 14),
                    _BarTypeSelector(
                      isDualBar: _isDualBar,
                      onChanged: (v) => setState(() => _isDualBar = v),
                    ),
                    const SizedBox(height: 16),

                    // Bar weight field
                    TextFormField(
                      controller: _barCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      decoration: InputDecoration(
                        labelText: 'Bar weight (optional)',
                        hintText: '20',
                        suffixText: _useKg ? 'kg' : 'lb',
                        suffixStyle: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Include bar weight switch
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SwitchListTile(
                        value: _includeBarWeight,
                        onChanged: (v) =>
                            setState(() => _includeBarWeight = v),
                        activeColor: AppColors.accent,
                        title: const Text('Include bar in target',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        subtitle: const Text(
                          'Bar weight is subtracted from target\nbefore calculating plates.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        dense: true,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Section: Inventory ──────────────────────────────
                    _SectionHeader('Inventory'),
                    const SizedBox(height: 6),
                    Text(
                      'Select inventories to draw plates from.',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    if (_selectedInvIds.length > 1) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          value: _poolInventories,
                          onChanged: (v) =>
                              setState(() => _poolInventories = v),
                          activeColor: AppColors.accent,
                          title: const Text('Pool Inventories',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          subtitle: const Text(
                            'Combine plates from all selected inventories.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          dense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (_inventories.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No inventories yet. Go to the Inventory tab to create one.',
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          children: _inventories.asMap().entries.map((e) {
                            final idx = e.key;
                            final inv = e.value;
                            final isSelected =
                                _selectedInvIds.contains(inv.id);
                            final isPrimary = _selectedInvIds.isNotEmpty &&
                                _selectedInvIds.first == inv.id;

                            return Column(
                              children: [
                                CheckboxListTile(
                                  value: isSelected,
                                  activeColor: AppColors.accent,
                                  checkColor: Colors.white,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedInvIds.add(inv.id!);
                                      } else {
                                        _selectedInvIds.remove(inv.id!);
                                      }
                                    });
                                  },
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(inv.name,
                                            style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      if (isPrimary) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.accentGradient,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Text('Primary',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: inv.description != null
                                      ? Text(inv.description!,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12))
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 2),
                                ),
                                if (idx < _inventories.length - 1)
                                  const Divider(height: 1,
                                      indent: 16, endIndent: 16),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 36),

                    // ── Save button ─────────────────────────────────────
                    GestureDetector(
                      onTap: _isSaving ? null : _save,
                      child: Container(
                        height: 54,
                        decoration: AppColors.gradientBox(radius: 14),
                        alignment: Alignment.center,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white))
                            : Text(
                                _isEditing
                                    ? 'Save Changes'
                                    : 'Add Exercise',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit toggle (kg / lb)
// ─────────────────────────────────────────────────────────────────────────────

class _UnitToggle extends StatelessWidget {
  final bool useKg;
  final ValueChanged<bool> onToggle; // true = switch to kg

  const _UnitToggle({required this.useKg, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        _tab('KG', useKg, () => onToggle(true)),
        _tab('LB', !useKg, () => onToggle(false)),
      ]),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stepper row (sets / reps)
// ─────────────────────────────────────────────────────────────────────────────

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const Spacer(),
      Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepBtn(Icons.remove,
                value > min ? () => onChanged(value - 1) : null),
            SizedBox(
              width: 44,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
            _stepBtn(Icons.add,
                value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      ),
    ]);
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: onTap != null ? AppColors.textPrimary : AppColors.textMuted,
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(),
      onPressed: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar type selector (Single / Two Bars)
// ─────────────────────────────────────────────────────────────────────────────

class _BarTypeSelector extends StatelessWidget {
  final bool isDualBar;
  final ValueChanged<bool> onChanged;

  const _BarTypeSelector(
      {required this.isDualBar, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _option(
        selected: !isDualBar,
        label: 'Single Bar',
        subtitle: 'Plates load equally on both sides',
        onTap: () => onChanged(false),
      ),
      const SizedBox(width: 10),
      _option(
        selected: isDualBar,
        label: 'Two Bars',
        subtitle: 'Two separate bars, each at target weight',
        onTap: () => onChanged(true),
      ),
    ]);
  }

  Widget _option({
    required bool selected,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentDim : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.linear_scale_rounded,
                    size: 18,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                ),
              ]),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _fmtKg(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  String s = v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
