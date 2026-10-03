import 'package:flutter/material.dart';

/// عارض الصور بملء الشاشة للغرف والخاص: تكبير بالإصبعين، وزر النقاط الثلاث
/// يفتح نفس قائمة الفقاعة (رد، اقتباس، مشاركة، حذف) بعد إغلاق العارض.
///
/// يُفتح كمسار معتم على الـNavigator الجذري، والصورة تأخذ مقاس الشاشة المقاس
/// فعليًا (LayoutBuilder) بدل الاعتماد على قيود InteractiveViewer؛ فلا تُرسم
/// صغيرة في الأعلى ولا تُحجب خلف أي طبقة.
Future<void> showFullscreenImage(
  BuildContext context,
  String url, {
  VoidCallback? onMore,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenImage(url: url, onMore: onMore),
    ),
  );
}

class _FullscreenImage extends StatelessWidget {
  final String url;
  final VoidCallback? onMore;
  const _FullscreenImage({required this.url, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // StackFit.expand: بدونه يأخذ الـStack حجمه من ابنه الوحيد غير المثبَّت
      // (شريط الأزرار العلوي)، فتملأ الصورة شريطًا صغيرًا أعلى الشاشة فقط.
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, c) => InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox(
                width: c.maxWidth,
                height: c.maxHeight,
                child: Image.network(
                  url,
                  width: c.maxWidth,
                  height: c.maxHeight,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('تعذّر تحميل الصورة',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              if (onMore != null)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onMore!();
                  },
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
