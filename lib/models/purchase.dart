class Purchase {
  final String supplierName;
  final String itemName;
  final String unitType;
  final int quantity;
  final double purchasePrice;
  final double total;
  final double invoiceTotal;
  final double paidAmount;
  final double dueAmount;
  final String paymentType;
  final String? wallet;
  final DateTime date;

  Purchase({
    required this.supplierName,
    required this.itemName,
    required this.unitType,
    required this.quantity,
    required this.purchasePrice,
    required this.total,
    required this.invoiceTotal,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentType,
    this.wallet,
    required this.date,
  });
}
