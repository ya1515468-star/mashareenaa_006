import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/geo_location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// لوحة تحكّم المالك بالمستخدمين:
/// بحث شامل (اسم/معرّف/إيميل/رقم) + فلترة بالدولة والمدينة والحالة،
/// وتفاصيل كاملة لكل عضو، وكل أوامر الإدارة مع إمكانية الإلغاء.
/// كل شيء خادمي عبر RPCs محميّة بـ is_my_platform_owner().

// ─── أنواع القيود ────────────────────────────────────────────────────
class _RestrictionKind {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const _RestrictionKind(
      this.key, this.label, this.description, this.icon, this.color);
}

const _kRestrictions = <_RestrictionKind>[
  _RestrictionKind('ban', 'حظر', 'منع الدخول للمنصة كليًا',
      Icons.block_rounded, Color(0xFFEF4444)),
  _RestrictionKind('mute', 'كتم', 'منع إرسال الرسائل',
      Icons.volume_off_rounded, Color(0xFFF59E0B)),
  _RestrictionKind('suspend', 'تعليق الحساب', 'تجميد الحساب مؤقتًا',
      Icons.pause_circle_rounded, Color(0xFFA855F7)),
  _RestrictionKind('no_media', 'منع الوسائط', 'لا صور ولا فيديو ولا صوت',
      Icons.image_not_supported_rounded, Color(0xFF06B6D4)),
  _RestrictionKind('no_gift', 'منع الهدايا', 'لا يرسل ولا يستقبل هدايا',
      Icons.card_giftcard_rounded, Color(0xFFEC4899)),
  _RestrictionKind('no_room', 'منع الغرف', 'لا يدخل أي غرفة دردشة',
      Icons.meeting_room_rounded, Color(0xFF8B5CF6)),
  _RestrictionKind('shadow', 'حظر خفي', 'رسائله تظهر له وحده',
      Icons.visibility_off_rounded, Color(0xFF64748B)),
];

const _kDurations = <String, int?>{
  'دائم': null,
  'ساعة': 60,
  '6 ساعات': 360,
  'يوم': 1440,
  '3 أيام': 4320,
  'أسبوع': 10080,
  'شهر': 43200,
};

// ─── مزوّدو البيانات ─────────────────────────────────────────────────
class OwnerSearchArgs {
  final String query;
  final String? country;
  final String? city;
  final String status;
  const OwnerSearchArgs({
    this.query = '',
    this.country,
    this.city,
    this.status = 'all',
  });

  @override
  bool operator ==(Object other) =>
      other is OwnerSearchArgs &&
      other.query == query &&
      other.country == country &&
      other.city == city &&
      other.status == status;

  @override
  int get hashCode => Object.hash(query, country, city, status);
}

final ownerUserSearchProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, OwnerSearchArgs>((ref, args) async {
  final raw = await Supabase.instance.client.rpc(
    'owner_search_users',
    params: {
      'p_query': args.query,
      'p_country': args.country,
      'p_city': args.city,
      'p_status': args.status,
      'p_limit': 100,
      'p_offset': 0,
    },
  );
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

final ownerLocationsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final raw = await Supabase.instance.client.rpc('owner_user_locations');
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

final ownerUserDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, uid) async {
  final raw = await Supabase.instance.client
      .rpc('owner_user_detail', params: {'p_user_id': uid});
  return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
});

// ─── التبويب ─────────────────────────────────────────────────────────
class OwnerUserControlTab extends ConsumerStatefulWidget {
  const OwnerUserControlTab({super.key});

  @override
  ConsumerState<OwnerUserControlTab> createState() =>
      _OwnerUserControlTabState();
}

