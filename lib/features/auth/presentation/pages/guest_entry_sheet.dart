import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/snack_sfx.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/guest_auth_service.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../widgets/gender_birth_fields.dart';

/// «الدخول كزائر»: الاسم والجنس وتاريخ الميلاد، ثم دخول فوري بلا بريد.
///
/// تاريخ الميلاد لا العمر: العمر رقم يصدأ، ومن يسجّل بعمر 20 يبقى 20
/// إلى الأبد. العمر يُحسب خادميًا من التاريخ عبر `public.profile_age()`.
class GuestEntrySheet extends ConsumerStatefulWidget {
  const GuestEntrySheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GuestEntrySheet(),
    );
    return done ?? false;
  }

  @override
  ConsumerState<GuestEntrySheet> createState() => _GuestEntrySheetState();
}

class _GuestEntrySheetState extends ConsumerState<GuestEntrySheet> {
  final _nameController = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await GuestAuthService().signInAsGuest(
        displayName: _nameController.text,
        gender: _gender,
        birthDate: _birthDate,
      );
      // القيود تُقرأ من الخادم فور الدخول.
      ref.invalidate(guestStateProvider);
      ref.invalidate(authControllerProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on GuestAuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر الدخول كزائر، حاول مرة أخرى.');
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
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text('الدخول كزائر',
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('جرّب التطبيق بلا بريد. تستطيع التسجيل لاحقًا ويبقى كل شيء جمعته.',
                  style: TextStyle(color: p.textSecondary, fontSize: 13)),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                maxLength: 30,
                style: TextStyle(color: p.textPrimary),
                decoration: InputDecoration(
                  labelText: 'الاسم الظاهر',
                  counterText: '',
                  prefixIcon: Icon(Icons.badge_outlined, color: p.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              GenderBirthFields(
                gender: _gender,
                birthDate: _birthDate,
                onGender: (v) => setState(() => _gender = v),
                onBirthDate: (d) => setState(() => _birthDate = d),
              ),
              const SizedBox(height: 16),
              // تحذير لا بدّ أن يراه قبل الضغط لا بعد أن يخسر ما جمعه:
              // جلسة الزائر محفوظة في هذا الجهاز وحده، ولا بريد ولا هاتف
              // يسترجع بها الحساب.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: .4)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'حساب الزائر محفوظ في هذا الجهاز فقط. إن حذفت التطبيق '
                      'أو مسحت بياناته فلن تستطيع استرجاعه — لا بريد ولا رقم. '
                      'سجّل ببريدك متى شئت ليصير حسابك دائمًا.',
                      style: TextStyle(
                          color: p.textSecondary, fontSize: 12, height: 1.5),
                    ),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _enter,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يُستعمل من صفحة التسجيل وصفحة الدخول: يفتح الورقة ثم يُعلم المستدعي.
Future<void> openGuestEntry(BuildContext context) async {
  final entered = await GuestEntrySheet.show(context);
  if (entered && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBarSfx(
      const SnackBar(content: Text('أهلًا بك! أنت الآن زائر.')),
    );
  }
}
