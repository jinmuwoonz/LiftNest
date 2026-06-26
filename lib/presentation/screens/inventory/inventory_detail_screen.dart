import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/inventory.dart';
import '../../../core/models/weight.dart';
import '../../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Strips trailing zeros from a decimal string.
/// e.g. "2.500" → "2.5"  |  "2.000" → "2"
String _fmt(double v, {int decimals = 3}) {
  String s = v.toStringAsFixed(decimals);
  s = s.replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

const double _kgToLb = 2.20462;
const double _lbToKg = 0.453592;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class InventoryDetailScreen extends StatefulWidget {
  final Inventory inventory;
  const InventoryDetailScreen({super.key, required this.inventory});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late Inventory _inventory;
  List<Weight> _weights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inventory = widget.inventory;
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    setState(() => _isLoading = true);
    final w =
        await DatabaseHelper.instance.getWeightsForInventory(_inventory.id!);
    if (!mounted) return;
    setState(() {
      _weights = w;
      _isLoading = false;
    });
  }

  // ── Add / Edit weight sheet ─────────────────────────────────────────────
  Future<void> _showWeightSheet({Weight? weight}) async {
    bool useKg = true;
    final weightCtrl = TextEditingController(
      text: weight != null ? _fmt(weight.weightKg) : '',
    );
    final descCtrl = TextEditingController(text: weight?.description ?? '');
    int qty = weight?.quantity ?? 1;
    Color? selectedColor = weight?.colorValue != null ? Color(weight!.colorValue!) : null;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final parsed = double.tryParse(weightCtrl.text);
          final converted = parsed == null || parsed <= 0
              ? null
              : useKg
                  ? '= ${_fmt(parsed * _kgToLb, decimals: 2)} lb'
                  : '= ${_fmt(parsed * _lbToKg, decimals: 3)} kg';

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _BottomSheetContainer(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SheetHandle(),
                    const SizedBox(height: 20),
                    Text(
                      weight == null ? 'Add Weight' : 'Edit Weight',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // Unit toggle
                    _UnitToggle(
                      useKg: useKg,
                      onToggle: (toKg) {
                        setSheet(() {
                          final cur = double.tryParse(weightCtrl.text);
                          useKg = toKg;
                          if (cur != null && cur > 0) {
                            weightCtrl.text = toKg
                                ? _fmt(cur * _lbToKg, decimals: 3)
                                : _fmt(cur * _kgToLb, decimals: 2);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Weight input
                    TextFormField(
                      controller: weightCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Weight',
                        hintText: useKg ? '0.0' : '0.00',
                        suffixText: useKg ? 'kg' : 'lb',
                        suffixStyle: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onChanged: (_) => setSheet(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Weight is required';
                        }
                        final n = double.tryParse(v);
                        if (n == null) return 'Enter a valid number';
                        if (n <= 0) return 'Must be greater than 0';
                        return null;
                      },
                    ),
                    if (converted != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(converted,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Quantity stepper
                    Row(children: [
                      Text('Quantity',
                          style: Theme.of(ctx).textTheme.titleSmall),
                      const Spacer(),
                      _QuantityStepper(
                        value: qty,
                        onChanged: (v) => setSheet(() => qty = v),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Description
                    TextFormField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'e.g. Red bumper plates',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    _ColorSelector(
                      selectedColor: selectedColor,
                      onColorChanged: (c) => setSheet(() => selectedColor = c),
                    ),

                    const SizedBox(height: 28),

                    // Submit
                    _GradientButton(
                      label:
                          weight == null ? 'Add Weight' : 'Save Changes',
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final raw = double.parse(weightCtrl.text);
                        final kg = useKg ? raw : raw * _lbToKg;
                        final lb = useKg ? raw * _kgToLb : raw;
                        final desc = descCtrl.text.trim();
                        final colorVal = selectedColor?.value;
                        if (weight == null) {
                          await DatabaseHelper.instance.insertWeight(Weight(
                            inventoryId: _inventory.id!,
                            weightKg: kg,
                            weightLb: lb,
                            quantity: qty,
                            description: desc.isEmpty ? '' : desc,
                            colorValue: colorVal,
                          ));
                        } else {
                          await DatabaseHelper.instance.updateWeight(
                            weight.copyWith(
                              weightKg: kg,
                              weightLb: lb,
                              quantity: qty,
                              description: desc.isEmpty ? '' : desc,
                              colorValue: colorVal,
                            ),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadWeights();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Delete weight ───────────────────────────────────────────────────────
  Future<bool?> _confirmDeleteWeight(Weight w) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Weight?'),
        content: Text(
            'Remove ${_fmt(w.weightKg)} kg (×${w.quantity}) from this inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWeight(Weight w) async {
    await DatabaseHelper.instance.deleteWeight(w.id!);
    _loadWeights();
  }

  // ── Edit inventory ──────────────────────────────────────────────────────
  Future<void> _showEditInventorySheet() async {
    final nameCtrl = TextEditingController(text: _inventory.name);
    final descCtrl =
        TextEditingController(text: _inventory.description ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BottomSheetContainer(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHandle(),
                const SizedBox(height: 20),
                Text('Edit Inventory',
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
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 28),
                _GradientButton(
                  label: 'Save Changes',
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final updated = _inventory.copyWith(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                    await DatabaseHelper.instance
                        .updateInventory(updated);
                    if (!mounted) return;
                    setState(() => _inventory = updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete inventory ────────────────────────────────────────────────────
  Future<void> _confirmDeleteInventory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inventory'),
        content: Text(
            'Delete "${_inventory.name}"? All weights inside will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteInventory(_inventory.id!);
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
        title: Text(
          _inventory.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showEditInventorySheet();
              if (v == 'delete') _confirmDeleteInventory();
            },
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            itemBuilder: (_) => [
              _menuItem(
                  'edit', Icons.edit_outlined, 'Edit', AppColors.textPrimary),
              _menuItem('delete', Icons.delete_outline, 'Delete inventory',
                  AppColors.error),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.accent))
          : _weights.isEmpty
              ? _EmptyState()
              : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWeightSheet(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
      itemCount: _weights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final w = _weights[i];
        return Dismissible(
          key: ValueKey(w.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDeleteWeight(w),
          onDismissed: (_) => _deleteWeight(w),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 24),
          ),
          child: _WeightCard(
            weight: w,
            onTap: () => _showWeightSheet(weight: w),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
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
class _EmptyState extends StatelessWidget {
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
                color: AppColors.accentDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('No weights yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Tap + to add your first plate or weight.',
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
// Weight card
// ─────────────────────────────────────────────────────────────────────────────
class _WeightCard extends StatelessWidget {
  final Weight weight;
  final VoidCallback onTap;
  const _WeightCard({required this.weight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kg = _fmt(weight.weightKg);
    final lb = _fmt(weight.weightLb, decimals: 2);

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
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: weight.colorValue != null ? Color(weight.colorValue!) : AppColors.accentDim,
                  shape: BoxShape.circle,
                  border: weight.colorValue != null ? Border.all(color: AppColors.border, width: 2) : null,
                ),
                child: Icon(Icons.fitness_center_rounded,
                    color: weight.colorValue != null 
                        ? (Color(weight.colorValue!).computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                        : AppColors.accent, 
                    size: 20),
              ),
              const SizedBox(width: 14),

              // Weight info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: kg,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const TextSpan(
                          text: ' kg',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text('$lb lb',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    if (weight.description != null &&
                        weight.description!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        weight.description!,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Quantity badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: AppColors.gradientBox(radius: 20),
                child: Text(
                  '× ${weight.quantity}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
// Shared small widgets (reused in both screens via same file)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetContainer extends StatelessWidget {
  final Widget child;
  const _BottomSheetContainer({required this.child});

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

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
        decoration: AppColors.gradientBox(radius: 14),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final bool useKg;
  final ValueChanged<bool> onToggle; // true = switched TO kg

  const _UnitToggle({required this.useKg, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _tab('KG', useKg, () => onToggle(true)),
          _tab('LB', !useKg, () => onToggle(false)),
        ],
      ),
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textMuted,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _QuantityStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove, value > 1 ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          _stepBtn(Icons.add, () => onChanged(value + 1)),
        ],
      ),
    );
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
// Color Selector
// ─────────────────────────────────────────────────────────────────────────────

class _ColorSelector extends StatelessWidget {
  final Color? selectedColor;
  final ValueChanged<Color?> onColorChanged;

  const _ColorSelector({required this.selectedColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    final presets = [
      Colors.green,
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.yellow,
    ];

    bool isCustom = selectedColor != null && !presets.any((p) => p.value == selectedColor!.value);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildColorCircle(context, null, selectedColor == null, () => onColorChanged(null)),
        for (final c in presets)
          _buildColorCircle(context, c, selectedColor?.value == c.value, () => onColorChanged(c)),
        _buildCustomCircle(context, isCustom, () async {
            final custom = await _showCustomColorPicker(context, selectedColor ?? Colors.grey);
            if (custom != null) onColorChanged(custom);
        }),
      ],
    );
  }

  Widget _buildColorCircle(BuildContext context, Color? color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.accent : (color == null ? AppColors.border : Colors.transparent),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: color == null 
            ? const Icon(Icons.format_color_reset, size: 20, color: AppColors.textMuted)
            : (isSelected ? Icon(Icons.check, size: 20, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white) : null),
      ),
    );
  }

  Widget _buildCustomCircle(BuildContext context, bool isCustom, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const SweepGradient(
            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isCustom ? AppColors.accent : Colors.transparent,
            width: isCustom ? 3 : 0,
          ),
        ),
        child: isCustom
            ? const Icon(Icons.check, size: 20, color: AppColors.surface)
            : const Icon(Icons.add, size: 20, color: Colors.white),
      ),
    );
  }

  Future<Color?> _showCustomColorPicker(BuildContext context, Color initialColor) {
    double r = initialColor.red.toDouble();
    double g = initialColor.green.toDouble();
    double b = initialColor.blue.toDouble();

    return showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Custom Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('R', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Expanded(child: Slider(value: r, min: 0, max: 255, activeColor: Colors.red, onChanged: (v) => setDialog(() => r = v))),
                ],
              ),
              Row(
                children: [
                  const Text('G', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  Expanded(child: Slider(value: g, min: 0, max: 255, activeColor: Colors.green, onChanged: (v) => setDialog(() => g = v))),
                ],
              ),
              Row(
                children: [
                  const Text('B', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  Expanded(child: Slider(value: b, min: 0, max: 255, activeColor: Colors.blue, onChanged: (v) => setDialog(() => b = v))),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1)),
              child: const Text('Select', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }
}

