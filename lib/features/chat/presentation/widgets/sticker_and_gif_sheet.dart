import 'package:flutter/material.dart';

import '../../data/gif_catalog.dart';
import 'emoji_picker_sheet.dart';

/// لوحة "السمايل" الموحَّدة: الثابت (إيموجي) والمتحرك (GIF) معًا في قسم
/// واحد، كل نوع بتبويبه المستقل بداخله — بدل ظهور كل واحد منفصلاً بزر
/// وورقة خاصة به. مُشتركة بين الغرفة العامة والخاص معًا، فالسلوك متطابق
/// في الاثنين.
class StickerAndGifSheet extends StatelessWidget {
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<String> onGifSelected;

  const StickerAndGifSheet({
    super.key,
    required this.onEmojiSelected,
    required this.onGifSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onEmojiSelected,
    required ValueChanged<String> onGifSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171126),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: StickerAndGifSheet(
          onEmojiSelected: onEmojiSelected,
          onGifSelected: onGifSelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              indicatorColor: Color(0xFFFFD700),
              labelColor: Color(0xFFFFD700),
              unselectedLabelColor: Colors.white38,
              tabs: [
                Tab(icon: Icon(Icons.emoji_emotions_outlined), text: 'إيموجي'),
                Tab(icon: Icon(Icons.gif_box_outlined), text: 'GIF'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  EmojiPickerContent(onSelect: onEmojiSelected),
                  _GifTabContent(onSelected: onGifSelected),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GifTabContent extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _GifTabContent({required this.onSelected});

  Widget _tile(BuildContext context, String path, {required bool wide}) {
    return Tooltip(
      message: mashareenaChatGifNames[path] ?? '',
      triggerMode: mashareenaChatGifNames.containsKey(path)
          ? TooltipTriggerMode.longPress
          : TooltipTriggerMode.manual,
      child: GestureDetector(
        // يُغلق الورقة بسياقه الخاص (سليل حقيقي للورقة دائمًا وقت الضغط).
        onTap: () {
          Navigator.of(context).pop();
          onSelected(path);
        },
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
