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
    // لا يتم إظهاره كمدين أو دائن أو رصيد.
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
    // نأخذ آخر رصيد فعلي موجود.
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
                  'حسابات علاء ابو شادي',
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
                textDirection: pw.TextDirection.rtl,
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
        build: (pw.Context context) {
          // ======================================================
          // بناء صفوف الجدول
          //
          // مهم جدًا:
          //
          // Table العادي يرسم الأعمدة من اليسار إلى اليمين.
          //
          // لذلك نضع البيانات في القائمة بهذا الترتيب:
          //
          // الرصيد ← دائن ← مدين ← سعر الطن ← وزن
          // ← السائق ← التحميل ← البيان ← الحركة ← التاريخ
          //
          // وبالتالي:
          //
          // أقصى اليمين = التاريخ
          // أقصى اليسار = الرصيد
          // ======================================================

          final List<pw.TableRow> rows = [];

          // ======================================================
          // رأس الجدول
          // ======================================================
          rows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1E3A8A),
              ),
              children: [
                _headerCell('الرصيد', fontBold),
                _headerCell('دائن', fontBold),
                _headerCell('مدين', fontBold),
                _headerCell('سعر الطن', fontBold),
                _headerCell('وزن', fontBold),
                _headerCell('السائق', fontBold),
                _headerCell('التحميل', fontBold),
                _headerCell('البيان', fontBold),
                _headerCell('الحركة', fontBold),
                _headerCell('التاريخ', fontBold),
              ],
            ),
          );

          // ======================================================
          // بيانات الحركات
          // ======================================================
          for (final ev in cleanedEvents) {
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

            // ====================================================
            // التحقق من رصيد أول المدة
            // ====================================================
            final String normalizedType =
                actionType.trim().toLowerCase();

            final bool isOpeningBalance =
                normalizedType == 'أول المدة' ||
                normalizedType == 'رصيد أول المدة' ||
                normalizedType == 'opening' ||
                normalizedType == 'opening_balance';

            final bool openingIsZero =
                isOpeningBalance &&
                debit.abs() < 0.000001 &&
                credit.abs() < 0.000001;

            // ====================================================
            // إضافة صف
            //
            // الترتيب هنا مقصود:
            //
            // الرصيد
            // دائن
            // مدين
            // سعر الطن
            // وزن
            // السائق
            // التحميل
            // البيان
            // الحركة
            // التاريخ
            //
            // لأن Table يرسم من اليسار لليمين،
            // سيظهر التاريخ في أقصى اليمين.
            // ====================================================
            rows.add(
              pw.TableRow(
                children: [
                  // ------------------------------------------------
                  // الرصيد
                  // ------------------------------------------------
                  _dataCell(
                    openingIsZero
                        ? ''
                        : balance.toStringAsFixed(2),
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // دائن
                  // ------------------------------------------------
                  _dataCell(
                    openingIsZero
                        ? ''
                        : credit > 0
                            ? credit.toStringAsFixed(2)
                            : '0.00',
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // مدين
                  // ------------------------------------------------
                  _dataCell(
                    openingIsZero
                        ? ''
                        : debit > 0
                            ? debit.toStringAsFixed(2)
                            : '0.00',
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // سعر الطن
                  // ------------------------------------------------
                  _dataCell(
                    price > 0
                        ? price.toStringAsFixed(2)
                        : '',
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // الوزن
                  // ------------------------------------------------
                  _dataCell(
                    weight > 0
                        ? weight.toStringAsFixed(2)
                        : '',
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // السائق
                  // ------------------------------------------------
                  _dataCell(
                    driver,
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // التحميل
                  // ------------------------------------------------
                  _dataCell(
                    vehicle,
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // البيان
                  // ------------------------------------------------
                  _dataCell(
                    itemOrDesc,
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // الحركة
                  // ------------------------------------------------
                  _dataCell(
                    actionType,
                    fontRegular,
                  ),

                  // ------------------------------------------------
                  // التاريخ
                  // ------------------------------------------------
                  _dataCell(
                    date,
                    fontRegular,
                  ),
                ],
              ),
            );
          }

          // ======================================================
          // الجدول
          // ======================================================
          return [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey500,
                width: 0.5,
              ),

              // ====================================================
              // العرض النسبي للأعمدة
              //
              // ترتيب القائمة:
              // الرصيد - دائن - مدين - سعر الطن - وزن
              // - السائق - التحميل - البيان - الحركة - التاريخ
              //
              // النتيجة البصرية:
              // التاريخ ... الرصيد
              // ====================================================
              columnWidths: const {
                0: pw.FlexColumnWidth(2.3), // الرصيد
                1: pw.FlexColumnWidth(2.0), // دائن
                2: pw.FlexColumnWidth(2.0), // مدين
                3: pw.FlexColumnWidth(1.8), // سعر الطن
                4: pw.FlexColumnWidth(1.2), // وزن
                5: pw.FlexColumnWidth(2.1), // السائق
                6: pw.FlexColumnWidth(1.8), // التحميل
                7: pw.FlexColumnWidth(2.6), // البيان
                8: pw.FlexColumnWidth(1.4), // الحركة
                9: pw.FlexColumnWidth(2.1), // التاريخ
              },

              children: rows,
            ),

            pw.SizedBox(height: 12),

            // ====================================================
            // الرصيد النهائي
            // ====================================================
            pw.Row(
              mainAxisAlignment:
                  pw.MainAxisAlignment.start,
              textDirection: pw.TextDirection.rtl,
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
          ];
        },
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

  // ==============================================================
  // خلية رأس الجدول
  // ==============================================================
  static pw.Widget _headerCell(
    String text,
    pw.Font font,
  ) {
    return pw.Container(
      height: 25,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 4,
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
          color: PdfColors.white,
        ),
      ),
    );
  }

  // ==============================================================
  // خلية بيانات الجدول
  // ==============================================================
  static pw.Widget _dataCell(
    String text,
    pw.Font font,
  ) {
    return pw.Container(
      height: 22,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 3,
      ),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          font: font,
          fontSize: 8.5,
          color: PdfColors.black,
        ),
      ),
    );
  }
}



كما أن رصيد أول المدة = 0 سيظل فارغًا في مدين + دائن + الرصيد ولن يُستخدم كرصيد فعلي مرة أخرى.
