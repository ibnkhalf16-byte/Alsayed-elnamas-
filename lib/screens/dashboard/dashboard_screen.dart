import 'package:flutter/material.dart';
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

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const DashboardScreen({Key? key, required this.onNavigateTab}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<PersonModel> _persons = [];
  Map<String, double> _balances = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final pMaps = await db.query('persons', orderBy: 'name ASC');
    final tMaps = await db.query('trips');
    final payMaps = await db.query('payments');

    final persons = pMaps.map((m) => PersonModel.fromMap(m)).toList();
    final trips = tMaps.map((m) => TripModel.fromMap(m)).toList();
    final payments = payMaps.map((m) => PaymentModel.fromMap(m)).toList();

    Map<String, double> balancesMap = {};
    for (var p in persons) {
      final events = AccountingEngine.calculateStatement(p, trips, payments);
      final lastBalance = events.isNotEmpty ? (events.last['balance'] as double) : 0.0;
      balancesMap[p.id] = lastBalance;
    }

    if (mounted) {
      setState(() {
        _persons = persons;
        _balances = balancesMap;
        _isLoading = false;
      });
    }
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPersons = _persons.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابات السيد النماس'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'بحث عن عميل أو مورد...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // 1. الإجراءات السريعة (4 أزرار أساسية غير مكررة مع الشريط السفلي)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickActionItem(
                          icon: Icons.add_road,
                          label: 'تسجيل نقلة',
                          color: AppColors.primary,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TripsScreen()),
                            );
                            _loadDashboardData();
                          },
                        ),
                        _buildQuickActionItem(
                          icon: Icons.payments_outlined,
                          label: 'تسجيل سداد',
                          color: const Color(0xFF0284C7),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                            );
                            _loadDashboardData();
                          },
                        ),
                        _buildQuickActionItem(
                          icon: Icons.receipt_long,
                          label: 'كشف حساب',
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StatementScreen()),
                            );
                          },
                        ),
                        _buildQuickActionItem(
                          icon: Icons.trending_up,
                          label: 'تقارير ملخصة',
                          color: AppColors.receivableGreen,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfitsScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أرصدة العملاء والموردين الحالية:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab(2), // الانتقال لتبويب الأطراف
                      child: const Text('عرض الكل'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // 2. قائمة بطاقات الأطراف مع المؤشرات الدائرية الملونة للمديونيات والمستحقات
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : filteredPersons.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'لا توجد أطراف مسجلة مطابقة للبحث',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredPersons.length,
                          itemBuilder: (ctx, i) {
                            final p = filteredPersons[i];
                            final balance = _balances[p.id] ?? 0.0;
                            final isReceivable = balance >= 0;

                            return Card(
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isReceivable ? Icons.arrow_downward : Icons.arrow_upward,
                                      size: 20,
                                      color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                    ),
                                  ),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  isReceivable ? 'مستحق لك عنده' : 'مطلوب له عندك',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                  ),
                                ),
                                trailing: Text(
                                  AppFormatters.formatCurrency(balance.abs()),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StatementScreen(initialPerson: p),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
