class RewardItem {
  const RewardItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.pointsCost,
    required this.stockQuantity,
    required this.iconKey,
    required this.isActive,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int pointsCost;
  final int stockQuantity;
  final String iconKey;
  final bool isActive;
  final String? imageUrl;

  factory RewardItem.fromMap(Map<String, Object?> map) => RewardItem(
    id: map['id']! as String,
    name: map['name']! as String,
    description: map['description']! as String,
    category: map['category']! as String,
    pointsCost: (map['points_cost']! as num).toInt(),
    stockQuantity: (map['stock_quantity']! as num).toInt(),
    iconKey: map['icon_key'] as String? ?? map['category'] as String,
    isActive: map['is_active'] as bool? ?? true,
    imageUrl: map['image_url'] as String?,
  );
}
