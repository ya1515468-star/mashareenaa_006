import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginAnnouncementTab extends StatefulWidget {
  const AdminLoginAnnouncementTab({super.key});

  @override
  State<AdminLoginAnnouncementTab> createState() => _AdminLoginAnnouncementTabState();
}

class _AdminLoginAnnouncementTabState extends State<AdminLoginAnnouncementTab> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final owner = await Supabase.instance.client.rpc('is_my_platform_owner');
    if (owner != true) return const [];
    final rows = await Supabase.instance.client.rpc('admin_list_login_announcements');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  String _friendly(Object error) {
    final s = error.toString();
    if (s.contains('FORBIDDEN')) return 'ليست لديك صلاحية تنفيذ هذا الإجراء.';
    if (s.contains('AUTH_REQUIRED')) return 'انتهت الجلسة، يرجى تسجيل الدخول مجددًا.';
    if (s.contains('INVALID_')) return 'بيانات الإعلان غير صالحة.';
    return 'تعذر إكمال العملية الآن. تحقق من الاتصال ثم أعد المحاولة.';
  }

  Future<void> _newAnnouncement() async {
    await _edit(null);
  }

  Future<void> _edit(Map<String, dynamic>? item) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final body = TextEditingController(text: item?['body']?.toString() ?? '');
    final image = TextEditingController(text: item?['image_url']?.toString() ?? '');
    final priority = TextEditingController(text: '${item?['priority'] ?? 0}');
    final users = TextEditingController(
      text: ((item?['audience_user_ids'] as List?) ?? const []).join(','),
    );
    String status = item?['status']?.toString() ?? 'draft';
    String audience = item?['audience_type']?.toString() ?? 'all';
    String displayMode = item?['display_mode']?.toString() ?? 'every_login';
    DateTime? starts = DateTime.tryParse(item?['starts_at']?.toString() ?? '');
    DateTime? ends = DateTime.tryParse(item?['ends_at']?.toString() ?? '');

    Future<String?> uploadImage() async {
      final picked = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: const ['gif', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return null;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) throw StateError('INVALID_IMAGE');
      if (bytes.length > 8 * 1024 * 1024) throw StateError('INVALID_IMAGE');
      final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'bin';
      if (!const {'gif', 'png', 'jpg', 'jpeg', 'webp'}.contains(ext)) {
        throw StateError('INVALID_IMAGE');
      }
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) throw StateError('AUTH_REQUIRED');
      final path = 'announcements/$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage.from('chat-welcome-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );
      return Supabase.instance.client.storage.from('chat-welcome-images').getPublicUrl(path);
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(item == null ? 'إعلان تسجيل الدخول' : 'تعديل الإعلان'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: body,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(labelText: 'نص الإعلان'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: const InputDecoration(labelText: 'الحالة'),
                            items: const [
                              DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                              DropdownMenuItem(value: 'active', child: Text('فعال')),
                              DropdownMenuItem(value: 'paused', child: Text('متوقف')),
                              DropdownMenuItem(value: 'expired', child: Text('منتهي')),
                            ],
                            onChanged: (v) => setLocal(() => status = v ?? status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: displayMode,
                            decoration: const InputDecoration(labelText: 'طريقة الظهور'),
                            items: const [
                              DropdownMenuItem(value: 'once_per_user', child: Text('مرة واحدة لكل مستخدم')),
                              DropdownMenuItem(value: 'every_login', child: Text('كل تسجيل دخول')),
                              DropdownMenuItem(value: 'manual', child: Text('إغلاق يدوي')),
                            ],
                            onChanged: (v) => setLocal(() => displayMode = v ?? displayMode),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: audience,
                      decoration: const InputDecoration(labelText: 'الجمهور'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('جميع المستخدمين')),
                        DropdownMenuItem(value: 'custom', child: Text('مستخدمون محددون')),
                      ],
                      onChanged: (v) => setLocal(() => audience = v ?? audience),
                    ),
                    if (audience == 'custom') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: users,
                        decoration: const InputDecoration(labelText: 'معرفات المستخدمين مفصولة بفواصل'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: image,
                      decoration: InputDecoration(
                        labelText: 'رابط الصورة الاختياري',
                        suffixIcon: IconButton(
                          tooltip: 'رفع صورة',
                          icon: const Icon(Icons.upload_file),
                          onPressed: () async {
                            try {
                              final url = await uploadImage();
                              if (url != null) setLocal(() => image.text = url);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priority,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الأولوية'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                                initialDate: starts ?? DateTime.now(),
                              );
                              if (picked != null) setLocal(() => starts = picked);
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(starts == null ? 'بداية اختيارية' : '${starts!.year}-${starts!.month}-${starts!.day}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                                initialDate: ends ?? DateTime.now(),
                              );
                              if (picked != null) setLocal(() => ends = picked);
                            },
                            icon: const Icon(Icons.event_busy),
                            label: Text(ends == null ? 'نهاية اختيارية' : '${ends!.year}-${ends!.month}-${ends!.day}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    final titleValue = title.text.trim();
                    final bodyValue = body.text.trim();
                    if (titleValue.isEmpty || bodyValue.isEmpty) throw StateError('INVALID_BODY');
                    final audienceIds = users.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(growable: false);
                    await Supabase.instance.client.rpc(
                      'admin_upsert_login_announcement',
                      params: {
                        'p_id': item?['id'],
                        'p_title': titleValue,
                        'p_body': bodyValue,
                        'p_image_url': image.text.trim().isEmpty ? null : image.text.trim(),
                        'p_status': status,
                        'p_starts_at': starts?.toIso8601String(),
                        'p_ends_at': ends?.toIso8601String(),
                        'p_audience_type': audience,
                        'p_audience_user_ids': audience == 'custom' ? audienceIds : const <String>[],
                        'p_display_mode': displayMode,
                        'p_priority': int.tryParse(priority.text.trim()) ?? 0,
                      },
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) setState(() => _future = _load());
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      body.dispose();
      image.dispose();
      priority.dispose();
      users.dispose();
    }
  }

  Future<void> _archive(String id) async {
    try {
      await Supabase.instance.client.rpc('admin_archive_login_announcement', params: {'p_id': id});
      if (mounted) setState(() => _future = _load());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل إعلانات تسجيل الدخول الآن. تحقق من الاتصال ثم أعد المحاولة.'));
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('إعلانات تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  FilledButton.icon(onPressed: _newAnnouncement, icon: const Icon(Icons.add), label: const Text('إعلان جديد')),
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لا توجد إعلانات محفوظة.')),
                )
              else
                ...rows.map(
                  (row) => Card(
                    child: ListTile(
                      title: Text(row['title']?.toString() ?? 'إعلان'),
                      subtitle: Text('${row['status']} • ${row['display_mode']} • الأولوية ${row['priority']}'),
                      leading: row['image_url']?.toString().isNotEmpty == true
                          ? const Icon(Icons.image_outlined)
                          : const Icon(Icons.campaign_outlined),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                            tooltip: 'أرشفة',
                            onPressed: () => _archive(row['id'].toString()),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
