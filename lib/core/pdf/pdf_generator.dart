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
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
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
    // إنشاء صفحة PDF
    // ============================================================

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,

        // اتجاه المستند عربي
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
              // --------------------------------------------------
              // اسم البرنامج
              // --------------------------------------------------

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

              // --------------------------------------------------
              // اسم الشخص
              // --------------------------------------------------

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
        // تذييل الصفحة
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

              // ==================================================
              // التذييل مقسم إلى 3 أجزاء
              //
              // اليمين  = تاريخ الطباعة
              // المنتصف = تم تصميم البرنامج بواسطة علي خلف
              // اليسار = رقم الصفحة
              // ==================================================

              pw.Row(
                textDirection: pw.TextDirection.rtl,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // ==============================================
                  // يمين التذييل
                  // ==============================================

                  pw.Expanded(
                    child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'تاريخ الطباعة: $currentDateStr',
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),

                  // ==============================================
                  // منتصف التذييل
                  // ==============================================

                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Text(
                        'تم تصميم البرنامج بواسطة علي خلف',
                        textDirection: pw.TextDirection.rtl,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),

                  // ==============================================
                  // يسار التذييل
                  // ==============================================

                  pw.Expanded(
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        'صفحة ${context.pageNumber} من ${context.pagesCount}',
                        textDirection: pw.TextDirection.rtl,
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
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
          // جدول كشف الحساب
          // ======================================================

          pw.TableHelper.fromTextArray(
            context: context,

            // ----------------------------------------------------
            // حدود الجدول
            // ----------------------------------------------------

            border: pw.TableBorder.all(
              color: PdfColors.grey500,
              width: 0.5,
            ),

            // ----------------------------------------------------
            // اتجاه النص داخل الخلايا
            // ----------------------------------------------------

            cellDirection: pw.TextDirection.rtl,

            // ----------------------------------------------------
            // تنسيق رأس الجدول
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
            // تنسيق الخلايا
            // ----------------------------------------------------

            cellStyle: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
            ),

            cellHeight: 22,

            cellAlignment: pw.Alignment.center,

            // ====================================================
            // ترتيب الأعمدة
            //
            // الترتيب المرئي النهائي من اليمين إلى اليسار:
            //
            // التاريخ
            // الحركة
            // البيان
            // التحميل
            // السائق
            // طن
            // سعر الطن
            // مدين
            // دائن
            // الرصيد
            //
            // التاريخ = أقصى اليمين
            // الرصيد   = أقصى اليسار
            // ====================================================

            columnWidths: const {
              // أقصى اليسار
              0: pw.FlexColumnWidth(2.3), // الرصيد
              1: pw.FlexColumnWidth(2.0), // دائن
              2: pw.FlexColumnWidth(2.0), // مدين
              3: pw.FlexColumnWidth(1.7), // سعر الطن
              4: pw.FlexColumnWidth(1.2), // طن
              5: pw.FlexColumnWidth(2.1), // السائق
              6: pw.FlexColumnWidth(1.8), // التحميل
              7: pw.FlexColumnWidth(2.6), // البيان
              8: pw.FlexColumnWidth(1.4), // الحركة
              9: pw.FlexColumnWidth(2.1), // التاريخ
            },

            // ====================================================
            // عناوين الأعمدة
            //
            // القائمة معكوسة عمدًا لكي يظهر الجدول بصريًا
            // من اليمين إلى اليسار بالترتيب المطلوب.
            // ====================================================

            headers: <String>[
              'الرصيد',
              'دائن',
              'مدين',
              'سعر الطن',
              'طن',
              'السائق',
              'التحميل',
              'البيان',
              'الحركة',
              'التاريخ',
            ],

            // ====================================================
            // بيانات الجدول
            // ====================================================

            data: events.map((ev) {
              // --------------------------------------------------
              // القيم الرقمية
              // --------------------------------------------------

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

              // --------------------------------------------------
              // القيم النصية
              // --------------------------------------------------

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
              // ترتيب البيانات مطابق لترتيب headers
              // ==================================================

              return [
                // 1 - الرصيد
                balance.toStringAsFixed(2),

                // 2 - الدائن
                credit > 0
                    ? credit.toStringAsFixed(2)
                    : '0.00',

                // 3 - المدين
                debit > 0
                    ? debit.toStringAsFixed(2)
                    : '0.00',

                // 4 - سعر الطن
                price > 0
                    ? price.toStringAsFixed(2)
                    : '',

                // 5 - طن
                weight > 0
                    ? weight.toStringAsFixed(2)
                    : '',

                // 6 - السائق
                driver,

                // 7 - التحميل
                vehicle,

                // 8 - البيان
                itemOrDesc,

                // 9 - الحركة
                actionType,

                // 10 - التاريخ
                date,
              ];
            }).toList(),
          ),

          pw.SizedBox(height: 12),

          // ======================================================
          // الرصيد النهائي
          // ======================================================

          pw.Row(
            textDirection: pw.TextDirection.rtl,
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
    // فتح شاشة الطباعة / المعاينة
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
