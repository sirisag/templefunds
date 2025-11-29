import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:templefunds/core/models/recovery_code_model.dart';
import 'package:templefunds/core/utils/date_formatter.dart';
import 'package:templefunds/features/recovery/providers/recovery_codes_provider.dart';

class RecoveryCodesScreen extends ConsumerStatefulWidget {
  const RecoveryCodesScreen({super.key});

  @override
  ConsumerState<RecoveryCodesScreen> createState() =>
      _RecoveryCodesScreenState();
}

class _RecoveryCodesScreenState extends ConsumerState<RecoveryCodesScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh the codes every time the screen is opened to ensure data is fresh.
    Future.microtask(
        () => ref.read(recoveryCodesProvider.notifier).regenerateCodes());
  }

  @override
  Widget build(BuildContext context) {
    final recoveryCodesAsync = ref.watch(recoveryCodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('รหัสผ่านฉุกเฉิน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'สร้างรหัสชุดใหม่ทั้งหมด',
            onPressed: () => _showRegenerateConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: recoveryCodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('เกิดข้อผิดพลาด: $err')),
        data: (codes) {
          final availableCodes = codes.where((c) => !c.isUsed).toList();
          // Sort used codes by used_at date, newest first.
          final usedCodes = codes.where((c) => c.isUsed).toList();
          usedCodes.sort((a, b) =>
              (b.usedAt ?? DateTime(0)).compareTo(a.usedAt ?? DateTime(0)));

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildWarningCard(context),
              const SizedBox(height: 24),
              _buildCodeSection(
                context: context,
                title: 'รหัสที่ใช้ได้ (${availableCodes.length})',
                codes: availableCodes,
                isAvailable: true,
              ),
              const SizedBox(height: 24),
              if (usedCodes.isNotEmpty)
                _buildCodeSection(
                  context: context,
                  title: 'รหัสที่ใช้แล้ว',
                  codes: usedCodes,
                  isAvailable: false,
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRegenerateConfirmationDialog(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('สร้างรหัสชุดใหม่ทั้งหมด?'),
        content: const Text(
            'การกระทำนี้จะทำให้รหัสที่ยังไม่ได้ใช้งานชุดปัจจุบันทั้งหมดถูกยกเลิก และจะสร้างรหัสชุดใหม่ขึ้นมาแทนที่ คุณแน่ใจหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'ยืนยัน',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recoveryCodesProvider.notifier).regenerateAllNewCodes();
    }
  }

  Widget _buildWarningCard(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.amber.shade600, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'สำคัญมาก: กรุณาจดหรือพิมพ์รหัสเหล่านี้เก็บไว้ในที่ปลอดภัยนอกแอปพลิเคชัน รหัสนี้เป็นหนทางเดียวในการกู้คืนบัญชีหากคุณลืมรหัส PIN',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeSection({
    required BuildContext context,
    required String title,
    required List<RecoveryCode> codes,
    required bool isAvailable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Divider(),
        if (codes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('ไม่มีข้อมูล')),
          )
        else
          ...codes.map((code) => _buildCodeTile(context, code, isAvailable)),
      ],
    );
  }

  Widget _buildCodeTile(
      BuildContext context, RecoveryCode code, bool isAvailable) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          isAvailable ? Icons.vpn_key_outlined : Icons.check_circle_outline,
          color: isAvailable ? Colors.blue.shade700 : Colors.grey,
        ),
        title: Text(
          code.code,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 2,
            decoration: isAvailable ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: !isAvailable && code.usedAt != null
            ? Text(
                'ใช้เมื่อ: ${DateFormatter.formatBE(code.usedAt!, "d MMM yyyy, HH:mm")}')
            : null,
        trailing:
            isAvailable ? _buildAvailableCodeActions(context, ref, code) : null,
      ),
    );
  }

  Widget _buildAvailableCodeActions(
      BuildContext context, WidgetRef ref, RecoveryCode code) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            code.isTagged ? Icons.star : Icons.star_border_outlined,
            color: code.isTagged ? Colors.orangeAccent : Colors.grey,
          ),
          tooltip: 'ทำเครื่องหมาย',
          onPressed: () =>
              ref.read(recoveryCodesProvider.notifier).toggleCodeTag(code),
        ),
        IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          tooltip: 'คัดลอกรหัส',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code.code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('คัดลอกรหัสแล้ว')),
            );
          },
        ),
      ],
    );
  }
}
