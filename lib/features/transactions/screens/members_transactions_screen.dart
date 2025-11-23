import 'package:collection/collection.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rounded_date_picker/flutter_rounded_date_picker.dart';
import 'package:templefunds/core/models/transaction_model.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/members/screens/member_management_screen.dart';
import 'package:templefunds/features/members/widgets/user_profile_avatar.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/features/transactions/providers/transactions_provider.dart';
import 'package:templefunds/features/transactions/screens/add_multi_transaction_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';

/// A provider that filters transactions for ALL members for a specific day.
final dailyMembersTransactionsProvider = Provider.autoDispose
    .family<AsyncValue<List<Transaction>>, DateTime>((ref, day) {
  final allTransactionsAsync = ref.watch(transactionsProvider);
  final allAccountsAsync = ref.watch(allAccountsProvider);

  if (allTransactionsAsync.isLoading || allAccountsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (allTransactionsAsync.hasError) {
    return AsyncValue.error(
        allTransactionsAsync.error!, allTransactionsAsync.stackTrace!);
  }
  if (allAccountsAsync.hasError) {
    return AsyncValue.error(
        allAccountsAsync.error!, allAccountsAsync.stackTrace!);
  }

  try {
    final transactions = allTransactionsAsync.requireValue;
    final accounts = allAccountsAsync.requireValue;

    final memberAccountIds = accounts
        .where((acc) => acc.ownerUserId != null)
        .map((acc) => acc.id)
        .whereNotNull()
        .toSet();

    final filtered = transactions.where((t) {
      // Change filtering from transactionDate to createdAt
      final creationDate = t.createdAt.toLocal();
      return memberAccountIds.contains(t.accountId) &&
          creationDate.year == day.year &&
          creationDate.month == day.month &&
          creationDate.day == day.day;
    }).toList();

    // Sort the results by the creation timestamp
    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return AsyncValue.data(filtered);
  } catch (e, st) {
    return AsyncValue.error(e, st);
  }
});

/// A provider that calculates the summary (total income/expense) for a given day's transactions.
final dailySummaryProvider =
    Provider.autoDispose.family<double, DateTime>((ref, day) {
  // This provider now depends on the correctly filtered daily transactions.
  final dailyTransactionsAsync =
      ref.watch(dailyMembersTransactionsProvider(day));

  return dailyTransactionsAsync.when(
    data: (transactions) {
      return transactions.fold(
          0.0, (sum, t) => sum + (t.type == 'income' ? t.amount : -t.amount));
    },
    loading: () => 0.0,
    error: (e, st) => 0.0,
  );
});

class MembersTransactionsScreen extends ConsumerStatefulWidget {
  const MembersTransactionsScreen({super.key});

  @override
  ConsumerState<MembersTransactionsScreen> createState() =>
      _MembersTransactionsScreenState();
}

class _MembersTransactionsScreenState
    extends ConsumerState<MembersTransactionsScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const _DailySummaryPage(),
      const _MembersListPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_selectedIndex == 0 ? 'สรุปรายวัน (สมาชิก)' : 'รายชื่อสมาชิก'),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            label: 'สรุปรายวัน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: 'รายชื่อสมาชิก',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AddMultiTransactionScreen(),
                ));
              },
              tooltip: 'ทำรายการหลายบัญชี',
              child: const Icon(Icons.edit_note),
            )
          : null,
    );
  }
}

// --- Page for Daily Summary ---
class _DailySummaryPage extends ConsumerStatefulWidget {
  const _DailySummaryPage();

  @override
  ConsumerState<_DailySummaryPage> createState() => _DailySummaryPageState();
}

