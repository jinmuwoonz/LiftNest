class ExerciseInventory {
  final int? id;
  final int exerciseId;
  final int inventoryId;
  final double? targetWeightKg;
  final double? targetWeightLb;
  final bool? isDualBar;
  final bool? includeBarWeight;
  final double? barWeightKg;
  final double? barWeightLb;
  final String? manualPlatesJson;

  const ExerciseInventory({
    this.id,
    required this.exerciseId,
    required this.inventoryId,
    this.targetWeightKg,
    this.targetWeightLb,
    this.isDualBar,
    this.includeBarWeight,
    this.barWeightKg,
    this.barWeightLb,
    this.manualPlatesJson,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exercise_id': exerciseId,
      'inventory_id': inventoryId,
      'target_weight_kg': targetWeightKg,
      'target_weight_lb': targetWeightLb,
      'is_dual_bar': isDualBar != null ? (isDualBar! ? 1 : 0) : null,
      'include_bar_weight': includeBarWeight != null ? (includeBarWeight! ? 1 : 0) : null,
      'bar_weight_kg': barWeightKg,
      'bar_weight_lb': barWeightLb,
      'manual_plates_json': manualPlatesJson,
    };
  }

  factory ExerciseInventory.fromMap(Map<String, dynamic> map) {
    return ExerciseInventory(
      id: map['id'] as int?,
      exerciseId: map['exercise_id'] as int,
      inventoryId: map['inventory_id'] as int,
      targetWeightKg: map['target_weight_kg'] as double?,
      targetWeightLb: map['target_weight_lb'] as double?,
      isDualBar: map['is_dual_bar'] != null ? (map['is_dual_bar'] as int) == 1 : null,
      includeBarWeight: map['include_bar_weight'] != null ? (map['include_bar_weight'] as int) == 1 : null,
      barWeightKg: map['bar_weight_kg'] as double?,
      barWeightLb: map['bar_weight_lb'] as double?,
      manualPlatesJson: map['manual_plates_json'] as String?,
    );
  }

  ExerciseInventory copyWith({
    int? id,
    int? exerciseId,
    int? inventoryId,
    double? targetWeightKg,
    double? targetWeightLb,
    bool? isDualBar,
    bool? includeBarWeight,
    double? barWeightKg,
    double? barWeightLb,
    String? manualPlatesJson,
  }) {
    return ExerciseInventory(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      inventoryId: inventoryId ?? this.inventoryId,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetWeightLb: targetWeightLb ?? this.targetWeightLb,
      isDualBar: isDualBar ?? this.isDualBar,
      includeBarWeight: includeBarWeight ?? this.includeBarWeight,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      barWeightLb: barWeightLb ?? this.barWeightLb,
      manualPlatesJson: manualPlatesJson ?? this.manualPlatesJson,
    );
  }

  @override
  String toString() =>
      'ExerciseInventory(id: $id, exerciseId: $exerciseId, inventoryId: $inventoryId, targetKg: $targetWeightKg)';
}
