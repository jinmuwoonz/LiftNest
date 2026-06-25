class Inventory {
  final int? id;
  final String name;
  final String? description;

  const Inventory({
    this.id,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
    };
  }

  factory Inventory.fromMap(Map<String, dynamic> map) {
    return Inventory(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }

  Inventory copyWith({
    int? id,
    String? name,
    String? description,
  }) {
    return Inventory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  String toString() =>
      'Inventory(id: $id, name: $name, description: $description)';
}
