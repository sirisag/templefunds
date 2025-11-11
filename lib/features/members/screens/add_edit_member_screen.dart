import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/models/user_model.dart';
import 'package:templefunds/features/transactions/providers/accounts_provider.dart';
import 'package:templefunds/core/services/crypto_service.dart';
import 'package:templefunds/features/members/providers/members_provider.dart';

class AddEditMemberScreen extends ConsumerStatefulWidget {
  const AddEditMemberScreen({super.key});

  @override
  ConsumerState<AddEditMemberScreen> createState() =>
      _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends ConsumerState<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _id1Controller = TextEditingController();
  UserRole _selectedRole = UserRole.Monk; // Default role
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _id1Controller.dispose();
    super.dispose();
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.Admin:
        return 'ไวยาวัจกรณ์';
      case UserRole.Master:
        return 'เจ้าอาวาส';
      case UserRole.Monk:
        return 'พระลูกวัด';
    }
  }

  Future<void> _submitForm() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final notifier = ref.read(membersProvider.notifier);
    final name = _nameController.text.trim();
    final id1 = _id1Controller.text.trim();

    // Check for duplicate ID1
    final isId1Taken = await notifier.isUserId1Taken(id1);
    if (isId1Taken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('รหัสประจำตัว "$id1" นี้ถูกใช้งานแล้ว'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Check for duplicate name and show warning
    final isNameTaken = await notifier.isNameTaken(name);
    if (isNameTaken) {
      final continueAnyway = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('คำเตือน: ชื่อซ้ำ'),
              content: Text(
                  'มีสมาชิกชื่อ "$name" อยู่ในระบบแล้ว คุณต้องการดำเนินการต่อหรือไม่?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('ยกเลิก')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('ดำเนินการต่อ')),
              ],
            ),
          ) ??
          false;

      if (!continueAnyway) {
        setState(() => _isLoading = false);
        return;
      }
    }

    // Final confirmation
    final id2 = (1000 + Random().nextInt(9000)).toString();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('ยืนยันการสร้างสมาชิก'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'กรุณาตรวจสอบข้อมูลให้ถูกต้อง การกระทำนี้ไม่สามารถแก้ไขหรือลบได้ในภายหลัง'),
                const Divider(),
                Text('ชื่อ: $name'),
                Text('ID ชุดที่ 1: $id1'),
                Text('ID ชุดที่ 2 (ระบบสร้าง): $id2'),
                Text('บทบาท: ${_getRoleDisplayName(_selectedRole)}'),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('ยกเลิก')),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('ยืนยันและบันทึก')),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      final newUser = User(
        userId1: id1,
        // Hash the ID2 before creating the user object
        userId2: ref.read(cryptoServiceProvider).hashString(id2),
        name: name,
        role: _selectedRole,
        createdAt: DateTime.now(),
      );
      await notifier.addUser(newUser);
      // Invalidate the accounts provider so the list is refreshed on the transaction screen
      ref.invalidate(allAccountsProvider);
      if (context.mounted) Navigator.of(context).pop();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มสมาชิกใหม่')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'ชื่อ-สกุล หรือ ฉายา'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'กรุณากรอกชื่อ' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _id1Controller,
                decoration: const InputDecoration(labelText: 'ID ประจำตัว (4 หลัก)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) =>
                    (v == null || v.length != 4) ? 'ต้องเป็นเลข 4 หลัก' : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'บทบาท'),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem<UserRole>(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedRole = value);
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.save),
                      label: const Text('บันทึก'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}