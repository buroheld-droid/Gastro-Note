class Product {
  final String id;
  final String name;
  final String? description;
  final String? sku;
  final String? categoryId;
  final double price;
  final double? costPrice;
  final double taxRate;
  final String unit;
  final int stockQuantity;
  final bool trackStock;
  final bool isActive;
  final String? imageUrl;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.sku,
    this.categoryId,
    required this.price,
    this.costPrice,
    required this.taxRate,
    required this.unit,
    required this.stockQuantity,
    required this.trackStock,
    required this.isActive,
    this.imageUrl,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String?,
      categoryId: json['category_id'] as String?,
      price: (json['price'] as num).toDouble(),
      costPrice: json['cost_price'] != null ? (json['cost_price'] as num).toDouble() : null,
      taxRate: (json['tax_rate'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'Stück',
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      trackStock: json['track_stock'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'category_id': categoryId,
      'price': price,
      'cost_price': costPrice,
      'tax_rate': taxRate,
      'unit': unit,
      'stock_quantity': stockQuantity,
      'track_stock': trackStock,
      'is_active': isActive,
      'image_url': imageUrl,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}
