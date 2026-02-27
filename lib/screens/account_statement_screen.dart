import 'package:flutter/material.dart';
import '../data/customer_store.dart';
import '../data/supplier_store.dart';

class AccountStatementScreen extends StatefulWidget {
  const AccountStatementScreen({super.key});

  @override
  State<AccountStatementScreen> createState() => _AccountStatementScreenState();
}

class _AccountStatementScreenState extends State<AccountStatementScreen> {
  @override
  Widget build(BuildContext context) {
    double totalCustomerDebit = 0;
    double totalCustomerCredit = 0;
    for (var name in CustomerStore.getAllCustomers()) {
      double bal = CustomerStore.getBalance(name);
      if (bal > 0) totalCustomerDebit += bal; // عليه (مدين)
      else totalCustomerCredit += bal.abs(); // له (دائن)
    }

    double totalSupplierCredit = 0;
    double totalSupplierDebit = 0;
    for (var supplier in SupplierStore.suppliers) {
      double bal = SupplierStore.getBalance(supplier.name);
      if (bal > 0) totalSupplierCredit += bal; // له (دائن)
      else totalSupplierDebit += bal.abs(); // عليه (مدين)
    }

    return Scaffold(
      appBar: AppBar(title: const Text('كشف الحسابات التراكمي')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildLargeAccountButton(
              context,
              title: 'الموردين',
              subtitle: 'إجمالي دائن (لهم): ${totalSupplierCredit.toStringAsFixed(2)} | مدين (عليهم): ${totalSupplierDebit.toStringAsFixed(2)}',
              icon: Icons.local_shipping,
              color: Colors.orange.shade800,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const SupplierBalancesListScreen())
              ).then((_) => setState(() {})),
            ),
            const SizedBox(height: 30),
            _buildLargeAccountButton(
              context,
              title: 'العملاء',
              subtitle: 'إجمالي مدين (عليهم): ${totalCustomerDebit.toStringAsFixed(2)} | دائن (لهم): ${totalCustomerCredit.toStringAsFixed(2)}',
              icon: Icons.people,
              color: Colors.green.shade800,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const CustomerBalancesListScreen())
              ).then((_) => setState(() {})),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeAccountButton(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 60, color: Colors.white),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// --- شاشة تقرير حسابات الموردين ---
class SupplierBalancesListScreen extends StatefulWidget {
  const SupplierBalancesListScreen({super.key});

  @override
  State<SupplierBalancesListScreen> createState() => _SupplierBalancesListScreenState();
}

class _SupplierBalancesListScreenState extends State<SupplierBalancesListScreen> {
  String searchQuery = "";
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    var suppliersWithBalance = SupplierStore.suppliers
        .where((s) => SupplierStore.getBalance(s.name) != 0)
        .toList();

    // الترتيب: الأكثر استحقاقاً (ليه فلوس - رصيد موجب كبير) في الأعلى
    suppliersWithBalance.sort((a, b) => SupplierStore.getBalance(b.name).compareTo(SupplierStore.getBalance(a.name)));

    if (searchQuery.isNotEmpty) {
      suppliersWithBalance = suppliersWithBalance.where((s) => s.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }

    double totalCredit = 0;
    double totalDebit = 0;
    for (var s in suppliersWithBalance) {
      double bal = SupplierStore.getBalance(s.name);
      if (bal > 0) totalCredit += bal;
      else totalDebit += bal.abs();
    }

    return Scaffold(
      appBar: AppBar(
        title: isSearching 
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "بحث عن مورد...", hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
              onChanged: (val) => setState(() => searchQuery = val),
            )
          : const Text('تقرير حسابات الموردين'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('إسم المورد', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('دائن (له)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                Expanded(flex: 2, child: Text('مدين (عليه)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: suppliersWithBalance.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final name = suppliersWithBalance[index].name;
                final balance = SupplierStore.getBalance(name);
                double credit = balance > 0 ? balance : 0;
                double debit = balance < 0 ? balance.abs() : 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
                      Expanded(flex: 2, child: Text(credit > 0 ? credit.toStringAsFixed(2) : '0', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text(debit > 0 ? debit.toStringAsFixed(2) : '0', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green))),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.blueGrey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('الإجماليات', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text(totalCredit.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                Expanded(flex: 2, child: Text(totalDebit.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- شاشة تقرير حسابات العملاء ---
class CustomerBalancesListScreen extends StatefulWidget {
  const CustomerBalancesListScreen({super.key});

  @override
  State<CustomerBalancesListScreen> createState() => _CustomerBalancesListScreenState();
}

class _CustomerBalancesListScreenState extends State<CustomerBalancesListScreen> {
  String searchQuery = "";
  bool isSearching = false;

  @override
  Widget build(BuildContext context) {
    var customersWithBalance = CustomerStore.getAllCustomers()
        .where((name) => CustomerStore.getBalance(name) != 0)
        .toList();

    // الترتيب: الأكثر مديونية (عليه فلوس - رصيد موجب كبير) في الأعلى
    customersWithBalance.sort((a, b) => CustomerStore.getBalance(b).compareTo(CustomerStore.getBalance(a)));

    if (searchQuery.isNotEmpty) {
      customersWithBalance = customersWithBalance.where((name) => name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }

    double totalDebit = 0; // اللي عليه (مدين)
    double totalCredit = 0; // اللي ليه (دائن)
    for (var name in customersWithBalance) {
      double bal = CustomerStore.getBalance(name);
      if (bal > 0) totalDebit += bal; 
      else totalCredit += bal.abs();
    }

    return Scaffold(
      appBar: AppBar(
        title: isSearching 
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "بحث عن عميل...", hintStyle: TextStyle(color: Colors.white70), border: InputBorder.none),
              onChanged: (val) => setState(() => searchQuery = val),
            )
          : const Text('تقرير حسابات العملاء'),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('إسم العميل', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('مدين (عليه)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                Expanded(flex: 2, child: Text('دائن (له)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: customersWithBalance.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final name = customersWithBalance[index];
                final balance = CustomerStore.getBalance(name);
                double debitCol = balance > 0 ? balance : 0; // مدين (عليه)
                double creditCol = balance < 0 ? balance.abs() : 0; // دائن (له)

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15))),
                      Expanded(flex: 2, child: Text(debitCol > 0 ? debitCol.toStringAsFixed(2) : '0', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text(creditCol > 0 ? creditCol.toStringAsFixed(2) : '0', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green))),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.blueGrey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('الإجماليات', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                Expanded(flex: 2, child: Text(totalDebit.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))),
                Expanded(flex: 2, child: Text(totalCredit.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
