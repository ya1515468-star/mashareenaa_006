import 'dart:async';
import '../../../../core/error/failure_text.dart';
import '../../../../core/services/snack_sfx.dart';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/resilient_realtime_channel.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/embedded_media_player.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/content/content_interaction_bar.dart';
import '../../../../core/content/filtered_image_picker.dart';
import '../../../../core/content/media_viewer.dart';
import '../widgets/mini_chat_overlay.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';

/// صورة منتج قيد الإضافة: إما موجودة سلفًا (رابط Storage عند التعديل)
/// أو مُختارة لتوّها من المعرض بانتظار الرفع عند الحفظ.
class _PickedImage {
  final String? url;
  final Uint8List? bytes;
  final String? name;
  _PickedImage.existing(this.url) : bytes = null, name = null;
  _PickedImage.local(this.bytes, this.name) : url = null;
}

final platformWallProductsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final controller = StreamController<List<Map<String, dynamic>>>();
  var disposed = false;

  Future<void> load() async {
    try {
      final rows = await client
          .from('platform_wall_products')
          .select('*')
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      if (!disposed) {
        controller.add(List<Map<String, dynamic>>.from(rows));
      }
    } catch (e, st) {
      if (!disposed) controller.addError(e, st);
    }
  }

  unawaited(load());
  final channel = client.channel('platform-wall-products-live')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'platform_wall_products',
      callback: (_) => unawaited(load()),
    )
    ..subscribe(retryOnChannelError(() {
      if (!disposed) unawaited(load());
    }, isAlive: () => !disposed));

  ref.onDispose(() {
    disposed = true;
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });
  return controller.stream;
});

class FriendsWallPage extends ConsumerStatefulWidget {
  const FriendsWallPage({super.key});

  @override
  ConsumerState<FriendsWallPage> createState() => _FriendsWallPageState();
}

