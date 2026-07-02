import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/inventory.dart';
import '../../../core/models/weight.dart';
import '../../../core/services/plate_calculator.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/barbell_visualizer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class QuickCalculatorScreen extends StatefulWidget {
  const QuickCalculatorScreen({super.key});

  @override
  State<QuickCalculatorScreen> createState() => _QuickCalculatorScreenState();
}

class _QuickCalculatorScreenState extends State<QuickCalculatorScreen> {
  final _targetCtrl = TextEditingController();
  bool _useKg = true;

  List<Inventory> _inventories = [];
  List<int> _selectedInvIds = [];
  bool _poolInventories = true;
  bool _isDualBar = false;
  bool _isLoading = true;

  // Results
  PlateResult? _pooledResult;
  List<PlateResult>? _individualResults;
  bool _hasCalculated = false;

  static const double _kgToLb = 2.20462;
  static const double _lbToKg = 0.453592;

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInventories() async {
    final invs = await DatabaseHelper.instance.getAllInventories();
    if (!mounted) return;
    setState(() {
      _inventories = invs;
      _isLoading = false;
    });
  }

  // ── Calculate ─────────────────────────────────────────────────────────────
  void _calculate() {
    final raw = double.tryParse(_targetCtrl.text.trim());
    if (raw == null || raw <= 0) {
      setState(() {
        _pooledResult = null;
        _individualResults = null;
        _hasCalculated = false;
      });
      return;
    }
    final targetKg = _useKg ? raw : raw * _lbToKg;

    if (_selectedInvIds.isEmpty) {
      setState(() {
        _pooledResult = PlateResult(
          perSide: [],
          status: PlateResultStatus.noInventory,
          perSideKg: 0,
        );
        _individualResults = null;
        _hasCalculated = true;
      });
      return;
    }

    final selectedInvs = _inventories
        .where((inv) => _selectedInvIds.contains(inv.id))
        .toList();

    _doCalculate(targetKg, selectedInvs);
  }

