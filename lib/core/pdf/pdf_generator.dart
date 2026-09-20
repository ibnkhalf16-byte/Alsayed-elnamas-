import 'dart:typed_data';

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
    try {
      // تحميل الخط العربي
      final regularFontData = await rootBundle.load(
        'assets/fonts/NotoNaskhArabic-Regular.ttf',
      );

      final boldFontData = await rootBundle.load(
        'assets/fonts/NotoNaskhArabic-Bold.ttf',
      );

      final regularFont = pw.Font.ttf(
        regularFontData,
      );

      final boldFont = pw.Font.ttf(
        boldFontData,
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          textDirection: pw.TextDirection.rtl,
          build: (context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'كشف حساب',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 22,
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  pw.Text(
                    'الطرف: ${person.name}',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 15,
                    ),
                  ),

                  if (person.phone.isNotEmpty)
                    pw.Text(
                      'الهاتف: ${person.phone}',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                      ),
                    ),

                  if (person.address.isNotEmpty)
                    pw.Text(
                      'العنوان: ${person.address}',
                      style: pw.TextStyle(
                        font: regularFont,
                        fontSize: 11,
                      ),
                    ),

                  pw.SizedBox(height: 15),

                  if (events.isEmpty)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(20),
                      child: pw.Center(
                        child: pw.Text(
                          'لا توجد حركة مسجلة لهذا الطرف',
                          style: pw.TextStyle(
                            font: regularFont,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  else
                    pw.Expanded(
                      child: pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColors.grey600,
                        ),
                        columnWidths: const {
                          0: pw.FlexColumnWidth(1.1),
                          1: pw.FlexColumnWidth(2.4),
                          2: pw.FlexColumnWidth(1.4),
                          3: pw.FlexColumnWidth(1.4),
                          4: pw.FlexColumnWidth(1.4),
                          5: pw.FlexColumnWidth(1.6),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.grey300,
                            ),
                            children: [
                              _headerCell('التاريخ', boldFont),
                              _headerCell('البيان', boldFont),
                              _headerCell('مدين', boldFont),
                              _headerCell('دائن', boldFont),
                              _headerCell('الرصيد', boldFont),
                              _headerCell('نوع الحركة', boldFont),
                            ],
                          ),

                          ...events.map(
                            (event) {
                              final date =
                                  event['date']?.toString() ?? '';

                              final description =
                                  event['description']
                                          ?.toString() ??
                                      event['title']
                                          ?.toString() ??
                                      '';

                              final debit =
                                  (event['debit'] as num?)
                                          ?.toDouble() ??
                                      0.0;

                              final credit =
                                  (event['credit'] as num?)
                                          ?.toDouble() ??
                                      0.0;

                              final balance =
                                  (event['balance'] as num?)
                                          ?.toDouble() ??
                                      0.0;

                              final type =
                                  event['type']?.toString() ?? '';

                              return pw.TableRow(
                                children: [
                                  _cell(date, regularFont),
                                  _cell(
                                    description,
                                    regularFont,
                                  ),
                                  _cell(
                                    _formatMoney(debit),
                                    regularFont,
                                  ),
                                  _cell(
                                    _formatMoney(credit),
                                    regularFont,
                                  ),
                                  _cell(
                                    _formatMoney(balance),
                                    regularFont,
                                  ),
                                  _cell(
                                    type,
                                    regularFont,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  pw.SizedBox(height: 12),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColors.grey600,
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment:
                          pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'الرصيد الختامي',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          _formatMoney(
                            events.isEmpty
                                ? person.openingReceivable -
                                    person.openingPayable
                                : ((events.last['balance']
                                            as num?)
                                        ?.toDouble() ??
                                    0.0),
                          ),
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  pw.Text(
                    'تم إنشاء التقرير بواسطة برنامج حسابات علاء أبو شادي',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();

      if (pdfBytes.isEmpty) {
        throw Exception('تم إنشاء ملف PDF فارغ.');
      }

      await Printing.layoutPdf(
        name: 'كشف_حساب_${person.name}',
        onLayout: (PdfPageFormat format) async {
          return pdfBytes;
        },
      );
    } catch (e, stackTrace) {
      print('PDF ERROR: $e');
      print(stackTrace);

      rethrow;
    }
  }

  static pw.Widget _headerCell(
    String text,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _cell(
    String text,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 9,
        ),
      ),
    );
  }

  static String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
  }
}
