import 'package:flutter/services.dart' show rootBundle;
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

    // ============================================================
    // تحميل الخط العربي من داخل التطبيق
    // ============================================================

    final regularFontData = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSansArabic-Bold.ttf',
    );

    final fontRegular = pw.Font.ttf(
      regularFontData,
    );

    final fontBold = pw.Font.ttf(
      boldFontData,
    );

    // ============================================================
    // الرصيد النهائي
    // ============================================================

    final lastBalance = events.isNotEmpty
        ? (events.last['balance'] as num?)?.toDouble() ?? 0.0
        : 0.0;

    // ============================================================
    // تاريخ الطباعة
    // ============================================================

    final now = DateTime.now();

    final currentDateStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // ============================================================
    // إنشاء الصفحة
    // ============================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,

        textDirection: pw.TextDirection.rtl,

        margin: const pw.EdgeInsets.only(
          left: 18,
          right: 18,
          top: 15,
          bottom: 18,
        ),

        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),

        // ========================================================
        // رأس الصفحة
        // ========================================================

        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [

              // اسم البرنامج
              pw.Center(
                child: pw.Text(
                  'حسابات السيد النماس',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 19,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              // اسم الشخص
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'كشف حساب: ${person.name}',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),

              pw.SizedBox(height: 7),
            ],
          );
        },

        // ========================================================
        // أسفل الصفحة
        // ========================================================

        footer: (pw.Context context) {
          return pw.Column(
            children: [

              pw.SizedBox(height: 8),

              pw.Divider(
                color: PdfColors.grey400,
                thickness: 0.5,
              ),

              pw.SizedBox(height: 3),

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [

                  pw.Text(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),

                  pw.Text(
                    'تاريخ الطباعة: $currentDateStr',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          );
        },

        // ========================================================
        // محتوى التقرير
        // ========================================================

        build: (pw.Context context) => [

          // ======================================================
          // الجدول
          // ======================================================

          pw.TableHelper.fromTextArray(

            context: context,

            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.5,
            ),

            // ----------------------------------------------------
            // الهيدر
            // ----------------------------------------------------

            headerStyle: pw.TextStyle(
              font: fontBold,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),

            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(
                0xFF1E3A8A,
              ),
            ),

            headerHeight: 25,

            // ----------------------------------------------------
            // الخلايا
            // ----------------------------------------------------

            cellStyle: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
            ),

            cellHeight: 22,

            cellAlignment: pw.Alignment.center,

            columnWidths: const {
              0: pw.FlexColumnWidth(2.1), // التاريخ
              1: pw.FlexColumnWidth(1.4), // الحركة
              2: pw.FlexColumnWidth(2.6), // البيان
              3: pw.FlexColumnWidth(1.8), // التحميل
              4: pw.FlexColumnWidth(2.1), // السائق
              5: pw.FlexColumnWidth(1.2), // طن
              6: pw.FlexColumnWidth(1.7), // سعر الطن
              7: pw.FlexColumnWidth(2.0), // مدين
              8: pw.FlexColumnWidth(2.0), // دائن
              9: pw.FlexColumnWidth(2.3), // الرصيد
            },

            // ====================================================
            // العناوين
            // ====================================================

            headers: <String>[
              'التاريخ',
              'الحركة',
              'البيان',
              'التحميل',
              'السائق',
              'طن',
              'سعر الطن',
              'مدين',
              'دائن',
              'الرصيد',
            ],

            // ====================================================
            // البيانات
            // ====================================================

            data: events.map((ev) {

              final double debit =
                  (ev['debit'] as num?)?.toDouble() ?? 0.0;

              final double credit =
                  (ev['credit'] as num?)?.toDouble() ?? 0.0;

              final double balance =
                  (ev['balance'] as num?)?.toDouble() ?? 0.0;

              final double weight =
                  (ev['weight'] as num?)?.toDouble() ?? 0.0;

              final double price =
                  (ev['price'] as num?)?.toDouble() ?? 0.0;

              final String vehicle =
                  (ev['vehicle'] ?? '').toString();

              final String driver =
                  (ev['driver'] ?? '').toString();

              final String itemOrDesc =
                  (ev['desc'] ?? '').toString();

              final String actionType =
                  (ev['type'] ?? '').toString();

              final String date =
                  ev['date']?.toString() ?? '';

              return [
                date,
                actionType,
                itemOrDesc,
                vehicle,
                driver,
                weight > 0 ? weight.toStringAsFixed(2) : '',
                price > 0 ? price.toStringAsFixed(2) : '',
                debit > 0 ? debit.toStringAsFixed(2) : '0.00',
                credit > 0 ? credit.toStringAsFixed(2) : '0.00',
                balance.toStringAsFixed(2),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 12),

          // ======================================================
          // الرصيد النهائي
          // ======================================================

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),

                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.blueGrey800,
                    width: 1,
                  ),

                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),

                  color: PdfColors.grey100,
                ),

                child: pw.Text(
                  'الرصيد النهائي: '
                  '${lastBalance.toStringAsFixed(2)} ج.م',

                  textDirection: pw.TextDirection.rtl,

                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 11,
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

    // ============================================================
    // فتح شاشة الطباعة
    // ============================================================

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdf.save();
      },

      name: 'كشف_حساب_${person.name}',

      format: PdfPageFormat.a4.landscape,
    );
  }
}
