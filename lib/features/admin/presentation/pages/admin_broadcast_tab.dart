import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../broadcasts/domain/usecases/send_broadcast_usecase.dart';

class AdminBroadcastTab extends ConsumerStatefulWidget {
  const AdminBroadcastTab({super.key});

  @override
  ConsumerState<AdminBroadcastTab> createState() => _AdminBroadcastTabState();
}

class _AdminBroadcastTabState extends ConsumerState<AdminBroadcastTab> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _resultMessage;

  Future<void> _send() async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    final message = _controller.text.trim();
    if (uid == null || message.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _resultMessage = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await sl<SendBroadcastUseCase>().call(
        message: message,
        sentByUid: uid,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resultMessage = result.fold(
          (failure) => failure.message,
          (_) => 'تم بث الرسالة لكل المستخدمين ✓',
        );
      });
      if (result.isRight()) _controller.clear();
      messenger.hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _resultMessage = 'تعذر تنفيذ البث: $e';
      });
      messenger.showSnackBarSfx(SnackBar(content: Text('تعذر تنفيذ البث: $e')));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بث رسالة ديناميكية لكل المستخدمين (DRAGON فقط)',
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration:
                const InputDecoration(hintText: 'اكتب رسالة البث هنا...'),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 10),
            Text(_resultMessage!, style: TextStyle(color: p.accent)),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.campaign_outlined),
            label: Text(_sending ? 'جارٍ البث...' : 'بث الآن'),
          ),
        ],
      ),
    );
  }
}