  Future<void> _doCalculate(
      double targetKg, List<Inventory> selectedInvs) async {
    if (_poolInventories || selectedInvs.length <= 1) {
      final weights = <Weight>[];
      for (final inv in selectedInvs) {
        weights.addAll(
            await DatabaseHelper.instance.getWeightsForInventory(inv.id!));
      }
      final result = PlateCalculator.calculate(
        targetWeightKg: targetKg,
        includeBarWeight: false,
        barWeightKg: 0,
        isDualBar: _isDualBar,
        availableWeights: weights,
      );
      if (!mounted) return;
      setState(() {
        _pooledResult = result;
        _individualResults = null;
        _hasCalculated = true;
      });
    } else {
      final results = <PlateResult>[];
      for (final inv in selectedInvs) {
        final weights =
            await DatabaseHelper.instance.getWeightsForInventory(inv.id!);
        results.add(PlateCalculator.calculate(
          targetWeightKg: targetKg,
          includeBarWeight: false,
          barWeightKg: 0,
          isDualBar: _isDualBar,
          availableWeights: weights,
        ));
      }
      if (!mounted) return;
      setState(() {
        _pooledResult = null;
        _individualResults = results;
        _hasCalculated = true;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Quick Calculator',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Target weight ───────────────────────────────────────
                  _SectionLabel('Target Weight'),
                  const SizedBox(height: 12),
                  _UnitToggle(
                    useKg: _useKg,
                    onToggle: (toKg) {
                      setState(() {
                        final cur =
                            double.tryParse(_targetCtrl.text.trim());
                        _useKg = toKg;
                        if (cur != null && cur > 0) {
                          final converted =
                              toKg ? cur * _lbToKg : cur * _kgToLb;
                          _targetCtrl.text = _fmt(converted);
                        }
                        _calculate();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetCtrl,
                    style:
                        const TextStyle(color: AppColors.textPrimary),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'))
                    ],
                    onChanged: (_) => _calculate(),
                    decoration: InputDecoration(
                      labelText: 'Target Weight',
                      hintText: '0.0',
                      suffixText: _useKg ? 'kg' : 'lb',
                      suffixStyle: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Bar setup ───────────────────────────────────────────
                  _SectionLabel('Bar Setup'),
                  const SizedBox(height: 12),
                  _BarTypeSelector(
                    isDualBar: _isDualBar,
                    onChanged: (v) {
                      setState(() => _isDualBar = v);
                      _calculate();
                    },
                  ),

                  const SizedBox(height: 28),

                  // ── Inventory ───────────────────────────────────────────
                  _SectionLabel('Inventory'),
                  const SizedBox(height: 8),
                  const Text(
                    'Select one or more inventories to draw plates from.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  if (_inventories.isEmpty)
                    _emptyInventoryNote()
                  else
                    _inventoryList(),

                  if (_selectedInvIds.length > 1) ...[
                    const SizedBox(height: 14),
                    _PoolToggle(
                      value: _poolInventories,
                      onChanged: (v) {
                        setState(() => _poolInventories = v);
                        _calculate();
                      },
                    ),
                  ],

                  // ── Result ──────────────────────────────────────────────
                  if (_hasCalculated) ...[
                    const SizedBox(height: 28),
                    _buildResult(),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Result section ─────────────────────────────────────────────────────────
  Widget _buildResult() {
    final selectedInvs = _inventories
        .where((inv) => _selectedInvIds.contains(inv.id))
        .toList();

    if (_pooledResult != null) {
      return _ResultCard(
        result: _pooledResult!,
        inventoryName: selectedInvs.length == 1
            ? selectedInvs.first.name
            : 'Pooled Inventories',
        isDualBar: _isDualBar,
        useKg: _useKg,
      );
    }

    if (_individualResults != null && _individualResults!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Results per Inventory'),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: PageView.builder(
              itemCount: _individualResults!.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ResultCard(
                  result: _individualResults![i],
                  inventoryName: selectedInvs[i].name,
                  isDualBar: _isDualBar,
                  showPageHint: _individualResults!.length > 1,
                  pageIndex: i,
                  pageCount: _individualResults!.length,
                  useKg: _useKg,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Inventory list ─────────────────────────────────────────────────────────
  Widget _inventoryList() {
    return Container(
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
          final isSelected = _selectedInvIds.contains(inv.id);
          final isPrimary =
              _selectedInvIds.isNotEmpty && _selectedInvIds.first == inv.id;

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
                    _calculate();
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
                          borderRadius: BorderRadius.circular(20),
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
                subtitle: inv.description != null &&
                        inv.description!.isNotEmpty
                    ? Text(inv.description!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12))
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 2),
              ),
              if (idx < _inventories.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyInventoryNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No inventories yet. Go to the Inventory tab to create one.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result card
// ─────────────────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final PlateResult result;
  final String inventoryName;
  final bool isDualBar;
  final bool showPageHint;
  final int pageIndex;
  final int pageCount;
  final bool useKg;

  const _ResultCard({
    required this.result,
    required this.inventoryName,
    required this.isDualBar,
    this.showPageHint = false,
    this.pageIndex = 0,
    this.pageCount = 1,
    required this.useKg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.isOk ? AppColors.accent : AppColors.border,
          width: result.isOk ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  inventoryName,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showPageHint)
                Text(
                  '${pageIndex + 1} / $pageCount  ← swipe →',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Visualizer
          BarbellVisualizer(
            result: result,
            compact: false,
            isDualBar: isDualBar,
            useKg: useKg,
          ),

          if (result.isOk && result.perSideKg > 0) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.horizontal_split_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Per side: ${useKg ? _fmt(result.perSideKg) : _fmt(result.perSideKg * 2.20462)} ${useKg ? 'kg' : 'lb'}',
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (result.isOk) ...[
            const SizedBox(height: 8),
            const Center(
              child: Text('Bar only — no plates needed',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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

class _UnitToggle extends StatelessWidget {
  final bool useKg;
  final ValueChanged<bool> onToggle;
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
                  color:
                      selected ? Colors.white : AppColors.textMuted,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 14)),
        ),
      ),
    );
  }
}

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
        subtitle: 'Plates on both sides equally',
        onTap: () => onChanged(false),
      ),
      const SizedBox(width: 10),
      _option(
        selected: isDualBar,
        label: 'Two Bars',
        subtitle: 'Two bars, each at target weight',
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
          padding: const EdgeInsets.all(12),
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
                    size: 16,
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
              const SizedBox(height: 4),
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

class _PoolToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PoolToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.accent,
        title: const Text('Pool Inventories',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        subtitle: const Text(
          'Combine plates from all selected inventories.',
          style:
              TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _fmt(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  String s = v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
