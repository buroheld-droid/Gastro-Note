class OrderLine {
  final String productId;
  final String productName;
  final double unitPrice; // Brutto (mit MwSt)
  final double taxRate; // percent, e.g. 19.0
  final int quantity;

  const OrderLine({
    required this.productId,
    required this.productName,
    required this.unitPrice, // Brutto
    required this.taxRate,
    required this.quantity,
  });

  /// Berechne Netto-Betrag aus Brutto
  /// Formel: Netto = Brutto / (1 + Steuersatz/100)
  double _calculateNetFromGross(double gross, double taxRate) {
    return gross / (1.0 + (taxRate / 100.0));
  }

  /// Gesamtbetrag Brutto (mit MwSt)
  double get lineTotal => unitPrice * quantity;

  /// Netto-Betrag (ohne MwSt)
  double get lineSubtotal {
    final net = _calculateNetFromGross(unitPrice, taxRate);
    return net * quantity;
  }

  /// MwSt-Betrag
  double get lineTax => lineTotal - lineSubtotal;
}
