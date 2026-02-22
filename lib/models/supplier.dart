class Supplier {
  final String name;
  double totalPurchases;
  double totalPaid;

  Supplier({
    required this.name,
    this.totalPurchases = 0,
    this.totalPaid = 0,
  });

  double get balance {
    return totalPurchases - totalPaid;
  }
}
