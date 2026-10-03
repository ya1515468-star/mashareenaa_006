import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/vip_favorite_button.dart';
import '../widgets/vip_link_preview.dart';
import '../widgets/vip_presence_plus.dart';

/// Dedicated runtime surface for the six VIP chat services that previously
/// fell back to the generic settings dialog.
class VipChatRuntimeCenterPage extends ConsumerStatefulWidget {
  final String featureKey;
  const VipChatRuntimeCenterPage({super.key, required this.featureKey});

  @override
  ConsumerState<VipChatRuntimeCenterPage> createState() =>
      _VipChatRuntimeCenterPageState();
}

class _VipChatRuntimeCenterPageState
    extends ConsumerState<VipChatRuntimeCenterPage> {
  final _linkController =
      TextEditingController(text: 'https://example.com/mashareena');
  final _tipLabelController = TextEditingController(text: 'دعم المنشئ');
  final _tipAmountController = TextEditingController(text: '100');
  int _smartMuteSeconds = 30;
  bool _busy = false;
  late final Future<Map<String, dynamic>> _runtimeFuture;

  String get _title => switch (widget.featureKey) {
        'chat_link_preview_plus' => 'معاينة الروابط Plus',
        'chat_media_plus' => 'وسائط Plus',
        'chat_favorites_plus' => 'مفضلة الشات Plus',
        'chat_presence_plus' => 'حضور Plus',
        'chat_smart_mute' => 'الكتم الذكي',
        'creator_tip_button' => 'دعم المنشئ',
        _ => 'خدمة VIP',
      };

  IconData get _icon => switch (widget.featureKey) {
        'chat_link_preview_plus' => Icons.link,
        'chat_media_plus' => Icons.perm_media,
        'chat_favorites_plus' => Icons.star,
        'chat_presence_plus' => Icons.online_prediction,
        'chat_smart_mute' => Icons.notifications_off,
        'creator_tip_button' => Icons.volunteer_activism,
        _ => Icons.auto_awesome,
      };

  @override
  void initState() {
    super.initState();
    _runtimeFuture = _runtime();
  }

  @override
  void dispose() {
    _linkController.dispose();
    _tipLabelController.dispose();
    _tipAmountController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _runtime() async {
    final raw = await Supabase.instance.client.rpc(
      'get_profile_service_runtime',
      params: {'p_feature_key': widget.featureKey},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> _saveSetting(String key, dynamic value) =>
      Supabase.instance.client.rpc(
        'set_profile_service_setting',
        params: {
          'p_feature_key': widget.featureKey,
          'p_key': key,
          'p_value': value,
        },
      );

  Future<void> _saveSmartMute() async {
    setState(() => _busy = true);
    try {
      await _saveSetting('value', _smartMuteSeconds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ مدة الكتم الذكي وربطها بخدمة أصوات الشات ✓'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveTipSettings() async {
    final label = _tipLabelController.text.trim();
    final amount = int.tryParse(_tipAmountController.text.trim());
    if (label.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل عنوانًا ومقدار دعم صالحًا.'),
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      await _saveSetting('value', label);
      await _saveSetting('default_amount', amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حفظ إعدادات زر دعم المنشئ ✓'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _header(Map<String, dynamic> runtime) {
    final enabled = runtime['enabled'] == true;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon)),
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(enabled ? 'مفعلة على الخادم ✓' : 'غير مفعلة على الخادم'),
        trailing: Icon(
          enabled ? Icons.verified : Icons.error_outline,
          color: enabled ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
    );
  }

  Widget _linkSurface() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('اختبار المعاينة الفعلية:',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _linkController,
            decoration: const InputDecoration(
              labelText: 'الرابط',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          VipLinkPreview(url: _linkController.text),
          const SizedBox(height: 8),
          const Text(
            'هذه المعاينة تستخدم نفس ودجت الإنتاج المستخدم داخل فقاعات رسائل الشات.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );

  Widget _mediaSurface() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.perm_media),
            title: Text('حد الوسائط Plus'),
            subtitle: Text('حتى 25MB للمسارات التي تسمح بها الخدمة.'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final picked =
                  await FilePicker.pickFiles(withData: true);
              final bytes = picked?.files.single.bytes;
              if (!mounted || bytes == null) return;
              final ok = bytes.length <= 25 * 1024 * 1024;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'فحص محلي: الملف ضمن حد 25MB.'
                    : 'فحص محلي: الملف يتجاوز حد 25MB.'),
              ));
            },
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('فحص ملف تجريبي بدون رفع'),
          ),
          const SizedBox(height: 8),
          const Text(
            'الرفع الفعلي يبقى عبر بوابة الوسائط الحالية وحماية Storage/RLS؛ هذا الفحص لا يكتب على الخادم.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      );

  Widget _favoritesSurface(Map<String, dynamic> runtime) {
    final settings = runtime['settings'];
    final ids = settings is Map && settings['favorite_message_ids'] is List
        ? settings['favorite_message_ids'] as List
        : const <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star),
          title: const Text('مفضلة الشات الحقيقية'),
          subtitle: Text('الرسائل المحفوظة: ${ids.length}'),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'زر النجمة داخل إجراءات الرسالة هو سطح الاستخدام الحقيقي. الصفحة لا تنشئ رسالة وهمية.',
            ),
          ),
        ),
        const Align(
          alignment: Alignment.center,
          child: VipFavoriteButton(
            messageId: '__runtime_preview__',
            enabled: false,
          ),
        ),
      ],
    );
  }

  Widget _presenceSurface() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const Text('لا توجد جلسة مستخدم حالية.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('حضور الحساب الفعلي:',
            style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        VipPresencePlus(uid: uid),
        const SizedBox(height: 8),
        const Text(
          'البيانات تُقرأ من user_presence على الخادم، وليست حالة محلية وهمية.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _smartMuteSurface(Map<String, dynamic> runtime) {
    final settings = runtime['settings'];
    final existing = settings is Map
        ? int.tryParse('${settings['value'] ?? 30}')
        : null;
    final currentSeconds = existing?.clamp(5, 300) ?? _smartMuteSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('منع تكرار صوت الحدث نفسه خلال $currentSeconds ثانية.'),
        Slider(
          value: currentSeconds.toDouble(),
          min: 5,
          max: 300,
          divisions: 59,
          label: '$_smartMuteSeconds ث',
          onChanged: (v) => setState(() => _smartMuteSeconds = v.round()),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _saveSmartMute,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ وربط مع ChatSoundService'),
        ),
      ],
    );
  }

  Widget _creatorTipSurface(Map<String, dynamic> runtime) {
    final settings = runtime['settings'];
    if (settings is Map) {
      final currentLabel = settings['value']?.toString();
      final currentAmount = settings['default_amount']?.toString();
      if (_tipLabelController.text == 'دعم المنشئ' &&
          currentLabel?.isNotEmpty == true) {
        _tipLabelController.text = currentLabel!;
      }
      if (_tipAmountController.text == '100' &&
          currentAmount?.isNotEmpty == true) {
        _tipAmountController.text = currentAmount!;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _tipLabelController,
          decoration: const InputDecoration(
            labelText: 'عنوان زر الدعم',
            prefixIcon: Icon(Icons.volunteer_activism),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tipAmountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مقدار الدعم الافتراضي',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _busy ? null : _saveTipSettings,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ الإعدادات على الخادم'),
        ),
      ],
    );
  }

  Widget _body(Map<String, dynamic> runtime) => switch (widget.featureKey) {
        'chat_link_preview_plus' => _linkSurface(),
        'chat_media_plus' => _mediaSurface(),
        'chat_favorites_plus' => _favoritesSurface(runtime),
        'chat_presence_plus' => _presenceSurface(),
        'chat_smart_mute' => _smartMuteSurface(runtime),
        'creator_tip_button' => _creatorTipSurface(runtime),
        _ => const Text('خدمة غير معروفة.'),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _runtimeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر قراءة حالة الخدمة من الخادم: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final runtime = snapshot.data ?? <String, dynamic>{};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(runtime),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _body(runtime),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
