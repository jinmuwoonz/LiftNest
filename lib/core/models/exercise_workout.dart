class ExerciseWorkout {
  final int? id;
  final int exerciseId;
  final int workoutId;
  final int sortOrder;

  const ExerciseWorkout({
    this.id,
    required this.exerciseId,
    required this.workoutId,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'exercise_id': exerciseId,
      'workout_id': workoutId,
      'sort_order': sortOrder,
    };
  }

  factory ExerciseWorkout.fromMap(Map<String, dynamic> map) {
    return ExerciseWorkout(
      id: map['id'] as int?,
      exerciseId: map['exercise_id'] as int,
      workoutId: map['workout_id'] as int,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  ExerciseWorkout copyWith({
    int? id,
    int? exerciseId,
    int? workoutId,
    int? sortOrder,
  }) {
    return ExerciseWorkout(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      workoutId: workoutId ?? this.workoutId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  String toString() =>
      'ExerciseWorkout(id: $id, exerciseId: $exerciseId, workoutId: $workoutId)';
}
