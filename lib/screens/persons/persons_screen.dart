import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../../core/accounting/accounting_engine.dart';
import '../../models/person_model.dart';
import '../../models/trip_model.dart';
import '../../models/payment_model.dart';
import '../statements/statement_screen.dart';

class PersonsScreen extends StatefulWidget {
  const PersonsScreen({Key? key}) : super(key: key);

  @override
  State<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends State<PersonsScreen> {
  List<Map<String, dynamic>> _personsWithBalances = [];
  List<Map<String, dynamic>> _filteredPersons = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPersonsAndCalculateBalances();
  }

  Future<void> _loadPersonsAndCalculateBalances() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    // جلب جميع البيانات اللازمة للحساب
    final personsData = await db.query('persons');
    final tripsData = await db.query('trips');
    final paymentsData = await db.query('payments');

    final List<PersonModel> persons = personsData.map((e) => PersonModel.fromMap(e)).toList();
    final List<TripModel> allTrips = tripsData.map((e) => TripModel.fromMap(e)).toList();
    final List<PaymentModel> allPayments = paymentsData.map((e) => PaymentModel.fromMap(e)).toList();

    List<Map<String, dynamic>> computedList = [];

    for (var person in persons) {
      // استخدام المحرك المحاسبي لحساب كشف الحساب الفعلي لكل طرف
      final statement = AccountingEngine.calculateStatement(person, allTrips, allPayments);
      
      // الرصيد الفعلي هو رصيد آخر حركة في كشف الحساب، أو الرصيد الافتتاحي إذا لم توجد حركات
      double actualBalance = 0.0;
      if (statement.isNotEmpty) {
        actualBalance = statement.last['balance'] as double;
      } else {
        actualBalance = person.openingReceivable - person.openingPayable;
      }

      computedList.add({
        'person': person,
        'actual_balance': actualBalance,
      });
    }

    setState(() {
      _personsWithBalances = computedList;
      _filteredPersons = computedList;
      _isLoading = false;
    });
  }

  void _filterPersons(String query) {
    setState(() {
      _searchQuery = query;
      _filteredPersons = _personsWithBalances.where((p) {
        final person = p['person'] as PersonModel;
        return person.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('دليل العملاء والموردين'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            color: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: _filterPersons,
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطرف...',
                fillColor: Colors.white,
                filled: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPersons.isEmpty
                    ? const Center(child: Text('لا يوجد أطراف مسجلة', style: TextStyle(fontSize: 16)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredPersons.length,
                        itemBuilder: (context, index) {
                          final data = _filteredPersons[index];
                          final PersonModel person = data['person'];
                          final double balance = data['actual_balance'];

                          // تحديد حالة الرصيد ولون الكارت
                          bool isOwedToYou = balance > 0;
                          bool isOwedByYou = balance < 0;
                          
                          Color statusColor = Colors.grey;
                          String statusText = 'رصيد مصفر';
                          
                          if (isOwedToYou) {
                            statusColor = const Color(0xFF10B981); // أخضر
                            statusText = 'مستحق لك عنده';
                          } else if (isOwedByYou) {
                            statusColor = const Color(0xFFEF4444); // أحمر
                            statusText = 'مطلوب له عندك';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
                            ),
                            elevation: 0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withOpacity(0.1),
                                child: Text(
                                  person.name.substring(0, 1),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                person.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusText,
                                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${balance.abs().toStringAsFixed(2)} ج.م',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  // خيارات إضافية للطرف
                                },
                              ),
                              onTap: () {
                                // فتح كشف الحساب
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StatementScreen(person: person),
                                  ),
                                ).then((_) => _loadPersonsAndCalculateBalances()); // تحديث الرصيد عند العودة
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // دالة إضافة طرف جديد
        },
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('إضافة طرف', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

