import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure_text.dart';
import '../../../core/services/snack_sfx.dart';
import '../../../core/utils/safe_launch.dart';
import '../../profile/domain/entities/profile_entity.dart';
import '../../profile/presentation/providers/profile_provider.dart';

/// خدمة «روابط التواصل الاجتماعي» (البند ١٠).
///
/// كانت الخدمة تفتح صفحة «تعديل البروفايل» — وهي صفحة لا تحتوي محرّرًا
/// للروابط إطلاقًا (فيها حقل موسيقى ولا شيء للروابط). فالعضو يشتري
/// الخدمة، يضغطها، يُنقَل إلى صفحة لا يجد فيها ما دفع من أجله، ويعود.
/// الحقل socialLinks كان موجودًا في الكيان ويُرسَل إلى الخادم
/// (p_social_links)، ولا واجهة تكتبه.
const _platforms = <String, (String, IconData)>{
  'whatsapp': ('واتساب', Icons.chat_rounded),
  'telegram': ('تلغرام', Icons.send_rounded),
  'facebook': ('فيسبوك', Icons.facebook_rounded),
  'instagram': ('إنستغرام', Icons.camera_alt_rounded),
  'youtube': ('يوتيوب', Icons.play_circle_fill_rounded),
  'tiktok': ('تيك توك', Icons.music_note_rounded),
  'x': ('إكس', Icons.alternate_email_rounded),
  'snapchat': ('سناب شات', Icons.photo_camera_back_rounded),
  'website': ('موقع إلكتروني', Icons.language_rounded),
};

class SocialLinksPage extends ConsumerStatefulWidget {
  const SocialLinksPage({super.key});

  @override
  ConsumerState<SocialLinksPage> createState() => _SocialLinksPageState();
}

class _SocialLinksPageState extends ConsumerState<SocialLinksPage> {
  List<SocialLink>? _links;
  bool _busy = false;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(m)));

  Future<void> _save(ProfileEntity profile) async {
    final links = _links;
    if (links == null) return;
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(profileControllerProvider.notifier)
          .updateProfile(profile.copyWith(socialLinks: links));
      if (!mounted) return;
      _toast(ok ? 'حُفظت الروابط ✓' : 'تعذّر حفظ الروابط، أعد المحاولة.');
      if (ok) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) _toast(FailureText.action(e, action: 'حفظ الروابط'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(List<SocialLink> links, [int? index]) async {
    final existing = index == null ? null : links[index];
    var platform = existing?.platform ?? 'whatsapp';
    final url = TextEditingController(text: existing?.url ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (d) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (d, setD) => AlertDialog(
            title: Text(index == null ? 'رابط جديد' : 'تعديل الرابط'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue:
                    _platforms.containsKey(platform) ? platform : 'website',
                decoration: const InputDecoration(
                    labelText: 'المنصّة', border: OutlineInputBorder()),
                items: [
                  for (final e in _platforms.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Row(children: [
                        Icon(e.value.$2, size: 16),
                        const SizedBox(width: 8),
                        Text(e.value.$1),
                      ]),
                    ),
                ],
                onChanged: (v) => setD(() => platform = v ?? platform),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'الرابط أو الرقم',
                  hintText: 'https://… أو 09xxxxxxxx للواتساب',
                  border: OutlineInputBorder(),
                ),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('تم')),
            ],
          ),
        ),
      ),
    );
    final text = url.text.trim();
    url.dispose();
    if (saved != true) return;
    if (text.isEmpty) {
      _toast('اكتب الرابط.');
      return;
    }
    // رقم واتساب يُحوَّل إلى رابط حقيقي، فلا يُحفَظ رقمًا لا يَفتح.
    var finalUrl = text;
    if (platform == 'whatsapp' && !text.startsWith('http')) {
      final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
      final intl = digits.startsWith('963')
          ? digits
          : '963${digits.replaceFirst(RegExp(r'^0+'), '')}';
      finalUrl = 'https://wa.me/$intl';
    } else if (!text.startsWith('http')) {
      finalUrl = 'https://$text';
    }
    setState(() {
      final next = [...links];
      final link = SocialLink(platform: platform, url: finalUrl);
      if (index == null) {
        next.add(link);
      } else {
        next[index] = link;
      }
      _links = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('روابط التواصل الاجتماعي'), centerTitle: true),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Text(FailureText.of(e, subject: 'ملفك'),
                  textAlign: TextAlign.center),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('سجّل الدخول أولًا.'));
            }
            final links = _links ?? profile.socialLinks;
            return Column(children: [
              Expanded(
                child: links.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(26),
                          child: Text(
                            'لا روابط بعد. أضف واتسابك أو صفحتك لِيَصِل إليك '
                            'من يرى منتجاتك.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: links.length,
                        onReorder: (from, to) => setState(() {
                          final next = [...links];
                          final item = next.removeAt(from);
                          next.insert(from < to ? to - 1 : to, item);
                          _links = next;
                        }),
                        itemBuilder: (_, i) {
                          final l = links[i];
                          final meta =
                              _platforms[l.platform] ?? ('رابط', Icons.link);
                          return Card(
                            key: ValueKey('${l.platform}_${l.url}_$i'),
                            child: ListTile(
                              leading: Icon(meta.$2),
                              title: Text(meta.$1),
                              subtitle: Text(l.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                              trailing:
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  tooltip: 'جرّب الرابط',
                                  icon: const Icon(Icons.open_in_new_rounded,
                                      size: 18),
                                  onPressed: () async {
                                    final ok = await safeLaunch(l.url);
                                    if (!ok && context.mounted) {
                                      _toast('تعذّر فتح هذا الرابط.');
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  onPressed: () => _edit(links, i),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Colors.redAccent),
                                  onPressed: () => setState(() {
                                    final next = [...links]..removeAt(i);
                                    _links = next;
                                  }),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _edit(links),
                        icon: const Icon(Icons.add_link_rounded, size: 18),
                        label: const Text('إضافة رابط'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            (_busy || _links == null) ? null : () => _save(profile),
                        icon: _busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: const Text('حفظ'),
                      ),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
