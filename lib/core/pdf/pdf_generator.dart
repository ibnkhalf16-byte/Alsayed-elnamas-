import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/person_model.dart';

class PdfGenerator {
  static Future<void> generateAndPrintStatement({
    required PersonModel person,
    required List<Map<String, dynamic>> events,
  }) async {
    final pdf = pw.Document();

    // تحميل الخطوط محلياً من ملفات التطبيق بدلاً من الإنترنت لضمان عملها دائماً
    final ByteData fontRegularData = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final pw.Font fontRegular = pw.Font.ttf(fontRegularData);

    final ByteData fontBoldData = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
    final pw.Font fontBold = pw.Font.ttf(fontBoldData);

    final lastBalance = events.isNotEmpty
        ? (events.last['balance'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    final currentDateStr = DateTime.now().toString().substring(0, 16);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'حسابات السيد النماس',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Text(
                    'كشف حساب: ${person.name}',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'صفحة ${context.pageNumber}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'تم تصميم البرنامج بواسطة علي خلف',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Text(
                    'تاريخ الطباعة: $currentDateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E3A8A),
            ),
            headerHeight: 25,
            cellHeight: 22,
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            columnWidths: const {
              0: pw.FlexColumnWidth(2.4), // الرصيد
              1: pw.FlexColumnWidth(2.2), // دائن
              2: pw.FlexColumnWidth(2.2), // مدين
              3: pw.FlexColumnWidth(1.8), // سعر الطن
              4: pw.FlexColumnWidth(1.4), // طن
              5: pw.FlexColumnWidth(2.2), // السائق
              6: pw.FlexColumnWidth(1.8), // السيارة
              7: pw.FlexColumnWidth(2.6), // البيان
              8: pw.FlexColumnWidth(1.4), // الحركة
              9: pw.FlexColumnWidth(2.2), // التاريخ
            },
            headers: <String>[
              'الرصيد',
              'دائن',
              'مدين',
              'سعر الطن',
              'طن',
              'السائق',
              'السيارة',
              'البيان',
              'الحركة',
              'التاريخ',
            ],
            data: events.map((ev) {
              final double debit = (ev['debit'] as num?)?.toDouble() ?? 0.0;
              final double credit = (ev['credit'] as num?)?.toDouble() ?? 0.0;
              final double balance = (ev['balance'] as num?)?.toDouble() ?? 0.0;
              final double weight = (ev['weight'] as num?)?.toDouble() ?? 0.0;
              final double price = (ev['price'] as num?)?.toDouble() ?? 0.0;

              final String vehicle = (ev['vehicle'] ?? '').toString();
              final String driver = (ev['driver'] ?? '').toString();
              final String itemOrDesc = (ev['desc'] ?? '').toString();
              final String actionType = (ev['type'] ?? '').toString();

              return [
                balance.toStringAsFixed(2),
                credit > 0 ? credit.toStringAsFixed(2) : '0.00',
                debit > 0 ? debit.toStringAsFixed(2) : '0.00',
                price > 0 ? price.toStringAsFixed(2) : '',
                weight > 0 ? weight.toStringAsFixed(2) : '',
                driver,
                vehicle,
                itemOrDesc,
                actionType,
                ev['date']?.toString() ?? '',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey800, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  color: PdfColors.grey100,
                ),
                child: pw.Text(
                  'الرصيد النهائي: ${lastBalance.toStringAsFixed(2)} ج.م',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'كشف_حساب_${person.name}',
      format: PdfPageFormat.a4.landscape,
    );
  }
}
