class Weight {
  final int? id;
  final int inventoryId;
  final double weightKg;
  final double weightLb;
  final int quantity;
  final String? description;

  const Weight({
    this.id,
    required this.inventoryId,
    required this.weightKg,
    required this.weightLb,
    required this.quantity,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'inventory_id': inventoryId,
      'weight_kg': weightKg,
      'weight_lb': weightLb,
      'quantity': quantity,
      'description': description,
    };
  }

  factory Weight.fromMap(Map<String, dynamic> map) {
    return Weight(
      id: map['id'] as int?,
      inventoryId: map['inventory_id'] as int,
      weightKg: (map['weight_kg'] as num).toDouble(),
      weightLb: (map['weight_lb'] as num).toDouble(),
      quantity: map['quantity'] as int,
      description: map['description'] as String?,
    );
  }

  Weight copyWith({
    int? id,
    int? inventoryId,
    double? weightKg,
    double? weightLb,
    int? quantity,
    String? description,
  }) {
    return Weight(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      weightKg: weightKg ?? this.weightKg,
      weightLb: weightLb ?? this.weightLb,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
    );
  }

  @override
  String toString() =>
      'Weight(id: $id, inventoryId: $inventoryId, weightKg: $weightKg, '
      'weightLb: $weightLb, quantity: $quantity)';
}
