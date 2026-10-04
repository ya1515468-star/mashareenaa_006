import 'package:flutter/material.dart';
import '../services/upload_progress.dart';

/// دائرة رفع واحدة فقط — لا نص "جارٍ الرفع" ولا اسم الملف ولا شريط خطي
/// منفصل كما كان سابقًا. النسبة المئوية داخل الدائرة نفسها تتحدث مباشرة
/// من progress.fraction (مصدرها الفعلي عدد البايتات المُرسَلة من إجمالي
/// حجم الملف)، فهي دقيقة لا تقديرية، وتصل 100% فعليًا عند الاكتمال.
/// عند النجاح/الفشل يحل رمز ✅/❌ محل الرقم للحظة قبل الاختفاء.
class UploadProgressOverlay extends StatelessWidget {
  final Widget child;
  const UploadProgressOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<UploadProgress?>(
          valueListenable: UploadProgressBus.current,
          builder: (context, progress, _) {
            if (progress == null) return const SizedBox.shrink();
            final isSuccess = progress.status == 'success';
            final isError = progress.status == 'error';
            final done = isSuccess || isError;
            return Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1B1524),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          // قيمة ثابتة (لا دوران غير محدد) عند النجاح/الفشل،
                          // ومتحركة بدقة أثناء الرفع الفعلي.
                          value: done ? 1 : progress.fraction,
                          strokeWidth: 5,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                            isSuccess
                                ? Colors.greenAccent
                                : isError
                                    ? Colors.redAccent
                                    : const Color(0xFFFFD45C),
                          ),
                        ),
                      ),
                      if (isSuccess)
                        const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 26)
                      else if (isError)
                        const Icon(Icons.close_rounded, color: Colors.redAccent, size: 26)
                      else
                        Text(
                          '${progress.percent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
