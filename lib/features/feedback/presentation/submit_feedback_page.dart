import '../../../core/data/supabase_document_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/providers/auth_provider.dart';

/// ميزة 12 من القائمة الإضافية: صندوق اقتراحات وأفكار موجَّه مباشرة
/// لإدارة المنصة (DRAGON) — يمنح الأعضاء شعورًا بأن رأيهم مسموع،
/// وهي وسيلة تغذية راجعة حقيقية لتطوير المنصة بمشاركتهم.
class FeedbackService {
  static Future<void> submit(
      {required String uid, required String message}) async {
    await SupabaseDocumentStore.instance.collection('member_feedback').add({
      'uid': uid,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'new',
    });
  }
}

class SubmitFeedbackPage extends ConsumerStatefulWidget {
  const SubmitFeedbackPage({super.key});

  @override
  ConsumerState<SubmitFeedbackPage> createState() => _SubmitFeedbackPageState();
}

class _SubmitFeedbackPageState extends ConsumerState<SubmitFeedbackPage> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  Future<void> _submit() async {
    final uid = ref.read(authControllerProvider).valueOrNull?.uid;
    final message = _controller.text.trim();
    if (uid == null || message.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await FeedbackService.submit(uid: uid, message: message);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
        _controller.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الاقتراح: $e')),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('اقترح فكرة على DRAGON 💡')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'شاركنا أي فكرة أو ميزة تودّ رؤيتها في المنصة — تصل مباشرة لإدارة مشاريعنا.',
              style: TextStyle(color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 5,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(hintText: 'اكتب فكرتك هنا...'),
            ),
            if (_sent) ...[
              const SizedBox(height: 10),
              Text('شكرًا لك! وصلت فكرتك ✓',
                  style: TextStyle(color: p.success)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
