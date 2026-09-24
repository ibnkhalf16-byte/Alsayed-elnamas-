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
    // تحميل الخط العربي
    // ============================================================
    final regularFontData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    );

    final fontRegular = pw.Font.ttf(regularFontData);
    final fontBold = pw.Font.ttf(boldFontData);

    // ============================================================
    // تجهيز الحركات
    //
    // إذا كان رصيد أول المدة = صفر:
    // لا يتم إظهاره كمدين أو دائن ولا يتم احتسابه مرة أخرى.
    // ============================================================
    final cleanedEvents = events.map((ev) {
      final copy = Map<String, dynamic>.from(ev);

      final type = (copy['type'] ?? '').toString().trim();

      final isOpeningBalance =
          type == 'أول المدة' ||
          type == 'رصيد أول المدة' ||
          type.toLowerCase() == 'opening' ||
          type.toLowerCase() == 'opening_balance';

      if (isOpeningBalance) {
        final debit =
            (copy['debit'] as num?)?.toDouble() ?? 0.0;

        final credit =
            (copy['credit'] as num?)?.toDouble() ?? 0.0;

        // إذا كان أول المدة صفر، نتركه بدون قيم مالية.
        if (debit.abs() < 0.000001 &&
            credit.abs() < 0.000001) {
          copy['debit'] = null;
          copy['credit'] = null;
          copy['balance'] = null;
        }
      }

      return copy;
    }).toList();

    // ============================================================
    // الرصيد النهائي
    //
    // نأخذ آخر رصيد فعلي وليس رصيد حركة أول المدة الفارغة.
    // ============================================================
    double lastBalance = 0.0;

    for (int i = cleanedEvents.length - 1; i >= 0; i--) {
      final balance =
          (cleanedEvents[i]['balance'] as num?)?.toDouble();

      if (balance != null) {
        lastBalance = balance;
        break;
      }
    }

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
            crossAxisAlignment:
                pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'حسابات السيد النماس',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 19,
                    color: PdfColors.blueGrey900,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'كشف حساب: ${person.name}',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
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

              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'صفحة ${context.pageNumber} من ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),

                  pw.Text(
                    'تم تصميم البرنامج بواسطة علي خلف',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 10,
                      color: PdfColors.blueGrey900,
                    ),
                  ),

                  pw.Text(
                    'تاريخ الطباعة: $currentDateStr',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 9,
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
          pw.TableHelper.fromTextArray(
            context: context,

            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.5,
            ),

            headerStyle: pw.TextStyle(
              font: fontBold,
              fontSize: 9,
              color: PdfColors.white,
            ),

            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E3A8A),
            ),

            headerHeight: 25,

            cellStyle: pw.TextStyle(
              font: fontRegular,
              fontSize: 8.5,
            ),

            cellHeight: 22,

            cellAlignment: pw.Alignment.center,

            // ====================================================
            // ترتيب الأعمدة:
            //
            // من اليمين:
            // التاريخ
            // الحركة
            // البيان
            // التحميل
            // السائق
            // وزن
            // سعر الطن
            // مدين
            // دائن
            // الرصيد
            // ====================================================
            columnWidths: const {
              0: pw.FlexColumnWidth(2.1), // التاريخ
              1: pw.FlexColumnWidth(1.4), // الحركة
              2: pw.FlexColumnWidth(2.6), // البيان
              3: pw.FlexColumnWidth(1.8), // التحميل
              4: pw.FlexColumnWidth(2.1), // السائق
              5: pw.FlexColumnWidth(1.2), // وزن
              6: pw.FlexColumnWidth(1.8), // سعر الطن
              7: pw.FlexColumnWidth(2.0), // مدين
              8: pw.FlexColumnWidth(2.0), // دائن
              9: pw.FlexColumnWidth(2.3), // الرصيد
            },

            headers: <String>[
              'التاريخ',
              'الحركة',
              'البيان',
              'التحميل',
              'السائق',
              'وزن',
              'سعر الطن',
              'مدين',
              'دائن',
              'الرصيد',
            ],

            // ====================================================
            // بيانات الجدول
            // ====================================================
            data: cleanedEvents.map((ev) {
              final double debit =
                  (ev['debit'] as num?)?.toDouble() ?? 0.0;

              final double credit =
                  (ev['credit'] as num?)?.toDouble() ?? 0.0;

              final double balance =
                  (ev['balance'] as num?)?.toDouble() ?? 0.0;

              final double weight =
                  (ev['weight'] as num?)?.toDouble() ?? 0.0;

              // سعر الطن
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

              // ==================================================
              // التحقق من حركة أول المدة
              // ==================================================
              final bool isOpeningBalance =
                  actionType.trim() == 'أول المدة' ||
                  actionType.trim() == 'رصيد أول المدة' ||
                  actionType.trim().toLowerCase() == 'opening' ||
                  actionType.trim().toLowerCase() ==
                      'opening_balance';

              final bool openingIsZero =
                  isOpeningBalance &&
                  debit.abs() < 0.000001 &&
                  credit.abs() < 0.000001;

              return [
                // 1 - التاريخ
                date,

                // 2 - الحركة
                actionType,

                // 3 - البيان
                itemOrDesc,

                // 4 - التحميل
                vehicle,

                // 5 - السائق
                driver,

                // 6 - الوزن
                weight > 0
                    ? weight.toStringAsFixed(2)
                    : '',

                // 7 - سعر الطن
                price > 0
                    ? price.toStringAsFixed(2)
                    : '',

                // 8 - مدين
                openingIsZero
                    ? ''
                    : debit > 0
                        ? debit.toStringAsFixed(2)
                        : '0.00',

                // 9 - دائن
                openingIsZero
                    ? ''
                    : credit > 0
                        ? credit.toStringAsFixed(2)
                        : '0.00',

                // 10 - الرصيد
                openingIsZero
                    ? ''
                    : balance.toStringAsFixed(2),
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 12),

          // ======================================================
          // الرصيد النهائي أسفل الجدول
          // ======================================================
          pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.start,
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

                  borderRadius:
                      const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),

                  color: PdfColors.grey100,
                ),

                child: pw.Text(
                  'الرصيد النهائي: ${lastBalance.toStringAsFixed(2)} ج.م',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 11,
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
  
