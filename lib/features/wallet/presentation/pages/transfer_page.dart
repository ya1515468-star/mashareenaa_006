import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_button.dart';
import '../../../auth/presentation/widgets/auth_text_field.dart';
import '../../domain/entities/currency.dart';
import '../providers/wallet_provider.dart';

class TransferPage extends ConsumerStatefulWidget {
  const TransferPage({super.key});

  @override
  ConsumerState<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends ConsumerState<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  Currency _currency = Currency.shamCash;

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final amountValue = double.tryParse(_amountController.text.trim()) ?? 0;
    final money =
        Money(minorUnits: (amountValue * 100).round(), currency: _currency);

    // يمر عبر TransferUseCase ثم معاملة طبقة بيانات Supabase ذرية واحدة تضمن
    // عدم فقدان أو ازدواج أي مبلغ مهما حدث من فشل جزئي.
    final success = await ref.read(walletControllerProvider.notifier).transfer(
          fromUid: user.uid,
          toUid: _recipientController.text.trim(),
          amount: money,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      ref.invalidate(walletHistoryProvider);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تنفيذ التحويل الآن. تحقق من الرصيد والاتصال ثم أعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(walletControllerProvider);
    final isLoading = controllerState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('تحويل رصيد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<Currency>(
                  segments: const [
                    ButtonSegment(
                        value: Currency.shamCash, label: Text('شام كاش')),
                    ButtonSegment(value: Currency.usd, label: Text('دولار')),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (s) =>
                      setState(() => _currency = s.first),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  controller: _recipientController,
                  label: 'معرّف المستلم (UID)',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال معرّف المستلم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _amountController,
                  label: 'المبلغ',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.payments_outlined,
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) {
                      return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _noteController,
                  label: 'ملاحظة (اختياري)',
                  prefixIcon: Icons.note_outlined,
                ),
                const SizedBox(height: 24),
                AuthButton(
                    label: 'تأكيد التحويل',
                    isLoading: isLoading,
                    onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
