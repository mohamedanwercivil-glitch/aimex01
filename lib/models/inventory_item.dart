/// =======================
/// INVENTORY ITEM MODEL
/// =======================
///
/// يمثل صنف واحد في المخزون
///

class InventoryItem {
  final String name;

  /// الكمية الحالية في المخزون
  int quantity;

  /// آخر سعر شراء
  double lastBuyPrice;

  /// آخر سعر بيع
  double lastSellPrice;

  InventoryItem({
    required this.name,
    this.quantity = 0,
    this.lastBuyPrice = 0,
    this.lastSellPrice = 0,
  });
}
