٨import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/accounting/accounting_engine.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../trips/trips_screen.dart';
import '../payments/payments_screen.dart';
import '../statements/statement_screen.dart';
import '../profits/profits_screen.dart';
import '../persons/persons_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({Key? key, required this.onNavigateTab}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalReceivable = 0;
  double _totalPayable = 0;
  double _totalSales = 0;
  double _totalPurchases = 0;
  double _netProfit = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons');
    final tMaps = await db.query('trips');
    final payMaps = await db.query('payments');

    final persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
    final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final payments = payMaps.map((m) => PaymentModel.fromMap(m)).toList();

    double receivables = 0;
    double payables = 0;
    
    for (var p in persons) {
      final events = AccountingEngine.calculateStatement(p, trips, payments);
      final balance = events.isNotEmpty ? (events.last['balance'] as double) : 0.0;
      if (balance > 0) {
        receivables += balance;
      } else if (balance < 0) {
        payables += balance.abs();
      }
    }

    double sales = 0;
    double purchases = 0;
    for (var t in trips) {
      if (t.operation == 'sale') sales += t.total;
      if (t.operation == 'purchase') purchases += t.total;
    }

    final profitsData = AccountingEngine.calculateRealProfits(trips);

    if (mounted) {
      setState(() {
        _totalReceivable = receivables;
        _totalPayable = payables;
        _totalSales = sales;
        _totalPurchases = purchases;
        _netProfit = profitsData['profit'] ?? 0.0;
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.formatCurrency(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابات السيد النماس ', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('ملخص الحسابات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryCard('مستحق لك عند العملاء', _totalReceivable, AppColors.receivableGreen, Icons.account_balance_wallet_outlined),
                        const SizedBox(width: 12),
                        _buildSummaryCard('مطلوب للموردين', _totalPayable, AppColors.payableRed, Icons.money_off_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: AppColors.primary.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('صافي الأرصدة:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              AppFormatters.formatCurrency((_totalReceivable - _totalPayable).abs()),
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: (_totalReceivable - _totalPayable) >= 0 ? AppColors.receivableGreen : AppColors.payableRed
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryCard('المبيعات', _totalSales, AppColors.primary, Icons.storefront_outlined),
                        const SizedBox(width: 12),
                        _buildSummaryCard('المشتريات', _totalPurchases, AppColors.warningOrange, Icons.shopping_cart_outlined),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: AppColors.receivableGreen.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('صافي الأرباح المحققة:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              AppFormatters.formatCurrency(_netProfit),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.receivableGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 8,
                      children: [
                        _buildActionBtn(
                          title: 'نقلة شراء',
                          icon: Icons.local_shipping,
                          color: AppColors.warningOrange,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen(initialOperation: 'purchase')));
                          },
                        ),
                        _buildActionBtn(
                          title: 'نقلة بيع',
                          icon: Icons.local_shipping_outlined,
                          color: AppColors.primary,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const TripsScreen(initialOperation: 'sale')));
                          },
                        ),
                        _buildActionBtn(
                          title: 'تحصيل نقدية',
                          icon: Icons.add_card,
                          color: AppColors.receivableGreen,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen(initialDirection: 'from_customer')));
                          },
                        ),
                        _buildActionBtn(
                          title: 'سداد دفعة',
                          icon: Icons.credit_card,
                          color: AppColors.payableRed,
                          onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen(initialDirection: 'to_supplier')));
                          },
                        ),
                        _buildActionBtn(
                          title: 'إضافة طرف',
                          icon: Icons.person_add_alt_1,
                          color: Colors.blueAccent,
                          onTap: () {
                            widget.onNavigateTab(2);
                          },
                        ),
                        _buildActionBtn(
                          title: 'كشف حساب',
                          icon: Icons.receipt_long,
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatementScreen()));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
