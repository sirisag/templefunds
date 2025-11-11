import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
//import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/utils/account_sorter.dart';
import 'package:uuid/uuid.dart';

class AddMultiTransactionScreen extends ConsumerStatefulWidget {
  const AddMultiTransactionScreen({super.key});

  @override
  ConsumerState<AddMultiTransactionScreen> createState() =>
      _AddMultiTransactionScreenState();
}

class _AddMultiTransactionScreenState
    extends ConsumerState<AddMultiTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Set<int> _selectedAccountIds = {};
  String _transactionType = 'income'; // Default to income for this use case
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showRoundedDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
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
      final allAccounts = ref.read(allAccountsProvider).asData?.value ?? [];
      final allMembers = ref.read(membersProvider).asData?.value ?? [];
      final userMap = {for (var user in allMembers) user.id: user};

      final List<Account> overdraftAccounts = [];
      for (final accountId in _selectedAccountIds) {
        final currentBalance = ref.read(filteredBalanceProvider(accountId));
        if (amount > currentBalance) {
          final account = allAccounts.firstWhereOrNull(
            (acc) => acc.id == accountId,
          );
          if (account != null) {
            overdraftAccounts.add(account);
          }
        }
      }

      if (overdraftAccounts.isNotEmpty) {
        final accountNames = overdraftAccounts
            .map((acc) {
              final user = userMap[acc.ownerUserId];
              if (user != null) {
                return '${user.name} (ID: ${user.userId1})';
              }
              return acc.name;
            })
            .join('\n • ');

        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('คำเตือน: ยอดเงินไม่เพียงพอ'),
            content: SingleChildScrollView(
              child: Text(
                'การถอนเงินจำนวน ${NumberFormat("#,##0.00").format(amount)} ฿ จะทำให้บัญชีต่อไปนี้มียอดติดลบ:\n\n • $accountNames\n\nคุณต้องการดำเนินการต่อหรือไม่?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('อนุมัติยอดติดลบ'),
              ),
            ],
          ),
        );

        if (continueAnyway != true) {
          return; // User cancelled the overdraft
        }
      }
    }
    // --- End Overdraft Check ---

    // Get data for confirmation dialog
    final description = _descriptionController.text.trim();
    final typeText = _transactionType == 'income' ? 'รายรับ' : 'รายจ่าย';
    final dateText = DateFormatter.formatBE(
      _selectedDate.toLocal(),
      'd MMM yyyy, HH:mm',
    );

    // Get the full account and user objects for the selected IDs
    final allAccounts = ref.read(allAccountsProvider).asData?.value ?? [];
    final allMembers = ref.read(membersProvider).asData?.value ?? [];
    final userMap = {for (var user in allMembers) user.id: user};

    final selectedAccounts = allAccounts
        .where((acc) => _selectedAccountIds.contains(acc.id))
        .toList();

    final accountNames = selectedAccounts.map((acc) {
      final user = userMap[acc.ownerUserId];
      if (user != null) {
        return '${user.name} (ID: ${user.userId1})';
      }
      return acc.name; // Temple account
    }).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการบันทึก'),
        content: SingleChildScrollView(
          // To handle many selected accounts
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'กรุณาตรวจสอบข้อมูลก่อนบันทึก:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text('ประเภท: $typeText'),
              Text(
                'จำนวนเงิน (ต่อบัญชี): ฿${NumberFormat("#,##0.00").format(amount)}',
              ),
              Text('คำอธิบาย: $description'),
              Text('วันที่: $dateText'),
              const Divider(),
              Text(
                'สำหรับ ${selectedAccounts.length} บัญชี:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Display list of selected accounts
              ...accountNames.map(
                (name) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(' • $name'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('แก้ไข'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isLoading = true);

    final loggedInUser = ref.read(authProvider).user;
    if (loggedInUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    List<Transaction> transactionsToCreate = [];
    for (final accountId in _selectedAccountIds) {
      transactionsToCreate.add(
        Transaction(
          id: const Uuid().v4(),
          accountId: accountId,
          type: _transactionType,
          amount: amount,
          description: description,
          transactionDate: _selectedDate,
          createdByUserId: loggedInUser.id!,
          createdAt: DateTime.now(),
        ),
      );
    }

    try {
      await ref
          .read(transactionsProvider.notifier)
          .addMultipleTransactions(transactionsToCreate);

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
            content: Text('เกิดข้อผิดพลาด: $e'),
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
    final membersAsync = ref.watch(membersProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ฝาก-ถอน')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            const Center(child: Text('ไม่สามารถโหลดข้อมูลบัญชีได้')),
        data: (accounts) {
          return transactionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                const Center(child: Text('ไม่สามารถโหลดข้อมูลธุรกรรมได้')),
            data: (allTransactions) {
              return membersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    const Center(child: Text('ไม่สามารถโหลดข้อมูลสมาชิกได้')),
                data: (members) {
                  final sortedAccounts = sortAccountsForTransaction(
                    accounts,
                    members,
                    allTransactions,
                  );
                  final userMap = {for (var user in members) user.id: user};

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'เลือกบัญชี',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          Expanded(
                            child: _buildMultiSelect(sortedAccounts, userMap),
                          ),
                          const SizedBox(height: 8),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            SafeArea(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
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
                                        setState(
                                          () => _transactionType =
                                              newSelection.first,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _amountController,
                                          decoration: const InputDecoration(
                                            labelText: 'จำนวนเงิน',
                                            border: OutlineInputBorder(),
                                            prefixText: '฿ ',
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'^\d+\.?\d{0,2}'),
                                            ),
                                          ],
                                          validator: (v) =>
                                              (v == null ||
                                                  v.isEmpty ||
                                                  double.tryParse(v) == null ||
                                                  double.parse(v) <= 0)
                                              ? 'ระบุยอด'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        flex: 1,
                                        child: _buildDatePickerField(),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _descriptionController,
                                          decoration: const InputDecoration(
                                            labelText: 'คำอธิบาย',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (v) =>
                                              (v == null || v.trim().isEmpty)
                                              ? 'กรุณากรอกคำอธิบาย'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        flex: 1,
                                        child: ElevatedButton.icon(
                                          onPressed: _submit,
                                          icon: const Icon(Icons.save),
                                          label: const Text('บันทึกธุรกรรม'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDatePickerField() {
    return TextFormField(
      onTap: _pickDate,
      readOnly: true,
      controller: TextEditingController(
        text: DateFormatter.formatBE(
          _selectedDate.toLocal(),
          'd MMM yy, HH:mm',
        ),
      ),
      decoration: const InputDecoration(
        labelText: 'วันที่',
        border: OutlineInputBorder(),
        suffixIcon: Icon(Icons.calendar_today),
      ),
    );
  }

  Widget _buildMultiSelect(List<Account> accounts, Map<int?, User> userMap) {
    return FormField<Set<int>>(
      initialValue: _selectedAccountIds,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'กรุณาเลือกอย่างน้อยหนึ่งบัญชี';
        }
        return null;
      },
      builder: (formFieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: accounts.length,
                itemBuilder: (context, index) {
                  final account = accounts[index];
                  final user = userMap[account.ownerUserId];

                  String namePart;
                  String idPart = '';
                  if (user != null) {
                    namePart = user.name;
                    idPart = ' (ID: ${user.userId1})';
                  } else {
                    namePart = account.name; // For temple account
                  }

                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(fontSize: 18),
                        children: [
                          TextSpan(
                            text: namePart,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: idPart,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    value: _selectedAccountIds.contains(account.id),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedAccountIds.add(account.id!);
                        } else {
                          _selectedAccountIds.remove(account.id);
                        }
                        formFieldState.didChange(_selectedAccountIds);
                      });
                    },
                  );
                },
              ),
            ),
            if (formFieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  formFieldState.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
