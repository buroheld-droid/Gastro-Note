class OrderLine {
  final String productId;
  final String productName;
  final double unitPrice;
  final double taxRate; // percent, e.g. 19.0
  final int quantity;

  const OrderLine({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.taxRate,
    required this.quantity,
  });

  double get lineSubtotal => unitPrice * quantity;
  double get lineTax => lineSubtotal * (taxRate / 100.0);
  double get lineTotal => lineSubtotal + lineTax;
}
