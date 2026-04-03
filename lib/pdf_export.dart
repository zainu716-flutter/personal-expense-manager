import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'indian_format.dart';

// ── PDF Export Helper ─────────────────────────
class PdfExportHelper with IndianFormatMixin {
  // ── Export to PDF ─────────────────────────────
  Future<void> exportToPdf(
    BuildContext context,
    List<DocumentSnapshot> docs,
    double totalIn,
    double totalOut,
    double balance,
    String accountName,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Personal Expense Manager',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Account: $accountName',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 13),
                ),
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy - hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _pdfSummaryItem(
                  'Total Cash In',
                  'Rs.${formatIndian(totalIn)}',
                  PdfColors.green700,
                ),
                _pdfSummaryItem(
                  'Total Cash Out',
                  'Rs.${formatIndian(totalOut)}',
                  PdfColors.red700,
                ),
                _pdfSummaryItem(
                  'Balance',
                  'Rs.${formatIndian(balance)}',
                  balance >= 0 ? PdfColors.blue700 : PdfColors.orange700,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Transactions (${docs.length})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey800),
                children: [
                  _pdfTableHeader('Title'),
                  _pdfTableHeader('Date'),
                  _pdfTableHeader('Amount'),
                  _pdfTableHeader('Type'),
                ],
              ),
              ...docs.map((doc) {
                final date = (doc['date'] as Timestamp).toDate();
                final isCashIn = doc['type'] == 'cash_in';
                return pw.TableRow(
                  children: [
                    _pdfTableCell(doc['title']),
                    _pdfTableCell(
                      DateFormat('dd MMM yyyy hh:mm a').format(date),
                    ),
                    _pdfTableCell(
                      'Rs.${formatIndian((doc['amount'] as num).toDouble())}',
                      color: isCashIn ? PdfColors.green700 : PdfColors.red700,
                    ),
                    _pdfTableCell(
                      isCashIn ? 'IN' : 'OUT',
                      color: isCashIn ? PdfColors.green700 : PdfColors.red700,
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Personal Expense Manager - Exported Report',
              style: pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Expense_${accountName}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _pdfSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, {PdfColor? color}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, color: color ?? PdfColors.black),
      ),
    );
  }
}