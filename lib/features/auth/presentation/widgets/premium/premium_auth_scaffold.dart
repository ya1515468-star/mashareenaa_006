import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'effects.dart';

/// إطار مشترك لشاشتي الدخول والتسجيل: خلفية سوداء + جزيئات ذهبية
/// عائمة + توهج يتبع اللمس، والمحتوى فوقها داخل [GlassCard] ضمن
/// SingleChildScrollView مركزي. عند تمرير [backgroundImageAsset]، تحل صورة
/// المتغيّر المتناوب محل التدرّج المجرَّد، مع تعتيم كافٍ لضمان وضوح النص.
class PremiumAuthScaffold extends StatelessWidget {
  final Widget child;
  final Widget? topRight;
  final String? backgroundImageAsset;

  const PremiumAuthScaffold(
      {super.key, required this.child, this.topRight, this.backgroundImageAsset});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);
    // أصول الخلفية عمودية (1024×1536، أبعاد هاتف). على شاشة حاسوب عريضة
    // كان BoxFit.cover يقصّها بإفراط شديد فتظهر مشوَّهة ومكبَّرة بلا معنى.
    // الحل: على الشاشات العريضة تُعرض الصورة بعرض محدود في المنتصف فوق
    // خلفية معتمة متجانسة، وعلى الهاتف تملأ الشاشة طبيعيًا كما صُمِّمت.
    final isWide = size.width > 720;
    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          if (backgroundImageAsset != null)
            Positioned.fill(
              child: isWide
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, -0.4),
                              radius: 1.2,
                              colors: [p.surface, p.background],
                            ),
                          ),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: size.height * (1024 / 1536)),
                            child: Image.asset(backgroundImageAsset!,
                                fit: BoxFit.cover),
                          ),
                        ),
                      ],
                    )
                  : Image.asset(backgroundImageAsset!, fit: BoxFit.cover),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.4),
                    radius: 1.2,
                    colors: [p.surface, p.background],
                  ),
                ),
              ),
            ),
          if (backgroundImageAsset != null)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
          const Positioned.fill(child: FloatingGoldDust()),
          SafeArea(
            child: MouseTrackingGlow(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      // كانت حشوة ثابتة 20 بلا أي اعتبار للوحة المفاتيح، فعند
                      // ظهورها (أو على شاشة قصيرة) تُقطع الأزرار السفلية
                      // — ومنها أزرار Google/Apple — بلا إمكانية الوصول إليها.
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        20 + MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: ConstrainedBox(
                        // 420 على الحاسوب، وعرض الشاشة كاملًا (ناقص الحشوة)
                        // على الهاتف — فلا تبدو البطاقة محصورة في عمود ضيق.
                        constraints: BoxConstraints(
                            maxWidth: size.width < 460 ? size.width : 420),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 520),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 18),
                              child: child,
                            ),
                          ),
                          child: GlassCard(child: child),
                        ),
                      ),
                    ),
                  ),
                  if (topRight != null)
                    Positioned(top: 8, left: 8, child: topRight!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
