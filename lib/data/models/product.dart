import 'package:equatable/equatable.dart';

/// Product represents a product object.
class Product extends Equatable {
  final String id;
  final String name;
  final double price;

  const Product({required this.id, required this.name, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'price': price};
  }

  @override
  List<Object?> get props => [id, name, price];
}
