import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/widgets/transaction_dialogs.dart';
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
  final _remarkController = TextEditingController();

  int? _selectedAccountId;
  String _transactionType = 'expense'; // 'income' or 'expense'
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  File? _receiptImageFile;

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
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null && mounted) {
      final croppedFile = await ImageCropper.platform.cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ปรับแต่งรูปภาพ',
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'ปรับแต่งรูปภาพ',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() => _receiptImageFile = File(croppedFile.path));
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? date = await showRoundedDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
      borderRadius: 16,
      textPositiveButton: "ตกลง",
      textNegativeButton: "ยกเลิก",
      era: EraMode.BUDDHIST_YEAR,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);
    final isExpense = _transactionType == 'expense';

    // --- Overdraft Check ---
    if (isExpense) {
      final currentBalance = ref.watch(
        filteredBalanceProvider(_selectedAccountId!),
      );
      if (amount > currentBalance) {
        final accountName = ref
            .read(allAccountsProvider)
            .asData
            ?.value
            .firstWhereOrNull((acc) => acc.id == _selectedAccountId)
            ?.name;
        final continueAnyway = await showOverdraftWarningDialog(
          context: context,
          amount: amount,
          accountNames: accountName ?? 'บัญชีนี้',
        );

        if (!continueAnyway) {
          return; // User cancelled the overdraft
        }
      }
    }
    // --- End Overdraft Check ---

    // Get data for confirmation dialog
    final accounts = ref.read(allAccountsProvider).asData?.value ?? [];
    final selectedAccount = accounts.firstWhereOrNull(
      (acc) => acc.id == _selectedAccountId,
    );

    final confirmed = await showTransactionConfirmationDialog(
      context: context,
      transactionType: _transactionType,
      amount: amount,
      description: _descriptionController.text.trim(),
      remark: _remarkController.text.trim(),
      date: _selectedDate,
      accountNames: [selectedAccount?.name ?? 'ไม่พบ'],
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);

    final loggedInUser = ref.read(authProvider).user;
    if (loggedInUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    String? receiptImagePath;
    if (_receiptImageFile != null) {
      final appDocsDir = await getApplicationDocumentsDirectory();
      final fileExtension = p.extension(_receiptImageFile!.path);
      final newFileName = '${const Uuid().v4()}$fileExtension';
      receiptImagePath = p.join(appDocsDir.path, newFileName);
      await _receiptImageFile!.copy(receiptImagePath);
    }

    final newTransaction = Transaction(
      id: const Uuid().v4(),
      accountId: _selectedAccountId!,
      type: _transactionType,
      amount: amount,
      description: _descriptionController.text.trim(),
      remark: _remarkController.text.trim(),
      receiptImage: receiptImagePath,
      transactionDate: _selectedDate,
      createdByUserId: loggedInUser.id!,
      createdAt: DateTime.now(), // This was already here, which is great!
    );

    try {
      await ref
          .read(transactionsProvider.notifier)
          .addTransaction(newTransaction);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกธุรกรรมสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: '),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
            Center(child: Text('ไม่สามารถโหลดข้อมูลบัญชีได้: ')),
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
                      labelText: 'บัญชี',
                      border: OutlineInputBorder(),
                    ),
                    items: accounts
                        .map(
                          (account) => DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                        )
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
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: 'income',
                      label: Text('รายรับ'),
                      icon: Icon(Icons.arrow_downward),
                    ),
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
                    prefixText: '฿ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
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
                    labelText: 'คำอธิบาย',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 1,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'กรุณากรอกคำอธิบาย'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    labelText: 'หมายเหตุ (ไม่บังคับ)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'ใบเสร็จ (ไม่บังคับ)',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: _receiptImageFile == null
                        ? const Row(
                            children: [
                              Icon(Icons.add_a_photo_outlined),
                              SizedBox(width: 8),
                              Text('เลือกรูปภาพใบเสร็จ'),
                            ],
                          )
                        : Image.file(_receiptImageFile!, height: 100),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('วันที่และเวลาที่ทำรายการ'),
                  subtitle: Text(
                    DateFormatter.formatBE(
                      _selectedDate.toLocal(),
                      'd MMMM yyyy, HH:mm น.',
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                  tileColor: Colors.grey.shade100,
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
