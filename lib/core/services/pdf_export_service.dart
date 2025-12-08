import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Corrected prefix to pw
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
    // final monthFormat = DateFormat.yMMMM('th'); // Not directly used here

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
    // final monthFormat = DateFormat.yMMMM('th'); // Not directly used here

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
          // Removed signature section for member reports
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

  /// Formats a user's name for display in the PDF report.
  /// It constructs a formal name string from various user fields.
  String _formatUserNameForPdf(User user) {
    final parts = <String>[];

    // Add special title if available
    if (user.specialTitle?.trim().isNotEmpty ?? false) {
      parts.add(user.specialTitle!.trim());
    }

    // Add first and last name
    if (user.firstName?.trim().isNotEmpty ?? false) {
      parts.add(user.firstName!.trim());
    }
    if (user.lastName?.trim().isNotEmpty ?? false) {
      parts.add(user.lastName!.trim());
    }

    // If no formal name parts are available, fall back to the nickname.
    if (parts.isEmpty) {
      return user.nickname;
    }

    return parts.join(' ');
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
    // debugPrint('[_buildFirstPageHeader] logoPath: $logoPath');
    pw.Widget? logoWidget;
    if (logoPath != null) {
      final imageFile = File(logoPath);
      // debugPrint(
      //     '[_buildFirstPageHeader] Checking if logo file exists at: ${imageFile.path}');
      if (imageFile.existsSync()) {
        try {
          final image = pw.MemoryImage(imageFile.readAsBytesSync());
          logoWidget = pw.ClipOval(
            child: pw.Image(
              image,
              width: 120, // Increased size
              height: 120, // Increased size
              fit: pw.BoxFit.cover, // Use cover for better circular clipping
            ),
          );
          // debugPrint('[_buildFirstPageHeader] Logo file read successfully.');
        } catch (e) {
          // debugPrint('[_buildFirstPageHeader] Error reading logo file: ');
        }
      } else {
        // debugPrint('[_buildFirstPageHeader] Logo file does NOT exist.');
      }
    }

    final headerText = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(templeName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 19)),
        // --- Temple Report Specifics ---
        if (accountName != null)
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 16),
              children: [
                const pw.TextSpan(text: 'รายงานสรุปยอดบัญชี: '),
                pw.TextSpan(
                  text: accountName,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        // --- Member Report Specifics ---
        if (memberUser != null) ...[
          pw.Text('รายงานบัญชีส่วนตัว',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.SizedBox(height: 2),
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 14),
              children: [
                const pw.TextSpan(text: 'ประจำเดือน: '),
                pw.TextSpan(
                  text: DateFormatter.formatBE(month, 'MMMM yyyy '),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.SizedBox(width: 70, child: pw.Text('ชื่อ-นามสกุล:')),
            pw.Text(_formatUserNameForPdf(memberUser)),
          ]),
          if (memberUser.ordinationName?.isNotEmpty ?? false)
            pw.Row(children: [
              pw.SizedBox(width: 70, child: pw.Text('ฉายา:')),
              pw.Text(memberUser.ordinationName!),
            ]),
          pw.Row(children: [
            pw.SizedBox(width: 70, child: pw.Text('ID ประจำตัว:')),
            pw.Text(memberUser.userId1),
          ]),
        ] else ...[
          // This block is for Temple Report only, when memberUser is null
          pw.RichText(
            text: pw.TextSpan(
              style: const pw.TextStyle(fontSize: 14),
              children: [
                const pw.TextSpan(text: 'ประจำเดือน: '),
                pw.TextSpan(
                  text: DateFormatter.formatBE(month, 'MMMM yyyy'),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 8),
        if (masterUser != null) ...[
          // Conditionally show the title row
          if (masterUser.specialTitle?.trim().isNotEmpty ?? false)
            pw.Row(children: [
              pw.SizedBox(width: 70, child: pw.Text('เจ้าอาวาส:')),
              pw.Text(masterUser.specialTitle!.trim()), // Not bold anymore
            ]),
          pw.Row(children: [
            // If there's no title, show the label here. Otherwise, just indent.
            pw.SizedBox(
                width: 70,
                child: (masterUser.specialTitle?.trim().isEmpty ?? true)
                    ? pw.Text('เจ้าอาวาส:')
                    : null),
            pw.Text(
                '${masterUser.firstName ?? ''} ${masterUser.lastName ?? ''} (${masterUser.ordinationName ?? ''})'),
          ]),
        ],
        // --- Admin and Print Date Section (for both reports) ---
        if (adminUser != null) ...[
          pw.SizedBox(height: 2),
          pw.Row(children: [
            pw.SizedBox(width: 70, child: pw.Text('ผู้จัดทำ:')),
            pw.Text(_formatUserNameForPdf(adminUser)),
          ]),
        ],
        pw.SizedBox(height: 2),
        pw.Row(children: [
          pw.SizedBox(width: 70, child: pw.Text('พิมพ์เมื่อ:')),
          pw.Text(
              DateFormatter.formatBE(DateTime.now(), "d MMM yyyy (HH:mm'น.')")),
        ]),
      ],
    );

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: headerText),
            if (logoWidget != null)
              pw.Container(
                width: 120, // Adjust container width to match image
                child: logoWidget,
              ),
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
    String titleLine = '';
    String nameLine;

    if (user != null) {
      // Line 1: Special Title
      titleLine = user.specialTitle?.trim() ?? '';

      // Line 2: (FirstName LastName)
      final nameParts = [
        user.firstName?.trim() ?? '',
        user.lastName?.trim() ?? ''
      ].where((part) => part.isNotEmpty).join(' ');
      nameLine = '( $nameParts )';
    } else {
      nameLine = '(........................................................)';
    }

    return pw.Column(
      children: [
        pw.Text('........................................................'),
        pw.SizedBox(height: 4),
        pw.SizedBox(
            height: 16, // Fixed height container for the title
            child: titleLine.isNotEmpty ? pw.Text(titleLine) : pw.SizedBox()),
        pw.Text(nameLine),
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
