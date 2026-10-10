import 'package:flutter/material.dart';
import '../../../../core/services/snack_sfx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/dynamic_avatar_frame.dart';
import '../../../rbac/presentation/widgets/server_user_identity_badges.dart';
import '../providers/profile_provider.dart';
import 'avatar_frame_catalog.dart';

final availableAvatarFramesProvider = FutureProvider.autoDispose<List<AvatarFrameDefinition>>((ref) async {
  final raw = await Supabase.instance.client.rpc('get_avatar_frame_catalog');
  final rows = raw is List ? raw : const <dynamic>[];
  return rows.whereType<Map>().map((m) => AvatarFrameDefinition.fromMap(Map<String,dynamic>.from(m))).where((f)=>f.key.isNotEmpty && f.assetUrl != null).toList(growable:false);
});

class AvatarFramePickerSheet extends ConsumerWidget {
  final String uid;
  const AvatarFramePickerSheet({super.key, required this.uid});

  static Future<void> show(BuildContext context, String uid) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarFramePickerSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentProfileProvider).valueOrNull?.avatarFrameKey;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        decoration: const BoxDecoration(color: Color(0xFF10131B),borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ref.watch(availableAvatarFramesProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24),child: Text('تعذر تحميل إطارات الخادم: $e'))),
          data: (frames) {
            if (frames.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(28),child: Text('لا توجد إطارات متاحة حاليًا.',textAlign: TextAlign.center,style: TextStyle(fontWeight: FontWeight.w800,color: Colors.white70))));
            }
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(width:42,height:4,decoration:BoxDecoration(color:Colors.white24,borderRadius:BorderRadius.circular(8))),
                const SizedBox(height: 10),
                const Text('إطارات من الخادم',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
                const SizedBox(height: 8),
                const Padding(padding:EdgeInsets.symmetric(horizontal:18),child:Text('الإطار يُعرض فوق الصورة من الملف المخزن في Supabase، سواء كان ثابتًا أو متحركًا.',style:TextStyle(color:Colors.white60,fontSize:11),textAlign:TextAlign.center)),
                const SizedBox(height: 10),
                Expanded(child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:.9),
                  itemCount: frames.length,
                  itemBuilder: (_,i){
                    final f=frames[i];
                    final selected=f.key==current;
                    final unlocked=f.canActivate;
                    return Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
                      Expanded(child:DynamicAvatarFrame(frameKey:f.key,radius:30,child:const CircleAvatar(radius:30,backgroundColor:Color(0xFF2A2535),child:Icon(Icons.person,color:Colors.white54)))),
                      Text(f.nameAr,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800)),
                      const SizedBox(height:5),
                      Text(selected?'مُجهز':(unlocked?'تجهيز':'يتطلب شراء'),style:const TextStyle(fontSize:10,color:Colors.white60)),
                      const SizedBox(height:5),
                      FilledButton(onPressed:unlocked?() async{try{await Supabase.instance.client.rpc('set_avatar_frame',params:{'p_frame_key':f.key});ref.invalidate(currentProfileProvider);ref.invalidate(profileByIdProvider(uid));ref.invalidate(serverUserIdentityProvider);ref.invalidate(serverUserIdentityInRoomProvider);DynamicAvatarFrame.invalidateVisualSizeCache(uid);if(context.mounted){Navigator.pop(context);ScaffoldMessenger.of(context).showSnackBarSfx(const SnackBar(content:Text('تم تجهيز الإطار ✓')));}}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBarSfx(SnackBar(content:Text('فشل تجهيز الإطار: $e')));}}:null,child:Text(selected?'مُجهز':'تجهيز')),
                    ])));
                  },
                )),
              ],
            );
          },
        ),
      ),
    );
  }
}
