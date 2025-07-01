import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:templefunds/core/models/account_model.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/widgets/app_dialogs.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
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
      _selectedDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'ยืนยันการบันทึก',
      content:
          'คุณต้องการบันทึกธุรกรรมนี้สำหรับ ${_selectedAccountIds.length} บัญชีใช่หรือไม่?',
    );

    // หากผู้ใช้กดยกเลิก (pop(false)) หรือปิด dialog (pop(null))
    // ให้หยุดการทำงาน
    if (confirmed != true) {
      return;
    }

    setState(() => _isLoading = true);

    final loggedInUser = ref.read(authProvider).user;
    if (loggedInUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text.trim();

    List<Transaction> transactionsToCreate = [];
    for (final accountId in _selectedAccountIds) {
      transactionsToCreate.add(Transaction(
        id: const Uuid().v4(),
        accountId: accountId,
        type: _transactionType,
        amount: amount,
        description: description,
        transactionDate: _selectedDate,
        createdByUserId: loggedInUser.id!,
        createdAt: DateTime.now(),
      ));
    }

    try {
      await ref
          .read(transactionsProvider.notifier)
          .addMultipleTransactions(transactionsToCreate);

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
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ฝาก-ถอน')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            const Center(child: Text('ไม่สามารถโหลดข้อมูลบัญชีได้')),
        data: (accounts) {
          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                const Center(child: Text('ไม่สามารถโหลดข้อมูลสมาชิกได้')),
            data: (members) {
              // --- Sorting Logic ---
              final Account? templeAccount =
                  accounts.firstWhereOrNull((acc) => acc.ownerUserId == null);

              final userMap = {for (var user in members) user.id: user};

              final memberAccounts =
                  accounts.where((acc) => acc.ownerUserId != null).toList();

              memberAccounts.sort((a, b) {
                final userA = userMap[a.ownerUserId];
                final userB = userMap[b.ownerUserId];

                if (userA == null) return 1;
                if (userB == null) return -1;

                int getRoleWeight(String role) {
                  switch (role) {
                    case 'Master':
                      return 0;
                    case 'Admin':
                      return 1;
                    case 'Monk':
                    default:
                      return 2;
                  }
                }

                final weightA = getRoleWeight(userA.role);
                final weightB = getRoleWeight(userB.role);

                if (weightA != weightB) {
                  return weightA.compareTo(weightB);
                }

                return a.name.compareTo(b.name);
              });

              final sortedAccounts = [
                if (templeAccount != null) templeAccount,
                ...memberAccounts,
              ];
              // --- End Sorting Logic ---

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'เลือกบัญชี',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _amountController,
                                    decoration: const InputDecoration(
                                        labelText: 'จำนวนเงิน',
                                        border: OutlineInputBorder(),
                                        prefixText: '฿ '),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d+\.?\d{0,2}'))
                                    ],
                                    validator: (v) => (v == null ||
                                            v.isEmpty ||
                                            double.tryParse(v) == null ||
                                            double.parse(v) <= 0)
                                        ? 'ระบุยอด'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _descriptionController,
                                    decoration: const InputDecoration(
                                        labelText: 'คำอธิบาย',
                                        border: OutlineInputBorder()),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'กรุณากรอกคำอธิบาย'
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                              onSelectionChanged: (newSelection) => setState(
                                  () => _transactionType = newSelection.first),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildDatePickerField(),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 5,
                                  child: ElevatedButton.icon(
                                    onPressed: _submit,
                                    icon: const Icon(Icons.save),
                                    label: const Text('บันทึกธุรกรรม'),
                                    style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDatePickerField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('d MMM yy, HH:mm').format(_selectedDate.toLocal()),
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
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

                  String displayName;
                  if (user != null) {
                    displayName = '${user.name} (ID: ${user.userId1})';
                  } else {
                    displayName = account.name; // For temple account
                  }

                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(displayName),
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
                      fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
