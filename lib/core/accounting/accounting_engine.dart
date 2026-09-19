import '../../models/trip_model.dart';
import '../../models/person_model.dart';
import '../../models/payment_model.dart';
import '../utils/app_formatters.dart';

class AccountingEngine {
  static Map<String, String> calculateTripStatuses(List<TripModel> rows) {
    Map<String, Map<String, dynamic>> purchases = {};
    for (var r in rows.where((t) => t.operation == 'purchase')) {
      purchases[r.id] = {
        'weight': r.weight,
        'remaining': r.weight,
        'item': AppFormatters.normalizeItem(r.item),
      };
    }

    Map<String, double> sold = {for (var id in purchases.keys) id: 0.0};
    Map<String, double> matched = {for (var r in rows) r.id: 0.0};
    Map<String, String> statuses = {};

    var linkedSales = rows.where((r) => r.operation == 'sale' && r.sourceTripId != null).toList();
    linkedSales.sort((a, b) => a.date.compareTo(b.date));

    for (var sale in linkedSales) {
      var purchase = purchases[sale.sourceTripId];
      if (purchase == null) {
        statuses[sale.id] = "مباع بدون شراء (المصدر محذوف)";
        continue;
      }
      double take = sale.weight <= purchase['remaining'] ? sale.weight : purchase['remaining'];
      purchase['remaining'] -= take;
      sold[sale.sourceTripId!] = (sold[sale.sourceTripId!] ?? 0.0) + take;
      matched[sale.id] = (matched[sale.id] ?? 0.0) + take;
      double remSale = sale.weight - take;

      if (remSale <= 0.0001) {
        statuses[sale.id] = "تم شراء الوزنة";
      } else if (take > 0.0001) {
        statuses[sale.id] = "جزء بدون شراء: ${remSale.toStringAsFixed(2)} طن";
      } else {
        statuses[sale.id] = "مباع بدون شراء: ${remSale.toStringAsFixed(2)} طن";
      }
    }

    Map<String, List<String>> queues = {};
    for (var r in rows.where((t) => t.operation == 'purchase')) {
      String it = AppFormatters.normalizeItem(r.item);
      queues.putIfAbsent(it, () => []).add(r.id);
    }

    for (var sale in rows.where((r) => r.operation == 'sale' && r.sourceTripId == null)) {
      String it = AppFormatters.normalizeItem(sale.item);
      var queue = queues[it] ?? [];
      double need = sale.weight;

      while (need > 0.0001 && queue.isNotEmpty) {
        String pid = queue.first;
        var p = purchases[pid]!;
        if (p['remaining'] <= 0.0001) {
          queue.removeAt(0);
          continue;
        }
        double take = need <= p['remaining'] ? need : p['remaining'];
        p['remaining'] -= take;
        need -= take;
        sold[pid] = (sold[pid] ?? 0.0) + take;
        matched[sale.id] = (matched[sale.id] ?? 0.0) + take;
        if (p['remaining'] <= 0.0001) {
          queue.removeAt(0);
        }
      }

      if (need <= 0.0001) {
        statuses[sale.id] = "تم شراء الوزنة";
      } else if ((matched[sale.id] ?? 0.0) > 0.0001) {
        statuses[sale.id] = "جزء بدون شراء: ${need.toStringAsFixed(2)} طن";
      } else {
        statuses[sale.id] = "لم يتم شراء هذه الوزنة";
      }
    }

    for (var r in rows.where((t) => t.operation == 'purchase')) {
      double rem = purchases[r.id]!['remaining'];
      double sld = sold[r.id] ?? 0.0;
      if (rem <= 0.0001) {
        statuses[r.id] = "تم بيع الوزنة";
      } else if (sld <= 0.0001) {
        statuses[r.id] = "لم يتم بيع هذه الوزنة";
      } else {
        statuses[r.id] = "متبقي للبيع: ${rem.toStringAsFixed(2)} طن";
      }
    }

    return statuses;
  }

