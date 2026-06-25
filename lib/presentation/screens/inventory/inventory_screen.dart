import 'package:flutter/material.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/models/inventory.dart';
import '../../../core/theme/app_theme.dart';
import 'inventory_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public state class so MainScreen can call showAddInventorySheet() via GlobalKey
// ─────────────────────────────────────────────────────────────────────────────
class InventoryContent extends StatefulWidget {
  const InventoryContent({super.key});

  @override
  State<InventoryContent> createState() => InventoryContentState();
}

class InventoryContentState extends State<InventoryContent> {
  List<Inventory> _inventories = [];
  final Map<int, int> _weightCounts = {}; // inventoryId → plate-type count
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final inventories = await DatabaseHelper.instance.getAllInventories();
    final counts = <int, int>{};
    for (final inv in inventories) {
      counts[inv.id!] =
          await DatabaseHelper.instance.getWeightCountForInventory(inv.id!);
    }
    if (!mounted) return;
    setState(() {
      _inventories = inventories;
      _weightCounts.addAll(counts);
      _isLoading = false;
    });
  }

  // ── Public entry point called by the FAB in MainScreen ──────────────────
  void showAddInventorySheet() => _showSheet();

  // ── Add / Edit bottom sheet ─────────────────────────────────────────────
  Future<void> _showSheet({Inventory? inv}) async {
    final nameCtrl = TextEditingController(text: inv?.name ?? '');
    final descCtrl = TextEditingController(text: inv?.description ?? '');
    final formKey = GlobalKey<FormState>();
    final isEdit = inv != null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                    isEdit ? 'Edit Inventory' : 'Create Inventory',
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
                      hintText: 'e.g. Home Gym Rack',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. Plates stored in the garage',
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  _GradientButton(
                    label: isEdit ? 'Save Changes' : 'Create Inventory',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final name = nameCtrl.text.trim();
                      final desc = descCtrl.text.trim();
                      if (isEdit) {
                        await DatabaseHelper.instance.updateInventory(
                          inv.copyWith(
                            name: name,
                            description: desc.isEmpty ? '' : desc,
                          ),
                        );
                      } else {
                        await DatabaseHelper.instance.insertInventory(
                          Inventory(
                              name: name,
                              description: desc.isEmpty ? '' : desc),
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
        );
      },
    );
  }

  // ── Delete with confirmation ─────────────────────────────────────────────
  Future<void> _confirmDelete(Inventory inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inventory'),
        content: Text(
          'Delete "${inv.name}"?\nAll weights inside will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteInventory(inv.id!);
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
    if (_inventories.isEmpty) return _EmptyState();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
        itemCount: _inventories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final inv = _inventories[i];
          return _InventoryCard(
            inventory: inv,
            weightCount: _weightCounts[inv.id!] ?? 0,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => InventoryDetailScreen(inventory: inv)),
              );
              _load(); // refresh counts after returning
            },
            onEdit: () => _showSheet(inv: inv),
            onDelete: () => _confirmDelete(inv),
          );
        },
      ),
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
              child: const Icon(Icons.inventory_2_outlined,
                  size: 48, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('No Inventories Yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Tap the + button below to create\nyour first equipment inventory.',
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
// Inventory card
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryCard extends StatelessWidget {
  final Inventory inventory;
  final int weightCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventoryCard({
    required this.inventory,
    required this.weightCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = inventory.name
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Gradient avatar
              Container(
                width: 48,
                height: 48,
                decoration: AppColors.gradientBox(radius: 14),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Text info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inventory.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (inventory.description != null &&
                        inventory.description!.isNotEmpty)
                      Text(
                        inventory.description!,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        '$weightCount plate type${weightCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
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
                  _menuItem('edit', Icons.edit_outlined, 'Edit',
                      AppColors.textPrimary),
                  _menuItem('delete', Icons.delete_outline, 'Delete',
                      AppColors.error),
                ],
              ),
            ],
          ),
        ),
      ),
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
// Shared small widgets
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