class _DailySummaryPageState extends ConsumerState<_DailySummaryPage> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    // Listen to provider changes to scroll down automatically.
    // We use listenManual because the provider family depends on `_selectedDate`,
    // which changes. We'll re-listen inside the build method.
    ref.listenManual<AsyncValue<List<Transaction>>>(
        dailyMembersTransactionsProvider(_selectedDate), (previous, next) {
      _scrollToBottom(next);
    });
  }

  void _scrollToBottom(AsyncValue<List<Transaction>> next) {
    if (!next.isLoading && next.hasValue) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    if (_isNextDayDisabled()) return;
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showRoundedDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
      era: EraMode.BUDDHIST_YEAR,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isNextDayDisabled() {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final selected = _selectedDate.toLocal();
    final selectedDay = DateTime(selected.year, selected.month, selected.day);

    return selectedDay.isAtSameMomentAs(today) || selectedDay.isAfter(today);
  }

  void _showReceiptImage(BuildContext context, String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบไฟล์รูปภาพ')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(file),
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final localDate = date.toLocal();
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'วันนี้';
    }
    if (dateOnly.isAtSameMomentAs(yesterday)) {
      return 'เมื่อวาน';
    }
    return DateFormatter.formatBE(date, 'd MMM yyyy');
  }

  @override
  Widget build(BuildContext context) {
    // When the date changes, we need to listen to the new provider instance.
    ref.listen<AsyncValue<List<Transaction>>>(
        dailyMembersTransactionsProvider(_selectedDate), (previous, next) {
      // This ensures that when the date is changed via the picker,
      // we scroll to the bottom of the new list.
      _scrollToBottom(next);
    });
    final dailyTransactionsAsync =
        ref.watch(dailyMembersTransactionsProvider(_selectedDate));
    final allUsersAsync = ref.watch(membersProvider);
    final allAccountsAsync = ref.watch(allAccountsProvider);

    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousDay,
                tooltip: 'วันก่อนหน้า',
              ),
              TextButton(
                onPressed: () => _pickDay(context),
                child: Text(
                  _getFormattedDate(_selectedDate),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isNextDayDisabled() ? null : _nextDay,
                tooltip: 'วันถัดไป',
              ),
            ],
          )),
      const Divider(height: 1),
      Expanded(
        child: dailyTransactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
          data: (transactions) {
            if (transactions.isEmpty) {
              return const Center(
                child: Text(
                  'ไม่มีธุรกรรมในวันนี้',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            final users = allUsersAsync.asData?.value ?? [];
            final accounts = allAccountsAsync.asData?.value ?? [];
            final userMap = {for (var u in users) u.id: u};
            final accountMap = {for (var a in accounts) a.id: a};

            final dailyBalance = ref.watch(dailySummaryProvider(_selectedDate));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'สรุปยอดวันนี้:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '฿${NumberFormat("#,##0").format(dailyBalance)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: dailyBalance >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final transaction = transactions[index];
                      final account = accountMap[transaction.accountId];
                      final owner =
                          account != null ? userMap[account.ownerUserId] : null;

                      final isIncome = transaction.type == 'income';
                      final amountColor = isIncome
                          ? Colors.green.shade700
                          : Colors.red.shade700;
                      final amountPrefix = isIncome ? '+' : '-';
                      final creator = userMap[transaction.createdByUserId];
                      final creatorName = creator?.nickname ?? 'ไม่ระบุ';

                      return ListTile(
                        onTap: owner == null
                            ? null
                            : () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => MemberTransactionsScreen(
                                      userId: owner.id!),
                                ));
                              },
                        title: RichText(
                          text: TextSpan(
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium, // Default style for the entire RichText
                            children: [
                              TextSpan(
                                  text: transaction.description ??
                                      'ไม่มีคำอธิบาย',
                                  style: const TextStyle(
                                      fontWeight: FontWeight
                                          .bold)), // Bold for description
                              if (transaction.remark?.isNotEmpty ?? false)
                                TextSpan(
                                    text: ' (${transaction.remark})',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight
                                            .normal)), // Normal for remark
                            ],
                          ),
                        ),
                        subtitle: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: [
                              TextSpan(
                                text: owner?.nickname ?? 'ไม่ระบุชื่อ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 15),
                              ),
                              TextSpan(
                                text:
                                    ' (ID:${owner?.userId1 ?? ''}) \n${DateFormatter.formatBE(transaction.transactionDate.toLocal(), "d MMM yyyy (HH:mm'น.')")} \n[บันทึกโดย]: ${creatorName}',
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        leading: owner != null
                            ? UserProfileAvatar(userId: owner.id!, radius: 26)
                            : const CircleAvatar(
                                child: Icon(Icons.person_off_outlined)),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          if (transaction.receiptImage?.isNotEmpty ?? false)
                            IconButton(
                              icon: Icon(Icons.receipt_long_outlined,
                                  color: Colors.grey.shade600),
                              onPressed: () => _showReceiptImage(
                                context,
                                transaction.receiptImage!,
                              ), // This dialog is for changing nickname, should be replaced with a proper edit screen later
                              tooltip: 'ดูใบเสร็จ',
                            ),
                          Text(
                            '$amountPrefix฿${NumberFormat("#,##0").format(transaction.amount)}',
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        ]),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

// --- Page for Members List ---
class _MembersListPage extends ConsumerWidget {
  const _MembersListPage();

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.Admin:
        return 'ไวยาวัจกรณ์';
      case UserRole.Master:
        return 'เจ้าอาวาส';
      case UserRole.Monk:
      default:
        return 'พระลูกวัด';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final loggedInUser = ref.watch(authProvider).user;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MemberManagementScreen())),
            icon: const Icon(Icons.settings_accessibility),
            label: const Text('จัดการสมาชิก (เพิ่ม/แก้ไข/ระงับ)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('เกิดข้อผิดพลาด: ')),
            data: (members) {
              if (members.isEmpty) {
                return const Center(child: Text('ยังไม่มีสมาชิกในระบบ'));
              }

              // Custom sorting: Admin -> Master -> Monk (alphabetical)
              members.sort((a, b) {
                int getRoleWeight(UserRole role) {
                  switch (role) {
                    case UserRole.Admin:
                      return 0;
                    case UserRole.Master:
                      return 1;
                    case UserRole.Monk:
                    default:
                      return 2;
                  }
                }

                final weightA = getRoleWeight(a.role);
                final weightB = getRoleWeight(b.role);

                if (weightA != weightB) {
                  return weightA.compareTo(weightB);
                }
                return a.nickname.compareTo(b.nickname);
              });

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: members.length,
                itemBuilder: (ctx, index) {
                  final user = members[index];
                  final bool isActive = user.status == 'active';
                  final bool isCurrentUser = user.id == loggedInUser?.id;

                  return Card(
                    color: isActive ? null : Colors.grey.shade300,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      onTap: () {
                        if (user.id != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MemberTransactionsScreen(userId: user.id!),
                            ),
                          );
                        }
                      },
                      leading: Icon(
                        isCurrentUser
                            ? Icons.account_circle
                            : Icons.person_outline,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade600,
                      ),
                      title: Text(
                        isCurrentUser
                            ? '${user.nickname} (คุณ)'
                            : user.nickname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_getRoleDisplayName(user.role)} : ${user.userId1}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