class _OwnerUserControlTabState extends ConsumerState<OwnerUserControlTab> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  OwnerSearchArgs _args = const OwnerSearchArgs();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _args = OwnerSearchArgs(
            query: v.trim(),
            country: _args.country,
            city: _args.city,
            status: _args.status,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(ownerUserSearchProvider(_args));
    final locations = ref.watch(ownerLocationsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _buildFilters(locations),
          const Divider(height: 1),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBox(
                message: e.toString().contains('OWNER_ONLY')
                    ? 'هذه اللوحة للمالك فقط.'
                    : 'تعذّر تحميل المستخدمين:\n$e',
                onRetry: () => ref.invalidate(ownerUserSearchProvider(_args)),
              ),
              data: (data) {
                final users = (data['users'] as List?) ?? const [];
                if (users.isEmpty) {
                  return const _EmptyBox(
                      icon: Icons.person_search_rounded,
                      message: 'لا نتائج مطابقة');
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Text('${users.length} من ${data['total'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54)),
                          const Spacer(),
                          IconButton(
                            tooltip: 'تحديث',
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            onPressed: () {
                              ref.invalidate(ownerUserSearchProvider(_args));
                              ref.invalidate(ownerLocationsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _UserCard(
                          user: Map<String, dynamic>.from(users[i] as Map),
                          onChanged: () =>
                              ref.invalidate(ownerUserSearchProvider(_args)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AsyncValue<Map<String, dynamic>> locations) {
    final locData = locations.valueOrNull ?? const <String, dynamic>{};
    final countries = ((locData['countries'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final allCities = ((locData['cities'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final cities = _args.country == null
        ? allCities
        : allCities.where((c) => c['country'] == _args.country).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو المعرّف أو الإيميل…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.public_rounded,
                  label: _args.country ?? 'كل الدول',
                  active: _args.country != null,
                  onTap: () => _pickCountry(countries),
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  icon: Icons.location_city_rounded,
                  label: _args.city ?? 'كل المدن',
                  active: _args.city != null,
                  onTap: cities.isEmpty ? null : () => _pickCity(cities),
                ),
                const SizedBox(width: 6),
                ...['all', 'online', 'banned', 'muted', 'suspended', 'clean']
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _FilterChip(
                            label: _statusLabel(s),
                            active: _args.status == s,
                            onTap: () => setState(() => _args = OwnerSearchArgs(
                                  query: _args.query,
                                  country: _args.country,
                                  city: _args.city,
                                  status: s,
                                )),
                          ),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'online' => 'متصل',
        'banned' => 'محظور',
        'muted' => 'مكتوم',
        'suspended' => 'معلّق',
        'clean' => 'نظيف',
        _ => 'الكل',
      };

  Future<void> _pickCountry(List<Map<String, dynamic>> countries) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'اختر الدولة',
        items: [
          const MapEntry<String?, String>(null, 'كل الدول'),
          ...countries.map((c) => MapEntry<String?, String>(
              c['country']?.toString(),
              '${c['country']}  (${c['count']})')),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _args = OwnerSearchArgs(
          query: _args.query,
          country: picked,
          city: null,
          status: _args.status,
        ));
  }

  Future<void> _pickCity(List<Map<String, dynamic>> cities) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (_) => _PickerSheet(
        title: 'اختر المدينة',
        items: [
          const MapEntry<String?, String>(null, 'كل المدن'),
          ...cities.map((c) => MapEntry<String?, String>(
              c['city']?.toString(),
              '${c['city']} — ${c['country']}  (${c['count']})')),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _args = OwnerSearchArgs(
          query: _args.query,
          country: _args.country,
          city: picked,
          status: _args.status,
        ));
  }
}

// ─── بطاقة المستخدم ──────────────────────────────────────────────────
class _UserCard extends ConsumerWidget {
  final Map<String, dynamic> user;
  final VoidCallback onChanged;
  const _UserCard({required this.user, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (user['display_name']?.toString().trim().isNotEmpty == true)
        ? user['display_name'].toString()
        : (user['username']?.toString() ?? 'عضو');
    final kinds = ((user['restriction_kinds'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final online = user['is_online'] == true;
    final location = [
      user['country']?.toString(),
      user['city']?.toString(),
      user['address']?.toString(),
    ].where((e) => e != null && e.trim().isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: kinds.isEmpty
              ? Colors.white12
              : const Color(0xFFEF4444).withValues(alpha: .5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        (user['avatar_url']?.toString().isNotEmpty == true)
                            ? NetworkImage(user['avatar_url'].toString())
                            : null,
                    child: (user['avatar_url']?.toString().isEmpty != false)
                        ? const Icon(Icons.person_rounded)
                        : null,
                  ),
                  if (online)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.black, width: 1.6),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5)),
                        ),
                        if (user['verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              size: 15, color: Color(0xFF38BDF8)),
                        ],
                        if (user['role_name'] != null) ...[
                          const SizedBox(width: 6),
                          _Pill(
                              text: user['role_name'].toString(),
                              color: const Color(0xFF6366F1)),
                        ],
                      ],
                    ),
                    if (user['username'] != null)
                      Text('@${user['username']}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38)),
                    if (location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 12, color: Color(0xFF34D399)),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF34D399))),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _Pill(
                            text: '⭐ ${user['points'] ?? 0}',
                            color: const Color(0xFFF59E0B)),
                        _Pill(
                            text: '💎 ${user['gems'] ?? 0}',
                            color: const Color(0xFF06B6D4)),
                        if (user['is_suspended'] == true)
                          const _Pill(
                              text: 'معلّق', color: Color(0xFFA855F7)),
                        ...kinds.map((k) {
                          final r = _kRestrictions.firstWhere(
                              (e) => e.key == k,
                              orElse: () => _kRestrictions.first);
                          return _Pill(text: r.label, color: r.color);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(
          userId: user['id'].toString(), onChanged: onChanged),
    );
  }
}

// ─── ورقة التفاصيل والإجراءات ────────────────────────────────────────
class _UserDetailSheet extends ConsumerWidget {
  final String userId;
  final VoidCallback onChanged;
  const _UserDetailSheet({required this.userId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(ownerUserDetailProvider(userId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: .85,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (context, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14101F),
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: detail.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorBox(
              message: '$e',
              onRetry: () => ref.invalidate(ownerUserDetailProvider(userId)),
            ),
            data: (data) =>
                _detailBody(context, ref, data, scrollCtrl),
          ),
        ),
      ),
    );
  }

  Widget _detailBody(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, ScrollController scrollCtrl) {
    final profile =
        Map<String, dynamic>.from((data['profile'] as Map?) ?? {});
    final wallets =
        Map<String, dynamic>.from((data['wallets'] as Map?) ?? {});
    final stats = Map<String, dynamic>.from((data['stats'] as Map?) ?? {});
    final restrictions = ((data['restrictions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final rooms = ((data['rooms'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final log = ((data['recent_actions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final active = restrictions.where((r) => r['active'] == true).toList();

    final name =
        (profile['display_name']?.toString().trim().isNotEmpty == true)
            ? profile['display_name'].toString()
            : (profile['username']?.toString() ?? 'عضو');

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  (profile['avatar_url']?.toString().isNotEmpty == true)
                      ? NetworkImage(profile['avatar_url'].toString())
                      : null,
              child: (profile['avatar_url']?.toString().isEmpty != false)
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  if (profile['username'] != null)
                    Text('@${profile['username']}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // الموقع
        _Section(title: 'الموقع', icon: Icons.place_rounded, children: [
          _KV('الدولة', profile['country']?.toString() ?? '—'),
          _KV('المدينة', profile['city']?.toString() ?? '—'),
          _KV('العنوان', profile['address']?.toString() ?? '—'),
          _KV('آخر IP', profile['last_ip']?.toString() ?? '—'),
          _KV(
              'المصدر',
              switch (profile['location_source']?.toString()) {
                'geoip' => 'استنتاج تلقائي من IP',
                'manual' => 'تعيين يدوي',
                _ => 'لم يُحدَّد بعد',
              }),
          if (profile['location_latitude'] != null)
            _KV('الإحداثيات',
                '${profile['location_latitude']}, ${profile['location_longitude']}'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: const Text('استنتاج من IP',
                    style: TextStyle(fontSize: 12)),
                onPressed: () => _resolveLocation(context, ref),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                label: const Text('تعديل يدويًا',
                    style: TextStyle(fontSize: 12)),
                onPressed: () => _editLocation(context, ref, profile),
              ),
            ),
          ]),
        ]),

        _Section(title: 'الحساب', icon: Icons.badge_rounded, children: [
          _KV('الإيميل', profile['email']?.toString() ?? '—'),
          _KV('المهنة', profile['profession']?.toString() ?? '—'),
          _KV('نوع الحساب', profile['account_type']?.toString() ?? '—'),
          _KV('انضم', _fmtDate(profile['created_at'])),
          _KV('آخر ظهور', _fmtDate(profile['last_seen_at'])),
          _KV('النقاط', '${wallets['points'] ?? 0}'),
          _KV('الجواهر', '${wallets['gems'] ?? 0}'),
          _KV('الرسائل', '${stats['messages'] ?? 0}'),
          _KV('الفيديوهات', '${stats['reels'] ?? 0}'),
          _KV('الخبرة', '${stats['xp'] ?? 0}'),
        ]),

        // القيود الفعّالة
        if (active.isNotEmpty)
          _Section(
            title: 'القيود الفعّالة (${active.length})',
            icon: Icons.gpp_bad_rounded,
            children: active
                .map((r) => _ActiveRestrictionRow(
                      restriction: r,
                      onRevoke: () => _revoke(context, ref, r),
                    ))
                .toList(),
          ),

        // الإجراءات
        _Section(
          title: 'الإجراءات',
          icon: Icons.admin_panel_settings_rounded,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kRestrictions.map((r) {
                final isActive = active.any((a) => a['kind'] == r.key);
                return ActionChip(
                  avatar: Icon(r.icon, size: 16, color: r.color),
                  label: Text(isActive ? '${r.label} ✓' : r.label,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: isActive ? r.color : Colors.white70,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w500)),
                  backgroundColor: isActive
                      ? r.color.withValues(alpha: .16)
                      : Colors.white10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: isActive
                            ? r.color.withValues(alpha: .6)
                            : Colors.white12),
                  ),
                  onPressed: () => _apply(context, ref, r),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (active.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('إلغاء كل القيود'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF34D399)),
                  onPressed: () => _clearAll(context, ref),
                ),
              ),
          ],
        ),

        if (rooms.isNotEmpty)
          _Section(
            title: 'الغرف (${rooms.length})',
            icon: Icons.forum_rounded,
            children: rooms
                .map((r) => _KV(
                    r['room_name']?.toString() ?? 'غرفة',
                    r['is_banned'] == true
                        ? 'محظور'
                        : (r['role']?.toString() ?? 'عضو')))
                .toList(),
          ),

        if (log.isNotEmpty)
          _Section(
            title: 'سجل الأوامر',
            icon: Icons.history_rounded,
            children: log
                .take(15)
                .map((l) => _KV(_actionLabel(l['action']?.toString() ?? ''),
                    _fmtDate(l['created_at'])))
                .toList(),
          ),
      ],
    );
  }

  static String _actionLabel(String a) => switch (a) {
        'apply_restriction' => 'تطبيق قيد',
        'revoke_restriction' => 'إلغاء قيد',
        'clear_all_restrictions' => 'إلغاء شامل',
        _ => a,
      };

  static String _fmtDate(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    if (d == null) return '—';
    final l = d.toLocal();
    return '${l.year}/${l.month.toString().padLeft(2, '0')}/'
        '${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// يستعلم مزوّد GeoIP بالـIP المحفوظ للعضو ويحفظ النتيجة خادميًا.
  Future<void> _resolveLocation(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(const SnackBar(
        content: Text('جارٍ الاستنتاج من الـIP…'),
        duration: Duration(seconds: 2)));
    try {
      final err = await GeoLocationService.resolveForUser(userId);
      ref.invalidate(ownerUserDetailProvider(userId));
      onChanged();
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
        content: Text(err ?? 'حُدّد الموقع من الـIP'),
        backgroundColor:
            err == null ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
      ));
    } catch (e) {
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
          content: Text('تعذّر الاستنتاج: $e'),
          backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<void> _editLocation(BuildContext context, WidgetRef ref,
      Map<String, dynamic> profile) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _LocationDialog(
        country: profile['country']?.toString() ?? '',
        city: profile['city']?.toString() ?? '',
        address: profile['address']?.toString() ?? '',
      ),
    );
    if (result == null) return;
    await _run(messenger, ref, () async {
      await Supabase.instance.client.rpc('owner_set_user_location', params: {
        'p_user_id': userId,
        'p_country': result['country'],
        'p_city': result['city'],
        'p_address': result['address'],
      });
    }, 'حُدّث الموقع');
  }

  Future<void> _apply(
      BuildContext context, WidgetRef ref, _RestrictionKind kind) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ApplyDialog(kind: kind),
    );
    if (result == null) return;
    await _run(messenger, ref, () async {
      await Supabase.instance.client.rpc('owner_apply_restriction', params: {
        'p_user_id': userId,
        'p_kind': kind.key,
        'p_reason': result['reason'],
        'p_room_id': null,
        'p_scope': 'global',
        'p_duration_mins': result['duration'],
      });
    }, '${kind.label} — تم');
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref,
      Map<String, dynamic> r) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _confirm(
        context, 'إلغاء القيد', 'سيُرفع القيد فورًا عن هذا العضو.');
    if (ok != true) return;
    await _run(messenger, ref, () async {
      await Supabase.instance.client.rpc('owner_revoke_restriction',
          params: {'p_restriction_id': r['id'], 'p_reason': 'إلغاء يدوي'});
    }, 'أُلغي القيد');
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await _confirm(context, 'إلغاء كل القيود',
        'سيُرفع كل قيد فعّال عن هذا العضو دفعة واحدة.');
    if (ok != true) return;
    await _run(messenger, ref, () async {
      await Supabase.instance.client.rpc('owner_clear_user_restrictions',
          params: {'p_user_id': userId, 'p_reason': 'إلغاء شامل'});
    }, 'أُلغيت كل القيود');
  }

  Future<bool?> _confirm(
          BuildContext context, String title, String body) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('تأكيد')),
            ],
          ),
        ),
      );

  /// يأخذ الـ messenger لا الـ BuildContext.
  ///
  /// التقاط context بعد await خطر: الشاشة قد تُغلق أثناء نداء الخادم
  /// فيصير المرجع معلَّقًا. نلتقط ScaffoldMessengerState قبل أول
  /// await ونستعمله بعده — وهو آمن لأنه لا يعتمد على بقاء الشجرة.
  Future<void> _run(ScaffoldMessengerState? messenger, WidgetRef ref,
      Future<void> Function() op, String successMsg) async {
    try {
      await op();
      ref.invalidate(ownerUserDetailProvider(userId));
      onChanged();
      messenger?.showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF16A34A)));
    } catch (e) {
      final msg = e.toString().contains('CANNOT_RESTRICT_OWNER')
          ? 'لا يمكن تقييد مالك المنصة.'
          : e.toString().contains('OWNER_ONLY')
              ? 'هذا الإجراء للمالك فقط.'
              : 'فشل الإجراء: $e';
      messenger?.showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: const Color(0xFFDC2626)));
    }
  }
}

