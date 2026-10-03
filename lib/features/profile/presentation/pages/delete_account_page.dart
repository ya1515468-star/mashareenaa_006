import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// "حذف عضوية" — تأكيد صريح (كتابة "حذف" يدويًا) قبل استدعاء
/// [AuthController.requestAccountDeletion] الموجود مسبقًا في طبقة
/// المصادقة؛ هذه الشاشة كانت مُشارًا إليها من account_security_page
/// دون أن تُنشأ فعليًا.
class DeleteAccountPage extends ConsumerStatefulWidget {
  final String uid;
  const DeleteAccountPage({super.key, required this.uid});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .requestAccountDeletion(widget.uid);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم استلام طلب حذف الحساب')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _confirmController.text.trim() == 'حذف' && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('حذف العضوية')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          const Text(
            'هذا الإجراء نهائي ولا يمكن التراجع عنه. سيتم حذف حسابك وكل '
            'بياناتك (النقاط، الجواهر، الأصدقاء، الرسائل، والمشتريات) '
            'بشكل دائم.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 24),
          Text('اكتب كلمة "حذف" أدناه للتأكيد',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'حذف',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  disabledBackgroundColor:
                      AppColors.error.withValues(alpha: .3)),
              onPressed: canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('حذف الحساب نهائيًا'),
            ),
          ),
        ],
      ),
    );
  }
}
