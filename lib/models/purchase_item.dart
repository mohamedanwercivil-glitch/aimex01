class PurchaseItem {
  final String name;
  final double qty;
  final double price;
  final bool isReturn;

  PurchaseItem({
    required this.name,
    required this.qty,
    required this.price,
    this.isReturn = false,
  });

  double get total => isReturn ? -(qty * price) : (qty * price);
}
