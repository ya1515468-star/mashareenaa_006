import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

final dragonStoreItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('store_items')
      .select(
          'id,code,name,is_active,store_item_prices(currency,amount,is_active)')
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows);
});

final dragonMembershipTiersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('app_documents')
      .select('doc_id,data,updated_at')
      .eq('collection_path', 'subscription_tiers')
      .order('doc_id');
  return List<Map<String, dynamic>>.from(rows);
});

final dragonMembershipOwnerProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await Supabase.instance.client.rpc('is_my_platform_owner') == true;
  } catch (_) {
    return false;
  }
});

final dragonVipServicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('profile_service_catalog')
      .select('feature_key,name_ar,description_ar,is_active,sort_order,price_points,price_gems')
      .order('sort_order');
  return List<Map<String, dynamic>>.from(rows);
});

final dragonTierRulesProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
        (ref, tierId) async {
  final rows = await Supabase.instance.client.rpc(
    'admin_get_membership_service_rules',
    params: {'p_tier_id': tierId},
  );
  return List<Map<String, dynamic>>.from(rows as List);
});

class DragonControlTab extends ConsumerWidget {
  const DragonControlTab({super.key});

  Future<void> _saveStore(BuildContext context, Map<String, dynamic> row,
      WidgetRef ref) async {
    final prices =
        List<Map<String, dynamic>>.from(row['store_item_prices'] ?? const []);
    int points = 0, gems = 0;
    for (final p in prices) {
      if (p['currency'] == 'points') {
        points = (p['amount'] as num?)?.toInt() ?? 0;
      }
      if (p['currency'] == 'gems') gems = (p['amount'] as num?)?.toInt() ?? 0;
    }
    final result = await showDialog<(int, int, bool)>(
      context: context,
      builder: (_) => _StoreDialog(
        name: row['name']?.toString() ?? row['code']?.toString() ?? '',
        points: points,
        gems: gems,
        enabled: row['is_active'] == true,
      ),
    );
    if (result == null) return;
    try {
      await Supabase.instance.client.rpc('dragon_update_store_item', params: {
        'p_item_id': row['id'],
        'p_price_points': result.$1,
        'p_price_gems': result.$2,
        'p_enabled': result.$3,
      });
      ref.invalidate(dragonStoreItemsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(
            const SnackBar(content: Text('تم حفظ العنصر على الخادم')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }

  Future<void> _editTier(BuildContext context,
      {Map<String, dynamic>? row, required WidgetRef ref}) async {
    final data = row?['data'] is Map
        ? Map<String, dynamic>.from(row!['data'] as Map)
        : <String, dynamic>{};
    final initialId = row?['doc_id']?.toString() ?? '';
    final result = await showDialog<_TierEditorResult>(
      context: context,
      builder: (_) => _TierEditorDialog(
        id: initialId,
        name: data['name']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        priceMinor: (data['priceMinorUnits'] as num?)?.toInt() ?? 0,
        durationDays: (data['durationDays'] as num?)?.toInt() ?? 30,
        enabled: data['enabled'] != false,
        displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 100,
        trial: data['trial'] == true,
        trialDays: (data['trialDays'] as num?)?.toInt() ?? 0,
        autoRenew: data['autoRenew'] == true,
        level: (data['level'] as num?)?.toInt() ?? 1,
        unlockedServiceCount:
            (data['unlockedServiceCount'] as num?)?.toInt() ?? 0,
        pointsGranted: (data['pointsGranted'] as num?)?.toInt() ?? 0,
        gemsGranted: (data['gemsGranted'] as num?)?.toInt() ?? 0,
        grantedCosmeticKeys: ((data['grantedCosmeticKeys'] as List?) ?? const [])
            .map((e) => e.toString())
            .join(', '),
        grantedAnimationKeys: ((data['grantedAnimationKeys'] as List?) ?? const [])
            .map((e) => e.toString())
            .join(', '),
      ),
    );
    if (result == null) return;
    try {
      await Supabase.instance.client.rpc('admin_upsert_membership_tier',
          params: result.toRpcParams());
      ref.invalidate(dragonMembershipTiersProvider);
      ref.invalidate(dragonTierRulesProvider(result.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(
            content: Text('تم حفظ خطة العضوية على الخادم')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBarSfx(SnackBar(content: Text('فشل حفظ الخطة: $e')));
      }
    }
  }

  Future<void> _editTierRules(BuildContext context, String tierId,
      WidgetRef ref) async {
    final services = await ref.read(dragonVipServicesProvider.future);
    final currentRules = await ref.read(dragonTierRulesProvider(tierId).future);
    final byKey = <String, Map<String, dynamic>>{
      for (final rule in currentRules) rule['feature_key'].toString(): rule,
    };
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _TierRulesDialog(
        tierId: tierId,
        services: services,
        existing: byKey,
      ),
    );
    ref.invalidate(dragonTierRulesProvider(tierId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final items = ref.watch(dragonStoreItemsProvider);
    final tiers = ref.watch(dragonMembershipTiersProvider);
    final owner = ref.watch(dragonMembershipOwnerProvider).valueOrNull == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.shield, color: Colors.amber),
            title: Text('DRAGON / Platform Owner',
                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text(
              owner
                  ? 'صلاحيات الإدارة مؤكدة من الخادم: مالك المنصة فقط.'
                  : 'هذه الشاشة للعرض فقط حتى يؤكد الخادم صلاحية المالك.',
              style: TextStyle(color: p.textSecondary),
            ),
            trailing: owner
                ? FilledButton.icon(
                    onPressed: () => _editTier(context, ref: ref),
                    icon: const Icon(Icons.add),
                    label: const Text('عضوية جديدة'),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text('العضويات المدفوعة — المصدر الخادمي',
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold)),
        tiers.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('تعذر تحميل العضويات: $e'),
          data: (rows) => Column(
            children: [
              for (final row in rows)
                Builder(builder: (_) {
                  final rawData = row['data'];
                  final data = rawData is Map
                      ? Map<String, dynamic>.from(rawData)
                      : <String, dynamic>{};
                  final id = row['doc_id']?.toString() ?? '';
                  final price = (data['priceMinorUnits'] as num?)?.toInt() ?? 0;
                  final enabled = data['enabled'] != false;
                  return Card(
                    child: ListTile(
                      title: Text(data['name']?.toString() ?? id),
                      subtitle: Text(
                          '$id • $price minorUnits • ${enabled ? 'مفعلة' : 'متوقفة'} • ${data['durationDays'] ?? 30} يوم'),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'تعديل الخطة',
                            onPressed: owner
                                ? () => _editTier(context, row: row, ref: ref)
                                : null,
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: 'إدارة خدمات VIP',
                            onPressed: owner
                                ? () => _editTierRules(context, id, ref)
                                : null,
                            icon: const Icon(Icons.apps),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('عناصر المتجر',
            style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold)),
        items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('تعذر تحميل المتجر: $e'),
          data: (rows) => Column(
            children: [
              for (final row in rows.take(100))
                Card(
                  child: ListTile(
                    title: Text(row['name']?.toString() ?? row['code']?.toString() ?? '-'),
                    subtitle: Text(row['code']?.toString() ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: owner ? () => _saveStore(context, row, ref) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TierEditorResult {
  final String id, name, description;
  final int priceMinor, durationDays, displayOrder, trialDays, level;
  final bool enabled, trial, autoRenew;
  final int unlockedServiceCount;
  final int pointsGranted, gemsGranted;
  final String grantedCosmeticKeys, grantedAnimationKeys;

  const _TierEditorResult({required this.id, required this.name, required this.description,
    required this.priceMinor, required this.durationDays, required this.enabled,
    required this.displayOrder, required this.trial, required this.trialDays,
    required this.autoRenew, required this.level, required this.unlockedServiceCount,
    required this.pointsGranted, required this.gemsGranted,
    required this.grantedCosmeticKeys, required this.grantedAnimationKeys});

  static List<String> _splitKeys(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Map<String, dynamic> toRpcParams() => {
        'p_tier_id': id.trim(),
        'p_name': name.trim(),
        'p_description': description.trim(),
        'p_price_minor_units': priceMinor,
        'p_currency': 'sham_cash',
        'p_duration_days': durationDays,
        'p_enabled': enabled,
        'p_display_order': displayOrder,
        'p_trial': trial,
        'p_trial_days': trialDays,
        'p_auto_renew': autoRenew,
        'p_level': level,
        'p_unlocked_service_count': unlockedServiceCount,
        'p_points_granted': pointsGranted,
        'p_gems_granted': gemsGranted,
        'p_granted_cosmetic_keys': _splitKeys(grantedCosmeticKeys),
        'p_granted_animation_keys': _splitKeys(grantedAnimationKeys),
      };
}

class _TierEditorDialog extends StatefulWidget {
  final String id, name, description;
  final int priceMinor, durationDays, displayOrder, trialDays, level,
      unlockedServiceCount;
  final bool enabled, trial, autoRenew;
  final int pointsGranted, gemsGranted;
  final String grantedCosmeticKeys, grantedAnimationKeys;
  const _TierEditorDialog({required this.id, required this.name, required this.description,
    required this.priceMinor, required this.durationDays, required this.enabled,
    required this.displayOrder, required this.trial, required this.trialDays,
    required this.autoRenew, required this.level, required this.unlockedServiceCount,
    required this.pointsGranted, required this.gemsGranted,
    required this.grantedCosmeticKeys, required this.grantedAnimationKeys});
  @override State<_TierEditorDialog> createState() => _TierEditorDialogState();
}
class _TierEditorDialogState extends State<_TierEditorDialog> {
  late final id=TextEditingController(text: widget.id), name=TextEditingController(text: widget.name),
      description=TextEditingController(text: widget.description), price=TextEditingController(text: widget.priceMinor.toString()),
      duration=TextEditingController(text: widget.durationDays.toString()), order=TextEditingController(text: widget.displayOrder.toString()),
      trialDays=TextEditingController(text: widget.trialDays.toString()), level=TextEditingController(text: widget.level.toString()),
      count=TextEditingController(text: widget.unlockedServiceCount.toString()),
      pointsGranted=TextEditingController(text: widget.pointsGranted.toString()), gemsGranted=TextEditingController(text: widget.gemsGranted.toString()),
      cosmeticKeys=TextEditingController(text: widget.grantedCosmeticKeys), animationKeys=TextEditingController(text: widget.grantedAnimationKeys);
  late bool enabled=widget.enabled, trial=widget.trial, autoRenew=widget.autoRenew;
  @override void dispose(){for(final c in [id,name,description,price,duration,order,trialDays,level,count,pointsGranted,gemsGranted,cosmeticKeys,animationKeys]){c.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
    title: Text(widget.id.isEmpty?'إنشاء عضوية':'تعديل ${widget.name}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
      TextField(controller:id,enabled:widget.id.isEmpty,decoration:const InputDecoration(labelText:'معرّف الخطة (a-z, 0-9, _)')),
      TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),
      TextField(controller:description,decoration:const InputDecoration(labelText:'الوصف')),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر minorUnits')),
      TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المدة بالأيام')),
      TextField(controller:order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'ترتيب العرض')),
      TextField(controller:level,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'مستوى العضوية')),
      TextField(controller:count,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'عدد خدمات VIP الافتراضية (0-36)')),
      const Padding(padding: EdgeInsets.only(top: 10, bottom: 4), child: Align(alignment: Alignment.centerRight, child: Text('يُمنح مرة واحدة عند كل عملية شراء (منفصل عن خدمات VIP أعلاه):', style: TextStyle(fontSize: 12, color: Colors.white60)))),
      TextField(controller:pointsGranted,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'نقاط تُمنح عند الشراء')),
      TextField(controller:gemsGranted,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'جواهر تُمنح عند الشراء')),
      TextField(controller:cosmeticKeys,decoration:const InputDecoration(labelText:'مفاتيح عناصر تجميلية تُمنح (مفصولة بفاصلة)')),
      TextField(controller:animationKeys,decoration:const InputDecoration(labelText:'مفاتيح حيوانات اسم تُمنح (مفصولة بفاصلة)')),
      SwitchListTile(value:enabled,onChanged:(v)=>setState(()=>enabled=v),title:const Text('مفعلة')),
      SwitchListTile(value:trial,onChanged:(v)=>setState(()=>trial=v),title:const Text('تجريبية')),
      if(trial) TextField(controller:trialDays,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'أيام التجربة')),
      SwitchListTile(value:autoRenew,onChanged:(v)=>setState(()=>autoRenew=v),title:const Text('تجديد تلقائي')),
    ])),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:(){final x=_TierEditorResult(id:id.text,name:name.text,description:description.text,priceMinor:int.tryParse(price.text)??-1,durationDays:int.tryParse(duration.text)??0,enabled:enabled,displayOrder:int.tryParse(order.text)??0,trial:trial,trialDays:int.tryParse(trialDays.text)??0,autoRenew:autoRenew,level:int.tryParse(level.text)??0,unlockedServiceCount:int.tryParse(count.text)??0,pointsGranted:int.tryParse(pointsGranted.text)??0,gemsGranted:int.tryParse(gemsGranted.text)??0,grantedCosmeticKeys:cosmeticKeys.text,grantedAnimationKeys:animationKeys.text);Navigator.pop(context,x);},child:const Text('حفظ'))],
  );
}

class _TierRulesDialog extends ConsumerStatefulWidget {
  final String tierId;
  final List<Map<String, dynamic>> services;
  final Map<String, Map<String, dynamic>> existing;
  const _TierRulesDialog({required this.tierId,required this.services,required this.existing});
  @override ConsumerState<_TierRulesDialog> createState()=>_TierRulesDialogState();
}
class _TierRulesDialogState extends ConsumerState<_TierRulesDialog>{
  late final Map<String,bool> included={for(final s in widget.services) s['feature_key'].toString(): widget.existing[s['feature_key'].toString()]?['included']==true};
  bool busy=false;
  Future<void> _save() async {if(busy)return;setState(()=>busy=true);try{for(final s in widget.services){final key=s['feature_key'].toString();await Supabase.instance.client.rpc('admin_set_membership_service_rule',params:{'p_tier_id':widget.tierId,'p_feature_key':key,'p_included':included[key]==true,'p_purchase_separately':included[key]!=true,'p_owner_only':widget.existing[key]?['owner_only']==true,'p_vip_only':widget.existing[key]?['vip_only']==true,'p_temporary':widget.existing[key]?['temporary']!=false,'p_event_only':widget.existing[key]?['event_only']==true,'p_duration_days':(widget.existing[key]?['duration_days'] as num?)?.toInt(),'p_enabled':true});}if(mounted)Navigator.pop(context);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content:Text('فشل تحديث الخدمات: $e')));}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text('خدمات ${widget.tierId}'),content:SizedBox(width:420,height:520,child:ListView(children:[for(final s in widget.services)CheckboxListTile(value:included[s['feature_key'].toString()]??false,onChanged:busy?null:(v)=>setState(()=>included[s['feature_key'].toString()]=v==true),title:Text(s['name_ar']?.toString()??s['feature_key'].toString()),subtitle:Text(s['feature_key'].toString()),dense:true)])),actions:[TextButton(onPressed:busy?null:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:busy?null:_save,child:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Text('حفظ'))]);
}

class _StoreDialog extends StatefulWidget {
  final String name; final int points,gems; final bool enabled;
  const _StoreDialog({required this.name,required this.points,required this.gems,required this.enabled});
  @override State<_StoreDialog> createState()=>_StoreDialogState();
}
class _StoreDialogState extends State<_StoreDialog>{late final points=TextEditingController(text:widget.points.toString()),gems=TextEditingController(text:widget.gems.toString());late bool enabled=widget.enabled;@override void dispose(){points.dispose();gems.dispose();super.dispose();}@override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.name),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:points,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Points')),TextField(controller:gems,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Gems')),SwitchListTile(value:enabled,onChanged:(v)=>setState(()=>enabled=v),title:const Text('متاح'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,(int.tryParse(points.text.trim())??0,int.tryParse(gems.text.trim())??0,enabled)),child:const Text('حفظ'))]);}
