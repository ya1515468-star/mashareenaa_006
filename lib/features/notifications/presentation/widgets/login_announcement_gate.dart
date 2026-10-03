import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginAnnouncementGate extends StatefulWidget {
  final Widget child;
  const LoginAnnouncementGate({super.key, required this.child});

  @override
  State<LoginAnnouncementGate> createState() => _LoginAnnouncementGateState();
}

class _LoginAnnouncementGateState extends State<LoginAnnouncementGate> {
  bool _checking = false;
  String? _shownId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted || _checking) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _checking = true);
    try {
      final raw = await Supabase.instance.client
          .rpc('get_active_login_announcement')
          .timeout(const Duration(seconds: 8));
      if (!mounted || raw == null) return;
      final data = Map<String, dynamic>.from(raw as Map);
      final id = data['id']?.toString();
      if (id == null || id.isEmpty || id == _shownId) return;
      _shownId = id;
      await _show(data);
    } catch (_) {
      // Announcement retrieval must never block or crash the signed-in app.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _show(Map<String, dynamic> data) async {
    final id = data['id']?.toString();
    if (id == null || id.isEmpty || !mounted) return;
    final imageUrl = data['image_url']?.toString().trim();
    final title = data['title']?.toString().trim() ?? '';
    final body = data['body']?.toString().trim() ?? '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title.isEmpty ? 'إعلان المنصة' : title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  body,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.rpc(
                  'record_login_announcement_view',
                  params: {'p_announcement_id': id},
                );
              } catch (_) {
                // The server remains authoritative for display eligibility.
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
