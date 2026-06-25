import 'dart:math';

import '../models/weight.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

/// One plate type on a single side of one bar.
class PlateUsage {
  final double weightKg;
  final int countPerSide;

  const PlateUsage({required this.weightKg, required this.countPerSide});

  double get weightLb => weightKg * 2.20462;
  double get totalKgPerSide => weightKg * countPerSide;

  @override
  String toString() => '${weightKg}kg ×$countPerSide';
}

enum PlateResultStatus {
  /// A valid combination was found.
  ok,

  /// The target is theoretically achievable but there are not enough plates.
  notEnoughPlates,

  /// The available plate sizes cannot sum to the required per-side weight.
  cannotAchieve,

  /// The bar itself is heavier than the target weight.
  barTooHeavy,

  /// No inventory was selected for this exercise.
  noInventory,
}

class PlateResult {
  /// Plates on one side of one bar, sorted heaviest first (innermost first).
  final List<PlateUsage> perSide;
  final PlateResultStatus status;

  /// Weight to be loaded on each side of one bar (after bar subtraction).
  final double perSideKg;

  const PlateResult({
    required this.perSide,
    required this.status,
    required this.perSideKg,
  });

  bool get isOk => status == PlateResultStatus.ok;

  double get totalLoadedKgPerSide =>
      perSide.fold(0.0, (s, p) => s + p.totalKgPerSide);
}

// ─────────────────────────────────────────────────────────────────────────────
// Calculator
// ─────────────────────────────────────────────────────────────────────────────

class PlateCalculator {
  /// Internal precision: 1 unit = 0.001 kg (handles plates as small as 0.25 kg).
  static const int _scale = 1000;

  /// Calculates which plates to load given an exercise setup and inventory.
  ///
  /// [isDualBar] = false → single bar, plates go on both sides equally.
  /// [isDualBar] = true  → two separate bars; needs 4× the plates in total.
  /// [includeBarWeight]  → subtract [barWeightKg] from [targetWeightKg] first.
  static PlateResult calculate({
    required double targetWeightKg,
    required bool includeBarWeight,
    required double barWeightKg,
    required bool isDualBar,
    required List<Weight> availableWeights,
  }) {
    if (availableWeights.isEmpty) {
      return PlateResult(
        perSide: [],
        status: PlateResultStatus.noInventory,
        perSideKg: 0,
      );
    }

    final double plateLoad =
        targetWeightKg - (includeBarWeight ? barWeightKg : 0);

    if (plateLoad < -0.001) {
      return PlateResult(
        perSide: [],
        status: PlateResultStatus.barTooHeavy,
        perSideKg: 0,
      );
    }

    final double perSideKg = plateLoad.clamp(0, double.infinity) / 2;

    // ── Build a pool of plates ──────────────────────────────────────────────
    //
    // For a single bar : each plate is placed on 2 sides  → need 2× per "count"
    // For two bars     : each plate is placed on 4 sides  → need 4× per "count"
    // So: maxCountPerSide = totalQuantity ÷ (isDualBar ? 4 : 2)
    final int totalSides = isDualBar ? 4 : 2;

    // 1. Aggregate total quantity per plate weight across all inventories.
    final Map<int, int> totalQty = {};
    for (final w in availableWeights) {
      final key = (w.weightKg * _scale).round();
      totalQty[key] = (totalQty[key] ?? 0) + w.quantity;
    }

    // 2. Compute available per side using integer floor division.
    final Map<int, int> perSideQty = {};
    for (final e in totalQty.entries) {
      final avail = e.value ~/ totalSides;
      if (avail > 0) perSideQty[e.key] = avail;
    }

    // 3. Sort heaviest first (inner plates go on first, greedy works well).
    final sorted = perSideQty.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final int targetInt = (perSideKg * _scale).round();

    // Bar-only case: no plates needed.
    if (targetInt == 0) {
      return PlateResult(
        perSide: [],
        status: PlateResultStatus.ok,
        perSideKg: 0,
      );
    }

    // 4. Try to solve with actual available quantities.
    final counts = _solve(
      sorted.map((e) => (e.key, e.value)).toList(),
      targetInt,
      0,
    );

    if (counts != null) {
      final usage = <PlateUsage>[];
      for (int i = 0; i < sorted.length; i++) {
        final c = i < counts.length ? counts[i] : 0;
        if (c > 0) {
          usage.add(PlateUsage(
            weightKg: sorted[i].key / _scale.toDouble(),
            countPerSide: c,
          ));
        }
      }
      return PlateResult(
        perSide: usage,
        status: PlateResultStatus.ok,
        perSideKg: perSideKg,
      );
    }

    // 5. Check theoretical feasibility (unlimited quantities).
    final theoretical = _solve(
      sorted.map((e) => (e.key, 9999)).toList(),
      targetInt,
      0,
    );

    return PlateResult(
      perSide: [],
      status: theoretical != null
          ? PlateResultStatus.notEnoughPlates
          : PlateResultStatus.cannotAchieve,
      perSideKg: perSideKg,
    );
  }

  /// Greedy-first backtracking solver.
  ///
  /// Returns a list of per-plate counts (parallel to [plates]) or null if
  /// the exact [remaining] weight cannot be achieved.
  static List<int>? _solve(
    List<(int weight, int maxQty)> plates,
    int remaining,
    int index,
  ) {
    if (remaining == 0) return List.filled(plates.length - index, 0);
    if (remaining < 0 || index >= plates.length) return null;

    final (weight, qty) = plates[index];
    if (weight <= 0) return _solve(plates, remaining, index + 1);

    final int maxCount = min(qty, remaining ~/ weight);
    for (int count = maxCount; count >= 0; count--) {
      final sub = _solve(plates, remaining - count * weight, index + 1);
      if (sub != null) return [count, ...sub];
    }
    return null;
  }
}
