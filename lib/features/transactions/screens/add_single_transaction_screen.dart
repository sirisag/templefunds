import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:uuid/uuid.dart';

class AddSingleTransactionScreen extends ConsumerStatefulWidget {
  final Account? preselectedAccount;

  const AddSingleTransactionScreen({super.key, this.preselectedAccount});

  @override
  ConsumerState<AddSingleTransactionScreen> createState() =>
      _AddSingleTransactionScreenState();
}

class _AddSingleTransactionScreenState
    extends ConsumerState<AddSingleTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedAccountId;
  String _transactionType = 'expense'; // 'income' or 'expense'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedAccount != null) {
      _selectedAccountId = widget.preselectedAccount!.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final loggedInUser = ref.read(authProvider).user;
    if (loggedInUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final newTransaction = Transaction(
      id: const Uuid().v4(),
      accountId: _selectedAccountId!,
      type: _transactionType,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim(),
      transactionDate: _selectedDate,
      createdByUserId: loggedInUser.id!,
      createdAt: DateTime.now(),
    );

    try {
      await ref
          .read(transactionsProvider.notifier)
          .addTransaction(newTransaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('บันทึกธุรกรรมสำเร็จ'),
              backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(allAccountsProvider);
    final title = widget.preselectedAccount != null
        ? 'ธุรกรรม: ${widget.preselectedAccount!.name}'
        : 'ธุรกรรมบัญชีเดี่ยว';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('ไม่สามารถโหลดข้อมูลบัญชีได้: $err')),
        data: (accounts) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.preselectedAccount == null)
                  DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(
                        labelText: 'บัญชี', border: OutlineInputBorder()),
                    items: accounts
                        .map((account) => DropdownMenuItem(
                            value: account.id, child: Text(account.name)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAccountId = value),
                    validator: (v) => v == null ? 'กรุณาเลือกบัญชี' : null,
                  ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'expense',
                        label: Text('รายจ่าย'),
                        icon: Icon(Icons.arrow_upward)),
                    ButtonSegment(
                        value: 'income',
                        label: Text('รายรับ'),
                        icon: Icon(Icons.arrow_downward)),
                  ],
                  selected: {_transactionType},
                  onSelectionChanged: (newSelection) =>
                      setState(() => _transactionType = newSelection.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                      labelText: 'จำนวนเงิน',
                      border: OutlineInputBorder(),
                      prefixText: '฿ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          double.tryParse(v) == null ||
                          double.parse(v) <= 0)
                      ? 'กรุณากรอกจำนวนเงินที่ถูกต้อง'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'คำอธิบาย', border: OutlineInputBorder()),
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'กรุณากรอกคำอธิบาย' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('วันที่ทำรายการ'),
                  subtitle: Text(DateFormat('d MMMM yyyy, HH:mm')
                      .format(_selectedDate.toLocal())),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save),
                        label: const Text('บันทึกธุรกรรม'),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}