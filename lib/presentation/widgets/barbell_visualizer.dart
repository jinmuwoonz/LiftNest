import 'package:flutter/material.dart';

import '../../core/services/plate_calculator.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a horizontal barbell with colour-coded plates on each side.
///
/// [compact] = true  → smaller plates for use inside exercise cards.
/// [compact] = false → full-size plates with labels for detail views.
class BarbellVisualizer extends StatelessWidget {
  final PlateResult result;
  final bool compact;
  final bool isDualBar;

  const BarbellVisualizer({
    super.key,
    required this.result,
    this.compact = false,
    this.isDualBar = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.isOk) return _StatusMessage(result: result);

    // Expand per-side list into individual plate slots (heaviest first = inner).
    final List<double> expanded = [];
    for (final p in result.perSide) {
      for (int i = 0; i < p.countPerSide; i++) {
        expanded.add(p.weightKg);
      }
    }

    // Left side: outer → inner (reversed). Right: inner → outer (normal).
    final leftPlates = List<double>.from(expanded.reversed);
    final rightPlates = List<double>.from(expanded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDualBar) _DualBarBadge(),
        _Barbell(
          leftPlates: leftPlates,
          rightPlates: rightPlates,
          compact: compact,
        ),
        if (!compact && result.perSide.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Summary(result: result),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status / error message
// ─────────────────────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  final PlateResult result;
  const _StatusMessage({required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, msg, color) = _resolve(result.status);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 12))),
      ],
    );
  }

  static (IconData, String, Color) _resolve(PlateResultStatus s) {
    switch (s) {
      case PlateResultStatus.notEnoughPlates:
        return (Icons.warning_amber_rounded,
            'Not enough plates in inventory',
            const Color(0xFFFFD166));
      case PlateResultStatus.cannotAchieve:
        return (Icons.cancel_outlined,
            'Cannot reach this weight with available plate sizes',
            AppColors.error);
      case PlateResultStatus.barTooHeavy:
        return (Icons.cancel_outlined,
            'Bar weight exceeds target',
            AppColors.error);
      case PlateResultStatus.noInventory:
        return (Icons.inventory_2_outlined,
            'No inventory selected',
            AppColors.textMuted);
      default:
        return (Icons.check_circle_outline, 'Bar only', AppColors.success);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary row
// ─────────────────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  final PlateResult result;
  const _Summary({required this.result});

  @override
  Widget build(BuildContext context) {
    final perSide = result.totalLoadedKgPerSide;
    return Text(
      'Per side: ${_fmt(perSide)} kg   ·   '
      'Plates total: ${_fmt(perSide * 2)} kg',
      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "×2 bars" badge
// ─────────────────────────────────────────────────────────────────────────────

class _DualBarBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('× 2 bars',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barbell row
// ─────────────────────────────────────────────────────────────────────────────

class _Barbell extends StatelessWidget {
  final List<double> leftPlates;
  final List<double> rightPlates;
  final bool compact;

  const _Barbell({
    required this.leftPlates,
    required this.rightPlates,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final double plateW  = compact ? 11 : 16;
    final double sleeveW = compact ? 14 : 20;
    final double barW    = compact ? 72 : 100;
    final double barH    = compact ? 6  : 8;
    final double sleeveH = compact ? 20 : 26;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left plates (outer → inner reading left-to-right)
          ...leftPlates.map((kg) => _Plate(kg: kg, width: plateW, compact: compact)),
          _Sleeve(width: sleeveW, height: sleeveH, isLeft: true),
          _BarShaft(width: barW, height: barH),
          _Sleeve(width: sleeveW, height: sleeveH, isLeft: false),
          // Right plates (inner → outer reading left-to-right)
          ...rightPlates.map((kg) => _Plate(kg: kg, width: plateW, compact: compact)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual plate
// ─────────────────────────────────────────────────────────────────────────────

class _Plate extends StatelessWidget {
  final double kg;
  final double width;
  final bool compact;

  const _Plate({required this.kg, required this.width, required this.compact});

  /// Standard Olympic plate colour mapping.
  static Color _color(double kg) {
    if (kg >= 25) return const Color(0xFFDC2626); // Red
    if (kg >= 20) return const Color(0xFF2563EB); // Blue
    if (kg >= 15) return const Color(0xFFF59E0B); // Yellow
    if (kg >= 10) return const Color(0xFF16A34A); // Green
    if (kg >= 5)  return const Color(0xFFCBD5E1); // Silver/white
    if (kg >= 2)  return const Color(0xFF60A5FA); // Light blue
    if (kg >= 1)  return const Color(0xFFFBBF24); // Light yellow
    if (kg >= 0.5) return const Color(0xFF86EFAC); // Light green
    return const Color(0xFF9CA3AF);               // Grey
  }

  static double _height(double kg, bool compact) {
    double h;
    if (kg >= 25) {
      h = 120;
    } else if (kg >= 20) {
      h = 108;
    } else if (kg >= 15) {
      h = 96;
    } else if (kg >= 10) {
      h = 84;
    } else if (kg >= 5) {
      h = 70;
    } else if (kg >= 2) {
      h = 58;
    } else if (kg >= 1) {
      h = 50;
    } else if (kg >= 0.5) {
      h = 42;
    } else {
      h = 34;
    }
    return compact ? h * 0.62 : h;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color(kg);
    final h = _height(kg, compact);
    return Container(
      width: width,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 0.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(c, Colors.black, 0.18)!,
            c,
            Color.lerp(c, Colors.white, 0.15)!,
            c,
            Color.lerp(c, Colors.black, 0.18)!,
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 1,
        child: Text(
          _fmt(kg),
          style: TextStyle(
            color: c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
            fontSize: compact ? 7 : 10,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleeve & bar shaft
// ─────────────────────────────────────────────────────────────────────────────

class _Sleeve extends StatelessWidget {
  final double width;
  final double height;
  final bool isLeft;

  const _Sleeve(
      {required this.width, required this.height, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB0B8C4), Color(0xFF6B7280), Color(0xFFB0B8C4)],
        ),
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? Radius.zero : const Radius.circular(5),
          right: isLeft ? const Radius.circular(5) : Radius.zero,
        ),
      ),
    );
  }
}

class _BarShaft extends StatelessWidget {
  final double width;
  final double height;

  const _BarShaft({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF), Color(0xFFE5E7EB)],
        ),
        borderRadius: BorderRadius.circular(2),
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
