import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gif_catalog.dart';
import 'emoji_picker_sheet.dart';

/// السمايل المتحرك الذي يُعنوِن تبويب الـGIF بدل كلمة «GIF» وأيقونة
/// `gif_box_outlined`: وجه غامز بمقاسه الأصلي 20×24 و12 إطارًا ووزن
/// 1.2 كيلوبايت — الأخفّ في الكتالوج كله، وهذا يهمّ لأنه يُرسَم مع كل
/// إعادة بناء للشريط.
const String kStickerTabGif = 'assets/chat/gif_first/smile_wink.gif';

/// لوحة «السمايل» الموحَّدة: الثابت (إيموجي) والمتحرك (GIF) معًا بتبويبين
/// جانب بعض، كل تبويب عنصر واحد بلا تكديس.
///
/// كانت ورقة `showModalBottomSheet` بارتفاع 60% من الشاشة، فتحجب صندوق
/// الكتابة وزر الإرسال — فلم يكن المستخدم يرى ما اختاره ولا يستطيع
/// الإرسال، ولذلك وُجد زر «تم» والعدّاد. الآن لوحة داخلية تجلس أسفل
/// صندوق الكتابة مكان لوحة المفاتيح (نمط واتساب/تليجرام): الحقل وزر
/// السهم ظاهران فوقها دائمًا، فتزول الحاجة إلى أي زر إغلاق — السهم
/// يُرسل ويُغلق، وزر السمايل مفتاح يفتح ويُغلق.
///
/// مشتركة بين الغرفة العامة والخاص معًا، فالسلوك متطابق في الاثنين.
class StickerAndGifPanel extends StatelessWidget {
  /// إيموجي ثابت: يُدرَج حرفًا في صندوق الكتابة عند موضع المؤشر.
  final ValueChanged<String> onEmojiSelected;

  /// سمايل متحرك: يُدرَج رمزًا `[gN]` عند موضع المؤشر — لا يُرسَل فورًا.
  final ValueChanged<String> onGifSelected;

  /// ارتفاع اللوحة. قريب من ارتفاع لوحة مفاتيح الهاتف حتى لا تقفز
  /// الشاشة عند التبديل بينهما.
  final double height;

  const StickerAndGifPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onGifSelected,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(
            top: BorderSide(color: p.divider.withValues(alpha: .75)),
          ),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                indicatorColor: const Color(0xFFFFD700),
                labelColor: const Color(0xFFFFD700),
                unselectedLabelColor: Colors.white38,
                tabs: [
                  const Tab(
                    icon: Icon(Icons.emoji_emotions_outlined),
                    text: 'إيموجي',
                  ),
                  // تبويب عنصر واحد: السمايل المتحرك وحده، بلا كلمة
                  // «GIF» وبلا أيقونة فوقه. `child` لا `icon`+`text` هو
                  // ما يمنع التكديس. والنص المحذوف يُستعاض عنه بوصف
                  // مخفي لقارئ الشاشة فقط.
                  Tab(
                    child: Semantics(
                      label: 'سمايلات متحركة',
                      child: Image.asset(
                        kStickerTabGif,
                        width: 20,
                        height: 24,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.gif_box_outlined,
                            size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // closeOnSelect الافتراضي false: اللوحة تبقى مفتوحة
                    // فيُدرَج إيموجي بعد إيموجي بلا إعادة فتحها.
                    EmojiPickerContent(onSelect: onEmojiSelected),
                    _GifTabContent(onSelected: onGifSelected),
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

class _GifTabContent extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _GifTabContent({required this.onSelected});

  Widget _tile(BuildContext context, String path, {required bool wide}) {
    // كان هنا Tooltip: يبني OverlayPortal، وحين تُغلق اللوحة والبطاقات
    // تُعاد بناءها يختفي الـOverlay فيُرمى "No Overlay widget found"
    // (٢٠ مرة في مراقب الأخطاء). الاسم يبقى متاحًا عبر Semantics بلا
    // أي طبقة Overlay.
    return Semantics(
      label: mashareenaChatGifNames[path] ?? '',
      child: GestureDetector(
        // لا Navigator.pop ولا عدّاد: اللوحة داخلية لا تحجب شيئًا، فهي
        // تبقى مفتوحة ويُدرَج كل اختيار في صندوق الكتابة فورًا.
        onTap: () => onSelected(path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(wide ? 8 : 6),
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            // ملصق فاسد لا يكسر الشبكة كلها.
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined, size: 20, color: Colors.white38),
          ),
        ),
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    if (mashareenaChatGifCatalog.isEmpty && mashareenaChatBannerGifs.isEmpty) {
      return const Center(
        child: Text('لا توجد ملصقات متاحة بعد',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header('سمايلات متحركة')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // خلايا صغيرة بعرض أقصى ثابت (كانت 4 أعمدة تتمدد على الشاشات العريضة).
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 46,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  _tile(context, mashareenaChatGifCatalog[i], wide: false),
              childCount: mashareenaChatGifCatalog.length,
            ),
          ),
        ),
        if (mashareenaChatBannerGifs.isNotEmpty) ...[
          SliverToBoxAdapter(child: _header('ملصقات نصية متحركة')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 3.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) =>
                    _tile(context, mashareenaChatBannerGifs[i], wide: true),
                childCount: mashareenaChatBannerGifs.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
