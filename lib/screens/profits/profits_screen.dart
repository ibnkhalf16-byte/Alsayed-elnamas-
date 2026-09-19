import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/accounting/accounting_engine.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/trip_model.dart';

class ProfitsScreen extends StatefulWidget {
  const ProfitsScreen({Key? key}) : super(key: key);

  @override
  State<ProfitsScreen> createState() => _ProfitsScreenState();
}

class _ProfitsScreenState extends State<ProfitsScreen> {
  Map<String, dynamic>? _profitData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfits();
  }

  Future<void> _loadProfits() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('trips', orderBy: 'date ASC');
    final trips = maps.map((m) => TripModel.fromMap(m)).toList();

    final profits = AccountingEngine.calculateRealProfits(trips);

    if (mounted) {
      setState(() {
        _profitData = profits;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profitData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final double revenue = (_profitData!['revenue'] as num).toDouble();
    final double cogs = (_profitData!['cogs'] as num).toDouble();
    final double netProfit = (_profitData!['profit'] as num).toDouble();
    final items = _profitData!['items'] as Map<String, Map<String, double>>;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تقرير الأرباح الحقيقي')),
        body: ListView(
          padding: const EdgeInsets.all(12.0),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي المبيعات:', style: TextStyle(fontSize: 14)),
                        Text(
                          AppFormatters.formatCurrency(revenue),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.receivableGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تكلفة البضاعة المباعة (COGS):', style: TextStyle(fontSize: 14)),
                        Text(
                          AppFormatters.formatCurrency(cogs),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.warningOrange),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صافي الأرباح المحققة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          AppFormatters.formatCurrency(netProfit),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: netProfit >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                'تفصيل أرباح الأصناف وفق نظام FIFO:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'لا توجد عمليات بيع لحساب الأرباح',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...items.entries.map((e) {
                final itemRev = e.value['revenue'] ?? 0.0;
                final itemCogs = e.value['cogs'] ?? 0.0;
                final itemProfit = itemRev - itemCogs;

                return Card(
                  child: ListTile(
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'مبيعات: ${itemRev.toStringAsFixed(2)} | تكلفة: ${itemCogs.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      AppFormatters.formatCurrency(itemProfit),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: itemProfit >= 0 ? AppColors.receivableGreen : AppColors.payableRed,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
