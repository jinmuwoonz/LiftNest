class Exercise {
  final int? id;
  final String name;
  final String? description;

  // Target weight
  final double? targetWeightKg;
  final double? targetWeightLb;

  // Workout config
  final int? sets;
  final int? repetitions;
  final int? restTimeSeconds; // rest time in seconds

  // Time-based config
  final bool needsReps; // true for reps, false for time (duration)
  final int? durationSeconds; // time per set if needsReps is false

  // Bar config
  /// true  → two independent bars, each must reach [targetWeightKg];
  ///         calculator will output "not enough" if inventory is insufficient for both.
  /// false → single bar reaching [targetWeightKg] in total.
  final bool isDualBar;
  final bool poolInventories; // whether to pool all inventories
  final bool includeBarWeight; // whether to subtract bar weight from target
  final double? barWeightKg;
  final double? barWeightLb;

  // Manual calculation & Bodyweight
  final bool needsWeight; // false for bodyweight/cardio
  final String? manualPlatesJson; // e.g. '{"1": 2, "3": 4}' (weightId -> qty)

  const Exercise({
    this.id,
    required this.name,
    this.description,
    this.targetWeightKg,
    this.targetWeightLb,
    this.sets,
    this.repetitions,
    this.restTimeSeconds,
    this.needsReps = true,
    this.durationSeconds,
    this.isDualBar = true,
    this.includeBarWeight = false,
    this.poolInventories = true,
    this.barWeightKg,
    this.barWeightLb,
    this.needsWeight = true,
    this.manualPlatesJson,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'target_weight_kg': targetWeightKg,
      'target_weight_lb': targetWeightLb,
      'sets': sets,
      'repetition': repetitions,
      'rest_time': restTimeSeconds,
      'needs_reps': needsReps ? 1 : 0,
      'duration_seconds': durationSeconds,
      'is_dual_bar': isDualBar ? 1 : 0,
      'include_bar_weight': includeBarWeight ? 1 : 0,
      'pool_inventories': poolInventories ? 1 : 0,
      'bar_weight_kg': barWeightKg,
      'bar_weight_lb': barWeightLb,
      'needs_weight': needsWeight ? 1 : 0,
      'manual_plates_json': manualPlatesJson,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      targetWeightKg: map['target_weight_kg'] as double?,
      targetWeightLb: map['target_weight_lb'] as double?,
      sets: map['sets'] as int?,
      repetitions: map['repetition'] as int?,
      restTimeSeconds: map['rest_time'] as int?,
      needsReps: (map['needs_reps'] as int? ?? 1) == 1,
      durationSeconds: map['duration_seconds'] as int?,
      isDualBar: (map['is_dual_bar'] as int? ?? 1) == 1,
      includeBarWeight: (map['include_bar_weight'] as int? ?? 0) == 1,
      poolInventories: (map['pool_inventories'] as int? ?? 1) == 1,
      barWeightKg: map['bar_weight_kg'] as double?,
      barWeightLb: map['bar_weight_lb'] as double?,
      needsWeight: (map['needs_weight'] as int? ?? 1) == 1,
      manualPlatesJson: map['manual_plates_json'] as String?,
    );
  }

  Exercise copyWith({
    int? id,
    String? name,
    String? description,
    double? targetWeightKg,
    double? targetWeightLb,
    int? sets,
    int? repetitions,
    int? restTimeSeconds,
    bool? needsReps,
    int? durationSeconds,
    bool? isDualBar,
    bool? includeBarWeight,
    bool? poolInventories,
    double? barWeightKg,
    double? barWeightLb,
    bool? needsWeight,
    String? manualPlatesJson,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetWeightLb: targetWeightLb ?? this.targetWeightLb,
      sets: sets ?? this.sets,
      repetitions: repetitions ?? this.repetitions,
      restTimeSeconds: restTimeSeconds ?? this.restTimeSeconds,
      needsReps: needsReps ?? this.needsReps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isDualBar: isDualBar ?? this.isDualBar,
      includeBarWeight: includeBarWeight ?? this.includeBarWeight,
      poolInventories: poolInventories ?? this.poolInventories,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      barWeightLb: barWeightLb ?? this.barWeightLb,
      needsWeight: needsWeight ?? this.needsWeight,
      manualPlatesJson: manualPlatesJson ?? this.manualPlatesJson,
    );
  }

  @override
  String toString() =>
      'Exercise(id: $id, name: $name, targetWeightKg: $targetWeightKg, '
      'sets: $sets, repetitions: $repetitions, isDualBar: $isDualBar)';
}
