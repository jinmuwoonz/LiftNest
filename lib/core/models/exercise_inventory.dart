class ExerciseInventory {
  final int? id;
  final int exerciseId;
  final int inventoryId;

  const ExerciseInventory({
    this.id,
    required this.exerciseId,
    required this.inventoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exercise_id': exerciseId,
      'inventory_id': inventoryId,
    };
  }

  factory ExerciseInventory.fromMap(Map<String, dynamic> map) {
    return ExerciseInventory(
      id: map['id'] as int?,
      exerciseId: map['exercise_id'] as int,
      inventoryId: map['inventory_id'] as int,
    );
  }

  ExerciseInventory copyWith({
    int? id,
    int? exerciseId,
    int? inventoryId,
  }) {
    return ExerciseInventory(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      inventoryId: inventoryId ?? this.inventoryId,
    );
  }

  @override
  String toString() =>
      'ExerciseInventory(id: $id, exerciseId: $exerciseId, inventoryId: $inventoryId)';
}
