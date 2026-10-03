import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CrossPlatformImage extends StatefulWidget {
  final XFile file;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? error;

  const CrossPlatformImage({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.error,
  });

  @override
  State<CrossPlatformImage> createState() => _CrossPlatformImageState();
}

class _CrossPlatformImageState extends State<CrossPlatformImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant CrossPlatformImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.file.name != widget.file.name) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        // كل الحالات (خطأ، تحميل، نجاح) تلتزم الآن بنفس width/height
        // المطلوبَين. سابقًا كانت حالتا التحميل والخطأ بلا أي أبعاد، فتُخطَّط
        // بحجم مختلف تمامًا عن الصورة النهائية، ويتغيّر حجم الودجت فجأة عند
        // اكتمال القراءة — وهو ما يسبب أخطاء "لا يمكن اختبار اللمس على صندوق
        // لم يُخطَّط/بلا حجم" الواردة في تقرير الأخطاء.
        if (snapshot.hasError) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: widget.error ??
                const ColoredBox(
                  color: Color(0x12000000),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              widget.error ?? const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