class _FriendsWallPageState extends ConsumerState<FriendsWallPage> {
  bool _isPlatformOwner = false;
  bool _canPost = false;
  Map<String, dynamic>? _settings;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOwnerState());
  }

  /// كان النشر حصريًّا على المالك فقط؛ الآن قد يُمنَح عضو آخر الصلاحية
  /// (get_my_wall_access تُرجع can_post التي تجمع الحالتين).
  Future<void> _loadOwnerState() async {
    try {
      final result = await Supabase.instance.client.rpc('get_my_wall_access');
      if (mounted && result is Map) {
        setState(() {
          _isPlatformOwner = result['is_owner'] == true;
          _canPost = result['can_post'] == true;
          _settings = result['settings'] is Map ? Map<String, dynamic>.from(result['settings']) : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _manageAccess() async {
    final uidCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '${_settings?['points_cost'] ?? 0}');
    final gemsCtrl = TextEditingController(text: '${_settings?['gems_cost'] ?? 200}');
    final daysCtrl = TextEditingController(text: '${_settings?['duration_days'] ?? 7}');
    var postingEnabled = _settings?['posting_enabled'] != false;
    final m = ScaffoldMessenger.maybeOf(context);
    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: const Text('إدارة الحائط'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('السماح بالنشر لغير المالك'),
                value: postingEnabled,
                onChanged: (v) => setLocal(() => postingEnabled = v),
              ),
              TextField(controller: pointsCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رسم النشر — نقاط ⭐')),
              TextField(controller: gemsCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'رسم النشر — جواهر 💎')),
              TextField(controller: daysCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مدة ظهور المنتج (أيام)')),
              const Divider(height: 24),
              const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('منح صلاحية النشر لعضو (UID)', style: TextStyle(fontWeight: FontWeight.w700))),
              Row(children: [
                Expanded(child: TextField(controller: uidCtrl, decoration: const InputDecoration(hintText: 'معرّف العضو'))),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () async {
                    final uid = uidCtrl.text.trim();
                    if (uid.isEmpty) return;
                    try {
                      await Supabase.instance.client.rpc('owner_set_wall_access', params: {'p_user_id': uid, 'p_enabled': true});
                      m?.showSnackBarSfx(const SnackBar(content: Text('مُنحت الصلاحية')));
                      uidCtrl.clear();
                    } catch (e) {
                      m?.showSnackBarSfx(SnackBar(content: Text(FailureText.of(e))));
                    }
                  },
                  child: const Text('منح'),
                ),
                TextButton(
                  onPressed: () async {
                    final uid = uidCtrl.text.trim();
                    if (uid.isEmpty) return;
                    try {
                      await Supabase.instance.client.rpc('owner_set_wall_access', params: {'p_user_id': uid, 'p_enabled': false});
                      m?.showSnackBarSfx(const SnackBar(content: Text('سُحبت الصلاحية')));
                      uidCtrl.clear();
                    } catch (e) {
                      m?.showSnackBarSfx(SnackBar(content: Text(FailureText.of(e))));
                    }
                  },
                  child: const Text('سحب', style: TextStyle(color: Colors.redAccent)),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('إغلاق')),
            FilledButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.rpc('owner_set_wall_settings', params: {
                    'p_posting_enabled': postingEnabled,
                    'p_points_cost': int.tryParse(pointsCtrl.text.trim()) ?? 0,
                    'p_gems_cost': int.tryParse(gemsCtrl.text.trim()) ?? 0,
                    'p_duration_days': int.tryParse(daysCtrl.text.trim()) ?? 7,
                  });
                  if (d.mounted) Navigator.pop(d);
                  await _loadOwnerState();
                } catch (e) {
                  m?.showSnackBarSfx(SnackBar(content: Text(FailureText.action(e, action: 'الحفظ'))));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  /// غير المالك يدفع رسم نشر بمدة يحدّدها المالك؛ الخادم يفرضهما فعليًا
  /// (ends_at يُستبدَل بصرف النظر عمّا يرسله النموذج)، وهذا مجرد عرض
  /// واضح للرسم قبل أن يبدأ المستخدم بملء النموذج.
  Future<void> _confirmThenOpenEditor() async {
    if (!_isPlatformOwner) {
      final gems = (_settings?['gems_cost'] as num?)?.toInt() ?? 0;
      final points = (_settings?['points_cost'] as num?)?.toInt() ?? 0;
      final days = (_settings?['duration_days'] as num?)?.toInt() ?? 7;
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('نشر في حائط المنتجات'),
          content: Text(gems > 0
              ? 'سيُخصم $gems جوهرة، ويظهر منتجك لمدة $days يومًا.'
              : 'سيُخصم $points نقطة، ويظهر منتجك لمدة $days يومًا.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('متابعة')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _openEditor();
  }

  /// محرّر المنتج.
  ///
  /// كان نموذجًا واحدًا بأحد عشر حقلًا مفتوحًا: SKU يُكتب يدويًّا،
  /// وتاريخا البداية والنهاية نصًّا بصيغة ISO، وترتيب عرض، ومخزون —
  /// كلّها مطلوبة بصريًّا على قدم المساواة مع اسم المنتج وسعره. فمن
  /// يريد عرض ثوبٍ للبيع يواجه استمارة مستودع.
  ///
  /// الآن: ثلاثة أشياء فقط ظاهرة (الاسم، السعر، الصور)، وما بقي تحت
  /// «خيارات متقدّمة» مطويّة. وSKU يُولَّد تلقائيًّا لأن الخادم يطلبه
  /// ولا سبب ليكتبه البائع، والتاريخان بمنتقي تاريخ لا بنصّ ISO.
  Future<void> _openEditor([Map<String, dynamic>? product]) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final sku = TextEditingController(text: product?['sku']?.toString() ?? '');
    final details =
        TextEditingController(text: product?['details']?.toString() ?? '');
    final description =
        TextEditingController(text: product?['description']?.toString() ?? '');
    final quantity = TextEditingController(text: '${product?['quantity'] ?? 1}');
    // المنتج سلعة حقيقية (ثوب، قماش...)، لا يُسعَّر بالذهب أو النقاط
    // الداخلية — سعر القطعة بالدولار و/أو الليرة السورية.
    final priceUsd =
        TextEditingController(text: '${product?['price_usd'] ?? ''}');
    final priceSyp =
        TextEditingController(text: '${product?['price_syp'] ?? ''}');
    final images = <_PickedImage>[
      for (final u in (product?['image_urls'] is List
          ? List.from(product!['image_urls'])
          : const []))
        _PickedImage.existing(u.toString()),
    ];
    var videoUrl = product?['video_url']?.toString() ?? '';
    final sort = TextEditingController(text: '${product?['sort_order'] ?? 0}');
    DateTime? startsAt =
        DateTime.tryParse('${product?['starts_at'] ?? ''}')?.toLocal();
    DateTime? endsAt =
        DateTime.tryParse('${product?['ends_at'] ?? ''}')?.toLocal();
    bool active = product?['is_active'] != false;
    bool likesOn = product?['likes_enabled'] != false;
    bool commentsOn = product?['comments_enabled'] != false;
    bool saving = false;
    bool busyMedia = false;
    bool advanced = false;

    String fmt(DateTime? d) => d == null
        ? 'غير محدّد'
        : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> addImage() async {
            final picked = await ImagePicker()
                .pickImage(source: ImageSource.gallery, imageQuality: 92);
            if (picked == null) return;
            setDialogState(() => busyMedia = true);
            try {
              var bytes = await picked.readAsBytes();
              if (!context.mounted) return;
              // الفلاتر التجميلية تُطبَّق قبل الرفع، فما يُخزَّن هو
              // الصورة كما اختارها صاحبها لا الأصل الخام.
              final edited = await FilteredImagePicker.edit(context, bytes,
                  title: 'تجميل صورة المنتج');
              if (edited != null) bytes = edited;
              setDialogState(
                  () => images.add(_PickedImage.local(bytes, picked.name)));
            } finally {
              setDialogState(() => busyMedia = false);
            }
          }

          Future<void> pickVideo() async {
            final picked =
                await ImagePicker().pickVideo(source: ImageSource.gallery);
            if (picked == null) return;
            setDialogState(() => busyMedia = true);
            try {
              final uid = Supabase.instance.client.auth.currentUser!.id;
              final url = await MediaUploadService(bucket: 'media').uploadBytes(
                bytes: await picked.readAsBytes(),
                fileName: picked.name,
                folder: 'wall/products',
                uid: uid,
              );
              setDialogState(() => videoUrl = url);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBarSfx(SnackBar(content: Text(FailureText.of(e))));
              }
            } finally {
              setDialogState(() => busyMedia = false);
            }
          }

          return AlertDialog(
            title: Text(product == null ? 'منتج جديد' : 'تعديل المنتج'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ما تبيعه',
                        hintText: 'مثال: قميص قطن رجالي',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: priceUsd,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'بالدولار',
                              prefixText: '\$ ',
                              hintText: '0'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceSyp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'بالليرة', suffixText: 'ل.س'),
                        ),
                      ),
                    ]),
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('اكتب سعرًا واحدًا على الأقل',
                          style: TextStyle(fontSize: 11, color: Colors.white54)),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('الصور (${images.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var i = 0; i < images.length; i++)
                        Stack(clipBehavior: Clip.none, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: images[i].bytes != null
                                  ? Image.memory(images[i].bytes!,
                                      fit: BoxFit.cover)
                                  : Image.network(images[i].url!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(color: Colors.white10)),
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () =>
                                  setDialogState(() => images.removeAt(i)),
                              child: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(Icons.close,
                                      size: 13, color: Colors.white)),
                            ),
                          ),
                        ]),
                      if (images.length < 12)
                        InkWell(
                          onTap: busyMedia ? null : addImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.white30),
                                borderRadius: BorderRadius.circular(10)),
                            child: busyMedia
                                ? const Padding(
                                    padding: EdgeInsets.all(22),
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_a_photo_outlined,
                                    color: Colors.white54),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busyMedia ? null : pickVideo,
                          icon: Icon(videoUrl.isEmpty
                              ? Icons.videocam_outlined
                              : Icons.check_circle_rounded),
                          label: Text(videoUrl.isEmpty
                              ? 'فيديو (اختياري)'
                              : 'فيديو مرفوع'),
                        ),
                      ),
                      if (videoUrl.isNotEmpty)
                        IconButton(
                          tooltip: 'إزالة الفيديو',
                          onPressed: () => setDialogState(() => videoUrl = ''),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    // كل ما لا يحتاجه بائعٌ عادي يُطوى هنا؛ القيم
                    // الافتراضية صالحة للنشر دون فتحه إطلاقًا.
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: advanced,
                        onExpansionChanged: (v) =>
                            setDialogState(() => advanced = v),
                        title: const Text('خيارات متقدّمة',
                            style: TextStyle(fontSize: 13)),
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          TextField(
                              controller: details,
                              decoration: const InputDecoration(
                                  labelText: 'سطر تفاصيل قصير')),
                          TextField(
                              controller: description,
                              maxLines: 3,
                              decoration:
                                  const InputDecoration(labelText: 'الوصف')),
                          TextField(
                              controller: quantity,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'الكمية المتوفّرة')),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: startsAt ?? DateTime.now(),
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 1)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 730)),
                                  );
                                  if (d != null) {
                                    setDialogState(() => startsAt = d);
                                  }
                                },
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: Text('يبدأ: ${fmt(startsAt)}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: endsAt ??
                                        DateTime.now()
                                            .add(const Duration(days: 7)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 730)),
                                  );
                                  if (d != null) setDialogState(() => endsAt = d);
                                },
                                icon: const Icon(Icons.stop_rounded, size: 18),
                                label: Text('ينتهي: ${fmt(endsAt)}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ]),
                          if (startsAt != null || endsAt != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: () => setDialogState(() {
                                  startsAt = null;
                                  endsAt = null;
                                }),
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                label: const Text('بلا توقيت',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          TextField(
                              controller: sort,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'ترتيب العرض')),
                          TextField(
                              controller: sku,
                              decoration: const InputDecoration(
                                  labelText: 'رمز المنتج SKU',
                                  hintText: 'يُولَّد تلقائيًّا إن تُرك فارغًا')),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: active,
                              onChanged: (v) =>
                                  setDialogState(() => active = v),
                              title: const Text('منشور ونشط')),
                          if (product != null) ...[
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: likesOn,
                                onChanged: (v) =>
                                    setDialogState(() => likesOn = v),
                                title: const Text('التفاعلات مفعّلة')),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: commentsOn,
                                onChanged: (v) =>
                                    setDialogState(() => commentsOn = v),
                                title: const Text('التعليقات مفعّلة')),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء')),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final usd = double.tryParse(priceUsd.text.trim().isEmpty
                                ? '0'
                                : priceUsd.text.trim()) ??
                            -1;
                        final syp = int.tryParse(priceSyp.text.trim().isEmpty
                                ? '0'
                                : priceSyp.text.trim()) ??
                            -1;
                        if (name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBarSfx(
                              const SnackBar(
                                  content: Text('اكتب اسم المنتج.')));
                          return;
                        }
                        if (usd < 0 || syp < 0 || (usd <= 0 && syp <= 0)) {
                          ScaffoldMessenger.of(context).showSnackBarSfx(
                              const SnackBar(
                                  content: Text(
                                      'اكتب سعرًا صحيحًا بالدولار أو بالليرة.')));
                          return;
                        }
                        if (images.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBarSfx(
                              const SnackBar(
                                  content: Text(
                                      'أضف صورة واحدة على الأقل من الهاتف.')));
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          final uid =
                              Supabase.instance.client.auth.currentUser!.id;
                          final urls = <String>[];
                          for (final img in images) {
                            if (img.url != null) {
                              urls.add(img.url!);
                            } else {
                              urls.add(await MediaUploadService(bucket: 'media')
                                  .uploadBytes(
                                bytes: img.bytes!,
                                fileName: img.name ?? 'product.jpg',
                                folder: 'wall/products',
                                uid: uid,
                              ));
                            }
                          }
                          // SKU مطلوب خادميًّا؛ لا سبب ليكتبه البائع.
                          var skuText = sku.text.trim();
                          if (skuText.isEmpty) {
                            skuText = 'P${DateTime.now().millisecondsSinceEpoch}';
                          }
                          final params = {
                            if (product != null) 'p_id': product['id'],
                            'p_name': name.text.trim(),
                            'p_sku': skuText,
                            'p_details': details.text.trim(),
                            'p_description': description.text.trim(),
                            'p_quantity':
                                int.tryParse(quantity.text.trim()) ?? 1,
                            'p_price_usd': usd,
                            'p_price_syp': syp,
                            'p_image_urls': urls,
                            'p_video_url': videoUrl,
                            'p_starts_at': startsAt?.toUtc().toIso8601String(),
                            'p_ends_at': endsAt?.toUtc().toIso8601String(),
                            'p_is_active': active,
                            'p_sort_order':
                                int.tryParse(sort.text.trim()) ?? 0,
                            if (product != null) 'p_likes_enabled': likesOn,
                            if (product != null)
                              'p_comments_enabled': commentsOn,
                          };
                          if (product == null) {
                            await Supabase.instance.client.rpc(
                                'platform_wall_create_product', params: params);
                          } else {
                            await Supabase.instance.client.rpc(
                                'platform_wall_update_product', params: params);
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBarSfx(
                              SnackBar(content: Text(FailureText.of(e))));
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: Text(saving ? 'جارٍ الحفظ' : 'حفظ'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    sku.dispose();
    details.dispose();
    description.dispose();
    quantity.dispose();
    priceUsd.dispose();
    priceSyp.dispose();
    sort.dispose();
    if (saved == true && mounted) ref.invalidate(platformWallProductsProvider);
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('سيتم حذف «${product['name'] ?? 'منتج'}» نهائيًا من الحائط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc('platform_wall_delete_product', params: {'p_id': product['id']});
      if (mounted) ref.invalidate(platformWallProductsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content: Text(FailureText.of(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حائط المنتجات'),
        centerTitle: true,
        actions: [
          if (_isPlatformOwner)
            IconButton(tooltip: 'إدارة الحائط', onPressed: _manageAccess, icon: const Icon(Icons.admin_panel_settings_rounded)),
          if (_canPost) IconButton(tooltip: 'إضافة منتج', onPressed: () => _confirmThenOpenEditor(), icon: const Icon(Icons.add_business_rounded)),
          IconButton(tooltip: 'تحديث', onPressed: () => ref.invalidate(platformWallProductsProvider), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ref.watch(platformWallProductsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _StateMessage(
              title: 'تعذر تحميل حائط المنتجات',
              details: e.toString(),
              icon: Icons.cloud_off_rounded,
            ),
            data: (products) {
              if (products.isEmpty) {
                return const _StateMessage(
                  title: 'لا توجد منتجات منشورة حاليًا',
                  details:
                      'المنتجات المنشورة من مالك المنصة ستظهر هنا تلقائيًا.',
                  icon: Icons.storefront_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(platformWallProductsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _ProductCard(product: products[i], isOwner: _isPlatformOwner, onEdit: () => _openEditor(products[i]), onDelete: () => _deleteProduct(products[i])),
                ),
              );
            },
          ),
    );
  }
}

class _ProductCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _ProductCard({required this.product, this.isOwner = false, this.onEdit, this.onDelete});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  final _client = Supabase.instance.client;

  String get _id => widget.product['id']?.toString() ?? '';
  String get _name => widget.product['name']?.toString() ?? 'منتج';
  String get _details => widget.product['details']?.toString() ?? '';
  String get _description => widget.product['description']?.toString() ?? '';
  // سعر حقيقي (قطعة من القماش، ثوب...) بالدولار و/أو الليرة، لا بعملة
  // المنصة الداخلية — لا معنى لشراء سلعة حقيقية بالجواهر.
  String get _currencyLabel {
    final usd = double.tryParse('${widget.product['price_usd'] ?? 0}') ?? 0;
    final syp = int.tryParse('${widget.product['price_syp'] ?? 0}') ?? 0;
    if (usd > 0 && syp > 0) return '\$${usd.toStringAsFixed(2)} • $syp ل.س';
    if (syp > 0) return '$syp ل.س';
    return '\$${usd.toStringAsFixed(2)}';
  }

  // العدّ والإعجاب والتعليق كانت ثلاث دوال محلّية تقرأ الجدولين مباشرة
  // وتزيد عدّادًا في الذاكرة بتفاؤل؛ صارت كلّها في ContentInteractionBar
  // التي تقرأ من الخادم وتكتب فيه، فينضمّ المنتج إلى نفس محرّك
  // التفاعلات والتعليقات الجاهزة والمشاركة الذي تستعمله الإعلانات.

  Future<void> _contactSeller() async {
    final myUid = _client.auth.currentUser?.id;
    final sellerUid = widget.product['owner_id']?.toString();
    if (myUid == null || sellerUid == null || sellerUid.isEmpty) return;
    if (myUid == sellerUid) return;
    final sorted = [myUid, sellerUid]..sort();
    openPrivateChat(
      context,
      ref,
      threadId: '${sorted[0]}_${sorted[1]}',
      peerUid: sellerUid,
      peerName: 'صاحب المنتج',
    );
  }

  /// الصور ثم الفيديو في قائمة واحدة، فالعارض يتنقّل بينها بالسحب.
  List<String> _viewerItems() {
    final v = widget.product['video_url']?.toString() ?? '';
    return [..._images(), if (v.isNotEmpty) v];
  }

  List<String> _images() {
    final raw = widget.product['image_urls'];
    if (raw is List) {
      return raw.whereType<String>().where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final images = _images();
    final quantity = int.tryParse('${widget.product['quantity'] ?? 0}') ?? 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // الضغط على الصورة كان لا يفعل شيئًا: تُعرض مقصوصة في ١٩٠
          // بكسل ولا طريق لرؤية التفاصيل. الآن تُفتح بالحجم الكامل مع
          // التكبير والتحميل والمشاركة، والفيديو معها في نفس العارض.
          if (images.isNotEmpty)
            Stack(children: [
              GestureDetector(
                onTap: () => MediaViewer.open(context,
                    items: _viewerItems(), title: _name),
                child: _AnimatedProductHero(images: images, title: _name),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_full_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('اضغط للعرض الكامل',
                          style: TextStyle(fontSize: 10, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
            ])
          else
            Container(
                height: 190,
                color: p.surfaceHighlight,
                child: const Icon(Icons.inventory_2_outlined, size: 50)),
          if ((widget.product['video_url']?.toString().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: EmbeddedMediaPlayer(
                  url: widget.product['video_url'].toString()),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // اسم البائع — بنفس مكوّن الغرف (ألوان وشارات وتأثيرات ما
              // اشتراه)؛ لم يكن يُعرض إطلاقًا رغم أن حائط المنتجات عرض
              // بضائع أشخاص حقيقيين لا جهة واحدة.
              if ((widget.product['owner_id']?.toString() ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ServerUsernameDisplay(
                    uid: widget.product['owner_id'].toString(),
                    fallbackName: 'عضو',
                    fallbackFontSize: 12,
                    showBadges: true,
                    compactBadges: true,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(_name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  ),
                  if (widget.isOwner) ...[
                    IconButton(tooltip: 'تعديل', onPressed: widget.onEdit, icon: const Icon(Icons.edit_rounded, size: 20)),
                    IconButton(tooltip: 'حذف', onPressed: widget.onDelete, icon: const Icon(Icons.delete_forever_rounded, size: 20)),
                  ],
                ],
              ),
              if (_details.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(_details, style: TextStyle(color: p.textSecondary))
              ],
              if (_description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(_description, maxLines: 4, overflow: TextOverflow.ellipsis)
              ],
              const SizedBox(height: 10),
              Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(_currencyLabel)),
                    if (quantity > 0) Chip(label: Text('المتوفر: $quantity')),
                    if (widget.product['starts_at'] != null ||
                        widget.product['ends_at'] != null)
                      _ExpiryChip(
                        startsAt: DateTime.tryParse('${widget.product['starts_at'] ?? ''}'),
                        endsAt: DateTime.tryParse('${widget.product['ends_at'] ?? ''}'),
                      ),
                  ]),
              const SizedBox(height: 4),
              // مفتاحا المالك (التفاعلات/التعليقات) يُحترمان: إن أطفأ
              // أحدهما فلا يُبنى الشريط لهذا المنتج.
              if (widget.product['likes_enabled'] != false ||
                  widget.product['comments_enabled'] != false)
                ContentInteractionBar(
                  // 'wall_product' لا 'product': الخادم يرفض ما عداه
                  // (ad / wall_product / showcase) بـINVALID_TARGET_TYPE.
                  targetType: 'wall_product',
                  targetId: _id,
                  shareText: '$_name — $_currencyLabel',
                ),
              // "isOwner" هنا تعني مالك المنصة لا بائع هذا المنتج تحديدًا؛
              // زر التواصل يُخفى فقط عمّن يبيع هذا المنتج هو نفسه.
              if (_client.auth.currentUser?.id !=
                  widget.product['owner_id']?.toString())
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                      onPressed: _contactSeller,
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('تواصل مع البائع')),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}


class _AnimatedProductHero extends StatefulWidget {
  final List<String> images;
  final String title;
  const _AnimatedProductHero({required this.images, required this.title});
  @override
  State<_AnimatedProductHero> createState() => _AnimatedProductHeroState();
}

class _AnimatedProductHeroState extends State<_AnimatedProductHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: PageView.builder(
        itemCount: widget.images.length,
        itemBuilder: (_, i) => AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.0 + _controller.value * .018,
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 42),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha:.70), Colors.transparent],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 12,
                left: 14,
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                    const Icon(Icons.swipe_rounded, color: Colors.white70, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  final DateTime? startsAt;
  final DateTime? endsAt;
  const _ExpiryChip({this.startsAt, this.endsAt});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (startsAt != null && startsAt!.isAfter(now)) {
      return Chip(avatar: const Icon(Icons.schedule, size: 16), label: Text('يبدأ خلال ${_label(startsAt!.difference(now))}'));
    }
    if (endsAt == null) return const SizedBox.shrink();
    final diff = endsAt!.difference(now);
    if (diff.isNegative) return const Chip(label: Text('منتهٍ'));
    return Chip(avatar: const Icon(Icons.timer_outlined, size: 16), label: Text('ينتهي خلال ${_label(diff)}'));
  }
  String _label(Duration d) {
    if (d.inDays > 0) return '${d.inDays} يوم';
    if (d.inHours > 0) return '${d.inHours} ساعة';
    return '${math.max(1, d.inMinutes)} دقيقة';
  }
}

class _StateMessage extends StatelessWidget {
  final String title;
  final String details;
  final IconData icon;
  const _StateMessage(
      {required this.title, required this.details, required this.icon});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(details,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
}
