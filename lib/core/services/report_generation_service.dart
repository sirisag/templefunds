import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
//import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/services/pdf_export_service.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/settings/providers/settings_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';

/// A service to handle the logic of generating and displaying PDF reports.
class ReportGenerationService {
  final Ref _ref;

  ReportGenerationService(this._ref);

  /// Shows a month picker dialog.
  Future<DateTime?> pickMonth(BuildContext context) async {
    // Using flutter_rounded_date_picker to be consistent with other screens.
    // It will show the year in B.E. due to the era setting.
    return await showRoundedDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale("th", "TH"),
      era: EraMode.BUDDHIST_YEAR,
      initialDatePickerMode: DatePickerMode.day,
      theme: Theme.of(context),
    );
  }

  /// Generates and shows a print preview for the temple's monthly report.
  Future<void> generateAndShowTempleReport(
      BuildContext context, DateTime month) async {
    _showLoadingSnackbar(context, 'กำลังสร้างรายงานวัด...');

    try {
      // 1. Gather all required data from providers
      final templeName = await _ref.read(templeNameProvider.future);
      final allAccounts = await _ref.read(allAccountsProvider.future);      
      final allTransactions = _ref.read(transactionsProvider).asData?.value;
      final allMembers = _ref.read(membersProvider).asData?.value;
      final adminUser = _ref.read(authProvider).user;

      if (templeName == null) throw Exception('ไม่พบชื่อวัด');
      if (allTransactions == null) throw Exception('ข้อมูลธุรกรรมยังไม่พร้อม');
      if (allMembers == null) throw Exception('ข้อมูลสมาชิกยังไม่พร้อม');

      final templeAccount =
          allAccounts.firstWhereOrNull((acc) => acc.ownerUserId == null);
      if (templeAccount == null) throw Exception('ไม่พบบัญชีวัด');

      // 2. Filter and calculate data for the selected month
      final monthlyTransactions = _getMonthlyTransactions(
          allTransactions, templeAccount.id!, month);

      // Calculate the balance at the START of the selected month.
      final firstDayOfSelectedMonth = DateTime(month.year, month.month, 1);
      final startingBalance = _calculateBalanceUpTo(allTransactions, templeAccount.id!, firstDayOfSelectedMonth);
      
      final monthlyIncome = monthlyTransactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final monthlyExpense = monthlyTransactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      
      // The ending balance is the starting balance plus the net of the month's transactions.
      final endingBalance = startingBalance + monthlyIncome - monthlyExpense;

      final masterUser = allMembers.firstWhereOrNull((u) => u.role == UserRole.Master);

      // 3. Generate PDF
      final pdfService = PdfExportService();
      final pdfData = await pdfService.generateTempleMonthlyReport(
        templeName: templeName,
        adminUser: adminUser,
        masterUser: masterUser,
        accountName: templeAccount.name,
        month: month,
        transactions: monthlyTransactions,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        totalBalance: endingBalance, // This is the final balance for the summary
        startingBalance: startingBalance,
      );

      // 4. Show print preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name:
            'report_${templeName.replaceAll(' ', '_')}_${DateFormat('yyyy-MM', 'th').format(month)}.pdf',
      );
    } catch (e) {
      _showErrorSnackbar(context, e.toString());
    }
  }

  /// Generates and shows a print preview for a member's monthly report.
  Future<void> generateAndShowMemberReport(
      BuildContext context, DateTime month, int userId) async {
    _showLoadingSnackbar(context, 'กำลังสร้างรายงานส่วนตัว...');

    try {
      // 1. Gather all required data
      final templeName = await _ref.read(templeNameProvider.future);
      final allAccounts = await _ref.read(allAccountsProvider.future);      
      final allTransactions = _ref.read(transactionsProvider).asData?.value;
      final allMembers = _ref.read(membersProvider).asData?.value;
      final adminUser = _ref.read(authProvider).user;

      if (templeName == null) throw Exception('ไม่พบชื่อวัด');
      if (allTransactions == null) throw Exception('ข้อมูลธุรกรรมยังไม่พร้อม');
      if (allMembers == null) throw Exception('ข้อมูลสมาชิกยังไม่พร้อม');

      final memberUser = allMembers.firstWhereOrNull((u) => u.id == userId);
      if (memberUser == null) throw Exception('ไม่พบข้อมูลสมาชิก');

      final memberAccount =
          allAccounts.firstWhereOrNull((acc) => acc.ownerUserId == userId);
      if (memberAccount == null) throw Exception('ไม่พบบัญชีของสมาชิก');

      // 2. Filter and calculate
      final monthlyTransactions = _getMonthlyTransactions(
          allTransactions, memberAccount.id!, month);

      // Calculate the balance at the START of the selected month.
      final firstDayOfSelectedMonth = DateTime(month.year, month.month, 1);
      final startingBalance = _calculateBalanceUpTo(allTransactions, memberAccount.id!, firstDayOfSelectedMonth);

      final monthlyIncome = monthlyTransactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final monthlyExpense = monthlyTransactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      
      // The ending balance is the starting balance plus the net of the month's transactions.
      final endingBalance = startingBalance + monthlyIncome - monthlyExpense;

      // 3. Generate PDF
      final pdfService = PdfExportService();
      final pdfData = await pdfService.generateMemberMonthlyReport(
        templeName: templeName,
        memberUser: memberUser,
        adminUser: adminUser,
        month: month,
        transactions: monthlyTransactions,
        monthlyIncome: monthlyIncome,
        monthlyExpense: monthlyExpense,
        totalBalance: endingBalance,
        startingBalance: startingBalance,
      );

      // 4. Show print preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name:
            'report_${memberUser.name.replaceAll(' ', '_')}_${DateFormat('yyyy-MM', 'th').format(month)}.pdf',
      );
    } catch (e) {
      _showErrorSnackbar(context, e.toString());
    }
  }

  // --- Helper Methods ---

  List<Transaction> _getMonthlyTransactions(
      List<Transaction> all, int accountId, DateTime month) {
    final filtered = all.where((t) {
      final transactionDate = t.transactionDate.toLocal();
      return t.accountId == accountId &&
          transactionDate.year == month.year &&
          transactionDate.month == month.month;
    }).toList();
    // Sort ascending for the report
    filtered.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    return filtered;
  }

  double _calculateBalanceUpTo(
      List<Transaction> all, int accountId, DateTime beforeDate) {
    return all
        .where((t) => t.accountId == accountId && t.transactionDate.isBefore(beforeDate))
        .fold(0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
  }

  void _showLoadingSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorSnackbar(BuildContext context, String error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: ${error.replaceFirst("Exception: ", "")}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

// Provider for easy access to the service
final reportGenerationServiceProvider = Provider((ref) => ReportGenerationService(ref));
