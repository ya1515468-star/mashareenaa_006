import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/widgets/gender_birth_fields.dart';
import '../providers/profile_provider.dart';

/// ما ينقص الملف الشخصي الحالي.
final profileCompletionProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return const {};
  try {
    final raw = await client.rpc('get_my_profile_completion');
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  } catch (_) {
    return const {};
  }
});

/// «أكمل بياناتك»: الجنس وتاريخ الميلاد لمن لم يُسأل عنهما.
///
/// سبب وجودها: الدخول بجوجل يتخطّى نموذج التسجيل كلّه، فلا يُسأل صاحبه
/// عن جنس ولا ميلاد. ومثله كل من سجّل قبل إضافة الحقلين. فصار اكتمال
/// البيانات ثلاثة مسارات لا اثنين، وهذه تسدّ الثالث وتُصلح القديم معًا.
///
/// قابلة للتخطّي عمدًا: لا نحجز المستخدم على شاشة لم يطلبها. وتبقى
/// متاحة دائمًا من الملف الشخصي.
class CompleteProfileSheet extends ConsumerStatefulWidget {
  const CompleteProfileSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CompleteProfileSheet(),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<CompleteProfileSheet> createState() =>
      _CompleteProfileSheetState();
}

class _CompleteProfileSheetState extends ConsumerState<CompleteProfileSheet> {
  String? _gender;
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy) return;
    if (_gender == null && _birthDate == null) {
      setState(() => _error = 'اختر الجنس أو تاريخ الميلاد على الأقل.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc('set_my_gender_birth', params: {
        'p_gender': _gender,
        'p_birth_date': _birthDate == null
            ? null
            : '${_birthDate!.year.toString().padLeft(4, '0')}-'
                '${_birthDate!.month.toString().padLeft(2, '0')}-'
                '${_birthDate!.day.toString().padLeft(2, '0')}',
      });
      ref.invalidate(profileCompletionProvider);
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = FailureText.of(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: p.divider,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Text('أكمل بياناتك',
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('معلومتان فقط، تُحسّنان ما يُعرَض لك ومن يجدك.',
                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              GenderBirthFields(
                gender: _gender,
                birthDate: _birthDate,
                onGender: (v) => setState(() => _gender = v),
                onBirthDate: (d) => setState(() => _birthDate = d),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('حفظ'),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                child: const Text('لاحقًا'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة دائمة في الملف الشخصي لمن تخطّى، أو لمن سجّل قبل إضافة الحقلين.
class CompleteProfileTile extends ConsumerWidget {
  const CompleteProfileTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(profileCompletionProvider).valueOrNull;
    if (completion == null || completion['needs_basics'] != true) {
      return const SizedBox.shrink();
    }
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.divider),
      ),
      child: Row(children: [
        Icon(Icons.person_search_outlined, color: p.accent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text('بياناتك ناقصة: الجنس وتاريخ الميلاد',
              style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
        ),
        TextButton(
          onPressed: () => CompleteProfileSheet.show(context),
          child: const Text('أكمل'),
        ),
      ]),
    );
  }
}
