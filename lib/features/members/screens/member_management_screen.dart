import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/auth/providers/auth_provider.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';
import 'package:templefunds/features/members/screens/change_pin_screen.dart';
import 'package:templefunds/features/transactions/screens/member_transactions_screen.dart';
import 'package:templefunds/features/members/screens/add_edit_member_screen.dart';

class MemberManagementScreen extends ConsumerWidget {
  const MemberManagementScreen({super.key});

  void _showChangeNameDialog(BuildContext context, WidgetRef ref, User user) async {
    final nameController = TextEditingController(text: user.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('เปลี่ยนชื่อของ ${user.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อใหม่',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อ';
                }
                if (value.trim() == user.name) {
                  return 'ชื่อใหม่ต้องไม่ซ้ำกับชื่อเดิม';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(nameController.text.trim());
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName != user.name && context.mounted) {
      await ref.read(membersProvider.notifier).updateUserName(user.id!, newName);
    }
  }

  void _showResetId2Dialog(
      BuildContext context, WidgetRef ref, User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการรีเซ็ตรหัส'),
        content: Text(
            'คุณต้องการรีเซ็ต ID ชุดที่ 2 ของ ${user.name} ใช่หรือไม่? การกระทำนี้จะทำให้ผู้ใช้ต้องใช้รหัสใหม่ในการเข้าสู่ระบบครั้งถัดไป'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ยืนยัน')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final newId2 =
          await ref.read(membersProvider.notifier).resetId2(user.id!);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('รีเซ็ตสำเร็จ'),
            content: Text(
                'ID ชุดที่ 2 ใหม่ของ ${user.name} คือ: $newId2\nกรุณาแจ้งรหัสใหม่นี้ให้เจ้าของบัญชีทราบ'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ตกลง')),
            ],
          ),
        );
      }
    }
  }

  void _showChangeRoleDialog(
      BuildContext context, WidgetRef ref, User user) async {
    String selectedRole = user.role;

    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('เปลี่ยนบทบาทของ ${user.name}'),
              content: DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'บทบาทใหม่',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Monk', child: Text('พระลูกวัด')),
                  DropdownMenuItem(value: 'Master', child: Text('เจ้าอาวาส')),
                  DropdownMenuItem(value: 'Admin', child: Text('ผู้ดูแลระบบ')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: selectedRole == user.role
                      ? null
                      : () => Navigator.of(ctx).pop(selectedRole),
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newRole != null && newRole != user.role && context.mounted) {
      await ref
          .read(membersProvider.notifier)
          .updateUserRole(user.id!, newRole);
    }
  }

  void _toggleStatus(BuildContext context, WidgetRef ref, User user) async {
    final bool isActive = user.status == 'active';
    final String actionText = isActive ? 'ระงับการใช้งาน' : 'เปิดใช้งาน';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการ$actionText'),
        content: Text('คุณต้องการ$actionTextบัญชีของ ${user.name} ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ยืนยัน')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(membersProvider.notifier)
          .updateUserStatus(user.id!, user.status);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final loggedInUser = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการสมาชิก'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('ยังไม่มีสมาชิกในระบบ'));
          }

          // Custom sorting: Admin -> Master -> Monk (alphabetical)
          members.sort((a, b) {
            int getRoleWeight(String role) {
              switch (role) {
                case 'Admin':
                  return 0;
                case 'Master':
                  return 1;
                case 'Monk':
                default:
                  return 2;
              }
            }

            final weightA = getRoleWeight(a.role);
            final weightB = getRoleWeight(b.role);

            if (weightA != weightB) {
              return weightA.compareTo(weightB);
            }
            // If roles are the same, sort by name
            return a.name.compareTo(b.name);
          });

          return ListView.builder(
            padding:
                const EdgeInsets.only(top: 8, bottom: 80), // Add padding for FAB
            itemCount: members.length,
            itemBuilder: (ctx, index) {
              final user = members[index];
              final bool isActive = user.status == 'active';
              final bool isCurrentUser = user.id == loggedInUser?.id;

              IconData getRoleIcon(String role) {
                switch (role) {
                  case 'Admin':
                    return Icons.shield_outlined;
                  case 'Master':
                    return Icons.school_outlined;
                  default:
                    return Icons.person_outline;
                }
              }

              return Card(
                color: isActive ? null : Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  onTap: () {
                    // Navigate to the member's transaction screen when tapped.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MemberTransactionsScreen(userId: user.id!),
                      ),
                    );
                  },
                  leading: Icon(
                    isCurrentUser ? Icons.account_circle : getRoleIcon(user.role),
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
                  ),
                  title: Text(
                    isCurrentUser
                        ? '${user.name} (คุณ)'
                        : '${user.name} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${user.role} : ${user.userId1}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'reset_id2') {
                        _showResetId2Dialog(context, ref, user);
                      } else if (value == 'change_name') {
                        _showChangeNameDialog(context, ref, user);
                      } else if (value == 'change_role') {
                        _showChangeRoleDialog(context, ref, user);
                      } else if (value == 'toggle_status') {
                        _toggleStatus(context, ref, user);
                      } else if (value == 'change_pin') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ChangePinScreen()),
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        enabled: false,
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text('ID2: ${user.userId2}'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'reset_id2',
                        child: ListTile(
                          leading: Icon(Icons.vpn_key_outlined),
                          title: Text('รีเซ็ต ID ชุดที่ 2'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'change_name',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('เปลี่ยนชื่อ'),
                        ),
                      ),
                      if (isCurrentUser)
                        const PopupMenuItem<String>(
                          value: 'change_pin',
                          child: ListTile(
                            leading: Icon(Icons.pin_outlined),
                            title: Text('เปลี่ยนรหัส PIN'),
                          ),
                        )
                      else
                        ...[
                          const PopupMenuItem<String>(
                            value: 'change_role',
                            child: ListTile(
                              leading:
                                  Icon(Icons.admin_panel_settings_outlined),
                              title: Text('เปลี่ยนบทบาท'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'toggle_status',
                            child: ListTile(
                              leading: Icon(isActive
                                  ? Icons.toggle_off_outlined
                                  : Icons.toggle_on_outlined),
                              title: Text(isActive ? 'ระงับการใช้งาน' : 'เปิดใช้งาน'),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditMemberScreen()),
          );
        },
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}