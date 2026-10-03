import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/theme/app_theme.dart';

/// تسجيل الدخول الاجتماعي عبر Supabase Auth.
class SocialLoginRow extends StatefulWidget {
  final ValueChanged<String>? onError;

  /// كان هذا يأتي من الطراز البصري المتناوب عشوائيًا (طرازان من الثلاثة
  /// يخفيان زر Apple!) — فيظهر الزر ويختفي بين زيارة وأخرى بلا أي منطق،
  /// وهو ما بدا عطلًا حقيقيًا. ظهور Apple الآن يتبع المنصة الفعلية وحدها:
  /// تسجيل Apple لا يعمل أصلًا إلا على أجهزة Apple (وعلى الويب)، فإظهاره
  /// على أندرويد كان يعِد المستخدم بما سيفشل حتمًا.
  final bool showAppleButton;
  const SocialLoginRow({super.key, this.onError, this.showAppleButton = true});

  static bool get supportsApple =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  State<SocialLoginRow> createState() => _SocialLoginRowState();
}

class _SocialLoginRowState extends State<SocialLoginRow> {
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError('تعذّر الحصول على Google ID token.');
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } catch (e) {
      widget.onError?.call('تعذّر تسجيل الدخول عبر Google: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _busy = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw StateError('تعذّر الحصول على Apple identity token.');
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        accessToken: appleCredential.authorizationCode,
      );
    } catch (e) {
      widget.onError?.call('تعذّر تسجيل الدخول عبر Apple: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // ظهور Apple يتبع المنصة الحقيقية، لا الطراز البصري العشوائي.
    final showApple = widget.showAppleButton && SocialLoginRow.supportsApple;
    return Column(
      children: [
        Row(children: [
          Expanded(child: Divider(color: p.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('أو تابع عبر',
                style: TextStyle(color: p.textMuted, fontSize: 12)),
          ),
          Expanded(child: Divider(color: p.divider)),
        ]),
        const SizedBox(height: 14),
        // على الشاشات الضيقة (هاتف) يتكدّس الزران رأسيًا بعرض كامل بدل
        // انضغاطهما جنبًا إلى جنب وقطع نصوصهما؛ وعلى الشاشات الأوسع يبقيان
        // في صف واحد كما هو مُصمَّم — تخطيط واحد يخدم الهاتف والحاسوب معًا.
        LayoutBuilder(builder: (context, constraints) {
          final stack = constraints.maxWidth < 320;
          final google = _SocialButton(
              label: 'Google',
              icon: Icons.g_mobiledata_rounded,
              busy: _busy,
              onTap: _signInWithGoogle);
          final apple = _SocialButton(
              label: 'Apple',
              icon: Icons.apple,
              busy: _busy,
              onTap: _signInWithApple);
          if (!showApple) return google;
          if (stack) {
            return Column(children: [
              google,
              const SizedBox(height: 10),
              apple,
            ]);
          }
          return Row(children: [
            Expanded(child: google),
            const SizedBox(width: 12),
            Expanded(child: apple),
          ]);
        }),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  const _SocialButton(
      {required this.label,
      required this.icon,
      required this.busy,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: Icon(icon, size: 20, color: p.accentBright.withValues(alpha: 0.85)),
      label: Text(label,
          style: TextStyle(
              color: p.textPrimary.withValues(alpha: 0.9), fontSize: 13.5)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: p.divider),
        minimumSize: const Size.fromHeight(46),
        backgroundColor: p.surfaceHighlight.withValues(alpha: 0.5),
      ),
    );
  }
}
