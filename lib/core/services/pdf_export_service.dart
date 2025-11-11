import 'package:flutter/services.dart';
import 'dart:io';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';

class PdfExportService {
  Future<Uint8List> generateTempleMonthlyReport({
    required String templeName,
    required User? adminUser,
    required User? masterUser,
    required String accountName,
    required DateTime month,
    required List<Transaction> transactions,
    required double monthlyIncome,
    required double monthlyExpense,
    required double totalBalance,
    required double startingBalance,
    String? logoPath,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final fontData = await rootBundle.load("assets/fonts/Sarabun-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Sarabun-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    final theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);

    final currencyFormat = NumberFormat("#,##0.00", "th_TH");
    final monthFormat = DateFormat.yMMMM('th');

    // Calculate the balance at the start of the month
    // final startingBalance = totalBalance - (monthlyIncome - monthlyExpense);

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildFirstPageHeader(
            templeName: templeName,
            logoPath: logoPath,
            adminUser: adminUser,
            masterUser: masterUser,
            accountName: accountName,
            month: month,
          ),
          pw.SizedBox(height: 15),
          _buildSummary(
            monthlyIncome: monthlyIncome,
            monthlyExpense: monthlyExpense,
            totalBalance: totalBalance,
            startingBalance: startingBalance,
            currencyFormat: currencyFormat,
          ),
          pw.SizedBox(height: 15),
          _buildTransactionTable(transactions, currencyFormat, startingBalance),
          pw.SizedBox(height: 40), // Fixed space after the table
          _buildSignatureSection(masterUser: masterUser, adminUser: adminUser),
        ],
        footer: (context) {
          return _buildFooter(
            pageNumber: context.pageNumber,
            totalPages: context.pagesCount,
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> generateMemberMonthlyReport({
    required String templeName,
    required User memberUser,
    required User? adminUser,
    required DateTime month,
    required List<Transaction> transactions,
    required double monthlyIncome,
    required double monthlyExpense,
    required double totalBalance,
    required double startingBalance,
    String? logoPath,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final fontData = await rootBundle.load("assets/fonts/Sarabun-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Sarabun-Bold.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldTtf = pw.Font.ttf(boldFontData);

    final theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);

    final currencyFormat = NumberFormat("#,##0.00", "th_TH");
    final monthFormat = DateFormat.yMMMM('th');

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildFirstPageHeader(
            templeName: templeName,
            logoPath: logoPath,
            memberUser: memberUser,
            adminUser: adminUser,
            month: month,
          ),
          pw.SizedBox(height: 15),
          _buildSummary(
            monthlyIncome: monthlyIncome,
            monthlyExpense: monthlyExpense,
            totalBalance: totalBalance,
            startingBalance: startingBalance,
            currencyFormat: currencyFormat,
          ),
          pw.SizedBox(height: 15),
          _buildTransactionTable(transactions, currencyFormat, startingBalance),
          pw.SizedBox(height: 15), // Fixed space after the table
          // For member reports, we still need the same signatures
          _buildSignatureSection(
            masterUser: null, // Master doesn't sign individual member reports
            adminUser: adminUser,
          ),
        ],
        footer: (context) {
          return _buildFooter(
            pageNumber: context.pageNumber,
            totalPages: context.pagesCount,
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildFirstPageHeader({
    required String templeName,
    String? logoPath,
    User? adminUser,
    User? masterUser,
    User? memberUser,
    String? accountName, // For temple report
    required DateTime month,
  }) {
    pw.Widget? logoWidget;
    if (logoPath != null) {
      final imageFile = File(logoPath);
      if (imageFile.existsSync()) {
        logoWidget = pw.Image(pw.MemoryImage(imageFile.readAsBytesSync()),
            width: 50, height: 50, fit: pw.BoxFit.contain);
      }
    }

    final headerText = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(templeName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 19)),
        if (accountName != null) // Temple Report
          pw.Text('รายงานสรุปยอดบัญชี: $accountName',
              style: const pw.TextStyle(fontSize: 16)),
        if (memberUser != null) // Member Report
          pw.Text(
              'รายงานบัญชีส่วนตัว: ${memberUser.name} (ID: ${memberUser.userId1})',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
        pw.Text('ประจำเดือน: ${DateFormatter.formatBE(month, 'MMMM yyyy')}'),
        pw.SizedBox(height: 8),
        if (masterUser != null)
          pw.Text('เจ้าอาวาส: ${masterUser.name} (ID: ${masterUser.userId1})'),
        if (adminUser != null)
          pw.Text('ผู้จัดทำ: ${adminUser.name} (ID: ${adminUser.userId1})'),
        pw.SizedBox(height: 8),
        pw.Text(
            'พิมพ์เมื่อ: ${DateFormatter.formatBE(DateTime.now(), "d MMM yyyy (HH:mm\'น.\')")}'),
      ],
    );

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoWidget != null)
              pw.Container(
                  width: 60,
                  height: 60,
                  margin: const pw.EdgeInsets.only(right: 16),
                  child: logoWidget),
            pw.Expanded(child: headerText),
          ],
        ),
        pw.Divider(height: 20),
      ],
    );
  }

  pw.Widget _buildSummary({
    required double monthlyIncome,
    required double monthlyExpense,
    required double totalBalance,
    required double startingBalance,
    required NumberFormat currencyFormat,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'สรุปยอด',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('ยอดยกมา:'),
            pw.Text('${currencyFormat.format(startingBalance)} บาท'),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('รายรับเดือนนี้:'),
            pw.Text('${currencyFormat.format(monthlyIncome)} บาท'),
          ],
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('รายจ่ายเดือนนี้:'),
            pw.Text('${currencyFormat.format(monthlyExpense)} บาท'),
          ],
        ),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'ยอดคงเหลือ:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${currencyFormat.format(totalBalance)} บาท',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTransactionTable(
    List<Transaction> transactions,
    NumberFormat currencyFormat,
    double startingBalance,
  ) {
    var runningBalance = startingBalance;
    return pw.Table.fromTextArray(
      headers: ['วันที่', 'รายการ', 'รายรับ', 'รายจ่าย', 'ยอดคงเหลือ'],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      data: transactions.map((t) {
        final date = DateFormatter.formatBE(
          t.transactionDate.toLocal(),
          "d MMM yyyy (HH:mm'น.')",
        );
        final income =
            t.type == 'income' ? currencyFormat.format(t.amount) : '';
        final expense =
            t.type == 'expense' ? currencyFormat.format(t.amount) : '';

        if (t.type == 'income') {
          runningBalance += t.amount;
        } else {
          runningBalance -= t.amount;
        }

        return [
          date,
          t.description ?? '',
          income,
          expense,
          currencyFormat.format(runningBalance),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildSignatureSection({
    required User? masterUser,
    required User? adminUser,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildSignatureBlock(role: 'เจ้าอาวาส', user: masterUser),
        _buildSignatureBlock(role: 'ไวยาวัจกรณ์', user: adminUser),
      ],
    );
  }

  pw.Widget _buildSignatureBlock({required String role, User? user}) {
    final String nameText = user != null
        ? '${user.name} (ID: ${user.userId1})'
        : '                              ';

    return pw.Column(
      children: [
        pw.Text('........................................................'),
        pw.SizedBox(height: 4),
        pw.Text('( $nameText )'),
        pw.SizedBox(height: 2),
        pw.Text(role),
      ],
    );
  }

  pw.Widget _buildFooter({required int pageNumber, required int totalPages}) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'หน้า $pageNumber / $totalPages',
        style: const pw.TextStyle(color: PdfColors.grey),
      ),
    );
  }
}