  static Map<String, dynamic> calculateRealProfits(List<TripModel> rows) {
    double totalRevenue = 0.0;
    double totalCOGS = 0.0;

    Map<String, List<Map<String, double>>> inventory = {};
    for (var p in rows.where((t) => t.operation == 'purchase')) {
      String it = AppFormatters.normalizeItem(p.item);
      inventory.putIfAbsent(it, () => []).add({
        'weight': p.weight,
        'cost_price': p.price,
      });
    }

    Map<String, Map<String, double>> itemProfits = {};

    for (var s in rows.where((t) => t.operation == 'sale')) {
      totalRevenue += s.total;
      double need = s.weight;
      String it = AppFormatters.normalizeItem(s.item);
      var batches = inventory[it] ?? [];
      double cogsForThisSale = 0.0;

      while (need > 0.0001 && batches.isNotEmpty) {
        var batch = batches.first;
        double take = need <= batch['weight']! ? need : batch['weight']!;
        cogsForThisSale += (take * batch['cost_price']!);
        batch['weight'] = batch['weight']! - take;
        need -= take;
        if (batch['weight']! <= 0.0001) {
          batches.removeAt(0);
        }
      }

      totalCOGS += cogsForThisSale;

      itemProfits.putIfAbsent(s.item, () => {'revenue': 0.0, 'cogs': 0.0});
      itemProfits[s.item]!['revenue'] = itemProfits[s.item]!['revenue']! + s.total;
      itemProfits[s.item]!['cogs'] = itemProfits[s.item]!['cogs']! + cogsForThisSale;
    }

    return {
      'revenue': totalRevenue,
      'cogs': totalCOGS,
      'profit': totalRevenue - totalCOGS,
      'items': itemProfits,
    };
  }

  static List<Map<String, dynamic>> calculateStatement(
    PersonModel person,
    List<TripModel> trips,
    List<PaymentModel> payments,
  ) {
    List<Map<String, dynamic>> events = [];
    
    double netOpening = person.openingReceivable - person.openingPayable;
    
    if (netOpening != 0) {
      events.add({
        'sort_time': 0, // لضمان ظهوره كأول حركة دائماً
        'date': 'أول المدة',
        'type': 'رصيد افتتاح',
        'desc': 'رصيد أول المدة',
        'vehicle': '',
        'driver': '',
        'weight': 0.0,
        'price': 0.0,
        'debit': netOpening > 0 ? netOpening : 0.0,
        'credit': netOpening < 0 ? netOpening.abs() : 0.0,
      });
    }

    for (var t in trips.where((t) => t.personId == person.id)) {
      events.add({
        'sort_time': DateTime.tryParse(t.date)?.millisecondsSinceEpoch ?? 1,
        'date': t.date,
        'type': t.operation == 'sale' ? 'بيع' : 'شراء',
        'desc': 'نقلة ${t.item} (${t.weight} طن)',
        'vehicle': t.vehicle,
        'driver': t.driver,
        'weight': t.weight,
        'price': t.price,
        'debit': t.operation == 'sale' ? t.total : 0.0,
        'credit': t.operation == 'purchase' ? t.total : 0.0,
      });
    }

    for (var p in payments.where((p) => p.personId == person.id)) {
      events.add({
        'sort_time': DateTime.tryParse(p.date)?.millisecondsSinceEpoch ?? 1,
        'date': p.date,
        'type': p.direction == 'from_customer' ? 'تحصيل من عميل' : 'سداد لمورد',
        'desc': p.description.isNotEmpty ? p.description : (p.direction == 'from_customer' ? 'تحصيل نقدي' : 'سداد نقدي'),
        'vehicle': '',
        'driver': '',
        'weight': 0.0,
        'price': 0.0,
        'debit': p.direction == 'to_supplier' ? p.amount : 0.0,
        'credit': p.direction == 'from_customer' ? p.amount : 0.0,
      });
    }

    events.sort((a, b) => (a['sort_time'] as int).compareTo(b['sort_time'] as int));

    double runningBalance = 0.0;
    for (var ev in events) {
      runningBalance += (ev['debit'] as double) - (ev['credit'] as double);
      ev['balance'] = runningBalance;
    }

    return events;
  }
}