// ─── حوار تطبيق القيد ────────────────────────────────────────────────
class _ApplyDialog extends StatefulWidget {
  final _RestrictionKind kind;
  const _ApplyDialog({required this.kind});

  @override
  State<_ApplyDialog> createState() => _ApplyDialogState();
}

class _ApplyDialogState extends State<_ApplyDialog> {
  final _reasonCtrl = TextEditingController();
  String _duration = 'دائم';

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(widget.kind.icon, color: widget.kind.color, size: 22),
            const SizedBox(width: 8),
            Text(widget.kind.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.kind.description,
                style: const TextStyle(
                    fontSize: 12.5, color: Colors.white54)),
            const SizedBox(height: 14),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'السبب',
                hintText: 'يظهر للعضو',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text('المدة',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _kDurations.keys
                  .map((k) => ChoiceChip(
                        label: Text(k, style: const TextStyle(fontSize: 12)),
                        selected: _duration == k,
                        onSelected: (_) => setState(() => _duration = k),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: widget.kind.color),
            onPressed: () => Navigator.pop(context, {
              'reason': _reasonCtrl.text.trim(),
              'duration': _kDurations[_duration],
            }),
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

// ─── حوار تعديل الموقع ───────────────────────────────────────────────
class _LocationDialog extends StatefulWidget {
  final String country;
  final String city;
  final String address;
  const _LocationDialog(
      {required this.country, required this.city, required this.address});

  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  late final _countryCtrl = TextEditingController(text: widget.country);
  late final _cityCtrl = TextEditingController(text: widget.city);
  late final _addressCtrl = TextEditingController(text: widget.address);

  /// اقتراحات سريعة للسوق الأساسي — تختصر الكتابة، ولا تمنع أي قيمة أخرى.
  static const _quick = <String, List<String>>{
    'سورية': ['دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'إدلب', 'درعا'],
    'تركيا': ['إسطنبول', 'غازي عنتاب', 'مرسين', 'أنقرة', 'إزمير'],
    'مصر': ['القاهرة', 'الإسكندرية', 'المحلة الكبرى', 'العاشر من رمضان'],
    'السعودية': ['الرياض', 'جدة', 'الدمام', 'مكة'],
    'الأردن': ['عمّان', 'إربد', 'الزرقاء'],
  };

  @override
  void dispose() {
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cities = _quick[_countryCtrl.text.trim()] ?? const <String>[];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تعديل الموقع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _countryCtrl,
                textDirection: TextDirection.rtl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: 'الدولة',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: _quick.keys
                    .map((c) => ActionChip(
                          label: Text(c,
                              style: const TextStyle(fontSize: 11.5)),
                          onPressed: () => setState(() {
                            _countryCtrl.text = c;
                            _cityCtrl.clear();
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cityCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                    labelText: 'المدينة',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
              if (cities.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: cities
                      .map((c) => ActionChip(
                            label: Text(c,
                                style: const TextStyle(fontSize: 11.5)),
                            onPressed: () =>
                                setState(() => _cityCtrl.text = c),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'country': _countryCtrl.text.trim(),
              'city': _cityCtrl.text.trim(),
              'address': _addressCtrl.text.trim(),
            }),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ─── ودجات مساعدة ────────────────────────────────────────────────────
class _ActiveRestrictionRow extends StatelessWidget {
  final Map<String, dynamic> restriction;
  final VoidCallback onRevoke;
  const _ActiveRestrictionRow(
      {required this.restriction, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final kind = _kRestrictions.firstWhere(
        (e) => e.key == restriction['kind'],
        orElse: () => _kRestrictions.first);
    final expires = DateTime.tryParse(
        restriction['expires_at']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kind.color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(kind.icon, size: 17, color: kind.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: kind.color)),
                if (restriction['reason']?.toString().isNotEmpty == true)
                  Text(restriction['reason'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54)),
                Text(
                    expires == null
                        ? 'دائم'
                        : 'ينتهي ${expires.toLocal()}'.split('.').first,
                    style: const TextStyle(
                        fontSize: 10.5, color: Colors.white38)),
              ],
            ),
          ),
          TextButton(
            onPressed: onRevoke,
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF34D399),
                visualDensity: VisualDensity.compact),
            child: const Text('إلغاء', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 17, color: const Color(0xFFC47CFF)),
              const SizedBox(width: 7),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 13.5)),
            ]),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _KV extends StatelessWidget {
  final String k;
  final String v;
  const _KV(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white38)),
            ),
            Expanded(
              child: SelectableText(v,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
      );
}

class _FilterChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _FilterChip(
      {this.icon, required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFC47CFF).withValues(alpha: .18)
                : Colors.white10,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: active
                    ? const Color(0xFFC47CFF).withValues(alpha: .6)
                    : Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: active ? const Color(0xFFC47CFF) : Colors.white54),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? const Color(0xFFC47CFF)
                          : Colors.white60,
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        ),
      );
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<MapEntry<String?, String>> items;
  const _PickerSheet({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(items[i].value,
                        style: const TextStyle(fontSize: 13.5)),
                    onTap: () => Navigator.pop(context, items[i].key),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyBox({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white24),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
}
