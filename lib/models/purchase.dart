class Purchase {
  final String supplierName;
  final String itemName;
  final String unitType;
  final int quantity;
  final double unitPrice;
  final double total;
  final String paymentType;
  final String? wallet;
  final DateTime date;

  Purchase({
    required this.supplierName,
    required this.itemName,
    required this.unitType,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.paymentType,
    this.wallet,
    required this.date,
  });
}
