class Workout {
  final int? id;
  final String name;
  final String? description;
  final String? day; // e.g. 'Monday', 'Tuesday', etc.

  const Workout({
    this.id,
    required this.name,
    this.description,
    this.day,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'day': day,
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      day: map['day'] as String?,
    );
  }

  Workout copyWith({
    int? id,
    String? name,
    String? description,
    String? day,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      day: day ?? this.day,
    );
  }

  @override
  String toString() =>
      'Workout(id: $id, name: $name, description: $description, day: $day)';
}
