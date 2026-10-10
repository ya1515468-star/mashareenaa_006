import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../search/presentation/providers/search_provider.dart';
import '../../../profile/presentation/pages/user_profile_view_page.dart';

class AdminUserTitlesTab extends ConsumerStatefulWidget {
  const AdminUserTitlesTab({super.key});

  @override
  ConsumerState<AdminUserTitlesTab> createState() => _AdminUserTitlesTabState();
}

class _AdminUserTitlesTabState extends ConsumerState<AdminUserTitlesTab> {
  Future<List<Map<String, dynamic>>>? _future;
  final _search = TextEditingController();
  String _query = '';
  bool _busy = false;
  String _identifierKind = 'UID';
  final _identifierController = TextEditingController();
  Map<String, dynamic>? _targetIdentity;
  String? _selectedExactTitleKey;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  void _reload() {
    _future = _load();
    if (mounted) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await _client.rpc('list_user_titles_for_admin');
    return List<Map<String, dynamic>>.from(
      (raw as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }


  Future<void> _lookupExactIdentity() async {
    final value = _identifierController.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final raw = await _client.rpc('admin_lookup_user_identity', params: {
        'p_identifier': value,
        'p_identifier_type': _identifierKind.toLowerCase(),
      });
      if (!mounted) return;
      setState(() {
        _targetIdentity = raw is Map ? Map<String, dynamic>.from(raw) : null;
        _selectedExactTitleKey = _targetIdentity?['title_key']?.toString();
      });
      if (_targetIdentity == null) _error('لم يتم العثور على المستخدم.');
    } catch (e) {
      if (mounted) _error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignSelectedTitleToExactUser() async {
    final target = _targetIdentity;
    if (target == null) return;
    final titles = await _future;
    if (titles == null || !mounted) return;
    final selected = titles.cast<Map<String, dynamic>>().firstWhere(
      (e) => e['is_active'] == true && e['title_key']?.toString() == _selectedExactTitleKey,
      orElse: () => <String, dynamic>{},
    );
    if (selected.isEmpty) {
      _error('اختر لقبًا نشطًا أولًا.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _client.rpc('set_user_title', params: {
        'p_user_id': target['user_id'],
        'p_title_key': selected['title_key'],
        'p_request_id': const Uuid().v4(),
      });
      if (mounted) {
        _message('تم تعيين اللقب للمستخدم المحدد خادميًا.');
        await _lookupExactIdentity();
      }
    } catch (e) {
      if (mounted) _error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTitle() async {
    final form = await _showForm();
    if (form == null) return;
    setState(() => _busy = true);
    try {
      await _client.rpc('create_user_title', params: {
        'p_title_key': form.key,
        'p_name_ar': form.name,
        'p_icon_url': form.iconUrl,
        'p_sort_order': form.sortOrder,
        'p_request_id': const Uuid().v4(),
      });
      if (mounted) _message('تم إنشاء اللقب.');
      _reload();
    } catch (e) {
      if (mounted) _error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTitle(Map<String, dynamic> row) async {
    final form = await _showForm(initial: row);
    if (form == null) return;
    setState(() => _busy = true);
    try {
      await _client.rpc('update_user_title_catalog', params: {
        'p_title_id': row['id'],
        'p_title_key': form.key,
        'p_name_ar': form.name,
        'p_icon_url': form.iconUrl,
        'p_sort_order': form.sortOrder,
        'p_request_id': const Uuid().v4(),
      });
      if (mounted) _message('تم تحديث اللقب.');
      _reload();
    } catch (e) {
      if (mounted) _error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    setState(() => _busy = true);
    try {
      await _client.rpc('set_user_title_catalog_active', params: {
        'p_title_id': row['id'],
        'p_is_active': row['is_active'] != true,
        'p_request_id': const Uuid().v4(),
      });
      if (mounted) _message(row['is_active'] == true ? 'تم إيقاف اللقب.' : 'تم تفعيل اللقب.');
      _reload();
    } catch (e) {
      if (mounted) _error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignDialog() async {
    _search.clear();
    _query = '';
    final titles = await _future;
    if (!mounted || titles == null || titles.isEmpty) return;
    Map<String, dynamic>? selected = titles.firstWhere(
      (e) => e['is_active'] == true,
      orElse: () => <String, dynamic>{},
    );
    if (selected.isEmpty) selected = null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, localSetState) {
          final users = ref.watch(profileSearchResultsProvider(_query));
          return AlertDialog(
            title: const Text('تعيين لقب لمستخدم'),
            content: SizedBox(
              width: 560,
              height: 470,
              child: Column(
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selected,
                    items: titles.where((e) => e['is_active'] == true).map((e) {
                      return DropdownMenuItem(value: e, child: Text(e['name_ar']?.toString() ?? ''));
                    }).toList(),
                    onChanged: (v) => localSetState(() => selected = v),
                    decoration: const InputDecoration(labelText: 'اللقب'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'ابحث باسم المستخدم'),
                    onChanged: (v) {
                      setState(() => _query = v.trim());
                      localSetState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _query.isEmpty
                        ? const Center(child: Text('اكتب اسمًا للبحث'))
                        : users.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const Center(child: Text('تعذر تحميل المستخدمين الآن.')),
                            data: (profiles) => ListView.builder(
                              itemCount: profiles.length,
                              itemBuilder: (_, index) {
                                final profile = profiles[index];
                                return ListTile(
                                  title: Text(profile.displayName),
                                  subtitle: Text(profile.email),
                                  // trailing بلا حدّ عرض: نحصره حتى لا
                                  // يطلب الزر عرضًا لانهائيًا.
                                  trailing: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 110),
                                    child: FilledButton(
                                    onPressed: _busy || selected == null ? null : () async {
                                      try {
                                        await _client.rpc('set_user_title', params: {
                                          'p_user_id': profile.uid,
                                          'p_title_key': selected!['title_key'],
                                          'p_request_id': const Uuid().v4(),
                                        });
                                        if (context.mounted) Navigator.pop(context);
                                      } catch (e) {
                                        if (context.mounted) _error(_friendlyError(e));
                                      }
                                    },
                                      child: const Text('تعيين'),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
            ],
          );
        },
      ),
    );
  }

  Future<_TitleForm?> _showForm({Map<String, dynamic>? initial}) async {
    final key = TextEditingController(text: initial?['title_key']?.toString() ?? '');
    final name = TextEditingController(text: initial?['name_ar']?.toString() ?? '');
    final icon = TextEditingController(text: initial?['icon_url']?.toString() ?? '');
    final sort = TextEditingController(text: '${initial?['sort_order'] ?? 0}');
    return showDialog<_TitleForm>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? 'إنشاء لقب مستخدم' : 'تحديث لقب مستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: key, readOnly: initial != null, decoration: const InputDecoration(labelText: 'المفتاح التقني')),
            TextField(controller: name, textAlign: TextAlign.right, maxLength: 80, decoration: const InputDecoration(labelText: 'اسم اللقب')),
            TextField(controller: icon, decoration: const InputDecoration(labelText: 'رابط الأيقونة (اختياري)')),
            TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (key.text.trim().length < 3 || name.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, _TitleForm(
                key: key.text.trim().toLowerCase(),
                name: name.text.trim(),
                iconUrl: icon.text.trim().isEmpty ? null : icon.text.trim(),
                sortOrder: int.tryParse(sort.text.trim()) ?? 0,
              ));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('FORBIDDEN')) return 'لا تملك صلاحية إدارة الألقاب.';
    if (text.contains('AUTH_REQUIRED')) return 'انتهت الجلسة. سجّل الدخول مجددًا.';
    if (text.contains('TITLE_KEY_EXISTS')) return 'المفتاح مستخدم بالفعل.';
    if (text.contains('TITLE_NOT_AVAILABLE')) return 'اللقب غير متاح.';
    return 'تعذر تنفيذ العملية الآن.';
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(text)));
  void _error(String text) => ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(text), backgroundColor: Theme.of(context).colorScheme.error));

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: _busy,
      child: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('بحث إداري دقيق بواسطة UID / ID', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _identifierController, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'UID أو ID'))),
                      const SizedBox(width: 8),
                      DropdownButton<String>(value: _identifierKind, items: const [DropdownMenuItem(value: 'UID', child: Text('UID')), DropdownMenuItem(value: 'ID', child: Text('ID'))], onChanged: (v) => setState(() => _identifierKind = v ?? 'UID')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _lookupExactIdentity, child: const Text('بحث')),
                    ],
                  ),
                  if (_targetIdentity != null) ...[
                    const Divider(height: 20),
                    Text('User ID: ${_targetIdentity!['user_id'] ?? ''}'),
                    Text('Auth UID: ${_targetIdentity!['auth_uid'] ?? ''}'),
                    Text('Username: ${_targetIdentity!['username'] ?? ''}'),
                    Text('Display: ${_targetIdentity!['display_name'] ?? ''}'),
                    Text('Role: ${_targetIdentity!['role'] ?? ''}  •  Rank: ${_targetIdentity!['rank'] ?? ''}'),
                    Text('Title: ${_targetIdentity!['title'] ?? 'غير معين'}'),
                    Text('Location: ${[_targetIdentity!['city'], _targetIdentity!['country']].whereType<String>().where((x) => x.trim().isNotEmpty).join('، ')}'),
                    Text('Latitude: ${_targetIdentity!['latitude'] ?? 'غير متوفر'}  •  Longitude: ${_targetIdentity!['longitude'] ?? 'غير متوفر'}'),
                    Text('Last Location Update: ${_targetIdentity!['location_updated_at'] ?? 'غير متوفر'}'),
                    const SizedBox(height: 8),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _future,
                      builder: (context, snapshot) {
                        final activeTitles = (snapshot.data ?? const <Map<String, dynamic>>[])
                            .where((e) => e['is_active'] == true)
                            .toList();
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: activeTitles.any((e) => e['title_key']?.toString() == _selectedExactTitleKey)
                                    ? _selectedExactTitleKey
                                    : null,
                                decoration: const InputDecoration(labelText: 'اللقب المراد تعيينه'),
                                items: [
                                  for (final title in activeTitles)
                                    DropdownMenuItem<String>(
                                      value: title['title_key']?.toString(),
                                      child: Text(title['name_ar']?.toString() ?? ''),
                                    ),
                                ],
                                onChanged: (value) => setState(() => _selectedExactTitleKey = value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _assignSelectedTitleToExactUser,
                              icon: const Icon(Icons.workspace_premium_outlined),
                              label: const Text('تعيين اللقب'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        final uid = _targetIdentity?['user_id']?.toString();
                        if (uid != null && uid.isNotEmpty) {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileViewPage(uid: uid)));
                        }
                      },
                      icon: const Icon(Icons.person_search_outlined),
                      label: const Text('فتح الملف الكامل للمستخدم المحدد'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(_friendlyError(snapshot.error!)));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: Text('ألقاب المستخدمين', textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleLarge)),
                  FilledButton.icon(onPressed: _createTitle, icon: const Icon(Icons.add), label: const Text('إضافة لقب')),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: _assignDialog, icon: const Icon(Icons.person_add_alt_1), label: const Text('تعيين لمستخدم')),
                ],
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد ألقاب في الكتالوج.'))),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(row['name_ar']?.toString() ?? ''),
                    subtitle: Text(row['title_key']?.toString() ?? ''),
                    trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 100),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تحديث',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _busy ? null : () => _editTitle(row),
                          ),
                          Switch(value: row['is_active'] == true, onChanged: _busy ? null : (_) => _toggle(row)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      )),
    ],
      ),
    );
  }
}

class _TitleForm {
  final String key;
  final String name;
  final String? iconUrl;
  final int sortOrder;

  const _TitleForm({required this.key, required this.name, required this.iconUrl, required this.sortOrder});
}
