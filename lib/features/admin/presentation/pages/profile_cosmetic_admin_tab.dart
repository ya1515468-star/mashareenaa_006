import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileCosmeticAdminTab extends StatefulWidget { const ProfileCosmeticAdminTab({super.key}); @override State<ProfileCosmeticAdminTab> createState()=>_ProfileCosmeticAdminTabState(); }
class _ProfileCosmeticAdminTabState extends State<ProfileCosmeticAdminTab>{
  late Future<List<Map<String,dynamic>>> _future=_load();
  Future<List<Map<String,dynamic>>> _load() async { final rows=await Supabase.instance.client.rpc('get_profile_cosmetic_catalog',params:{}); return List<Map<String,dynamic>>.from(rows as List); }
  Future<void> _edit(Map<String,dynamic> item) async {
    final points=TextEditingController(text:'${item['price_points']}'); final gems=TextEditingController(text:'${item['price_gems']}');
    try {
      final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(item['name_ar'].toString()),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:points,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر النقاط')),TextField(controller:gems,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر الجواهر'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حفظ'))]));
      if(ok!=true || !mounted)return;
      try{ await Supabase.instance.client.rpc('update_profile_cosmetic_price',params:{'p_item_key':item['item_key'],'p_price_points':int.tryParse(points.text)??0,'p_price_gems':int.tryParse(gems.text)??0,'p_is_active':true}); if(mounted){setState(()=>_future=_load());ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تحديث السعر')));}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر تحديث السعر الآن. حاول مرة أخرى.')));}
    } finally {
      points.dispose();
      gems.dispose();
    }
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:_future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator()); if(s.hasError)return const Center(child:Text('تعذر تحميل عناصر متجر الشات الآن. تحقق من الاتصال ثم أعد المحاولة.')); final items=s.data??const[]; return ListView.builder(itemCount:items.length,itemBuilder:(c,i){final x=items[i]; return ListTile(title:Text(x['name_ar']?.toString() ?? 'عنصر متجر'),subtitle:Text('${x['category']} • ${x['price_points']} نقطة • ${x['price_gems']} جوهرة'),trailing:IconButton(icon:const Icon(Icons.edit),onPressed:()=>_edit(x)));});});
}
