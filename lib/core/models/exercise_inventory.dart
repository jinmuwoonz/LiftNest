class ExerciseInventory {
  final int? id;
  final int exerciseId;
  final int inventoryId;
  final double? targetWeightKg;
  final double? targetWeightLb;
  final String? manualPlatesJson;

  const ExerciseInventory({
    this.id,
    required this.exerciseId,
    required this.inventoryId,
    this.targetWeightKg,
    this.targetWeightLb,
    this.manualPlatesJson,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exercise_id': exerciseId,
      'inventory_id': inventoryId,
      'target_weight_kg': targetWeightKg,
      'target_weight_lb': targetWeightLb,
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
      manualPlatesJson: map['manual_plates_json'] as String?,
    );
  }

  ExerciseInventory copyWith({
    int? id,
    int? exerciseId,
    int? inventoryId,
    double? targetWeightKg,
    double? targetWeightLb,
    String? manualPlatesJson,
  }) {
    return ExerciseInventory(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      inventoryId: inventoryId ?? this.inventoryId,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetWeightLb: targetWeightLb ?? this.targetWeightLb,
      manualPlatesJson: manualPlatesJson ?? this.manualPlatesJson,
    );
  }

  @override
  String toString() =>
      'ExerciseInventory(id: $id, exerciseId: $exerciseId, inventoryId: $inventoryId, targetKg: $targetWeightKg)';
}
