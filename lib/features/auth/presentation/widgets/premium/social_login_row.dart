import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/oauth_config.dart';
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

  /// nonce عشوائي: يُرسَل مُجزَّأً (SHA-256) إلى المزوّد ويُرسَل الأصل إلى
  /// Supabase كي يطابقه مع ما في التوكن. هذا ما يمنع إعادة استخدام توكن
  /// مسروق (replay) لتسجيل الدخول بحساب غيرك.
  static String _rawNonce([int len = 32]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final r = math.Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<void> _signInWithGoogle() async {
    if (!OAuthConfig.googleReady) {
      widget.onError?.call(
        'الدخول عبر Google غير مهيّأ بعد على هذا الإصدار. '
        'يلزم إضافة معرّف عميل الويب (Web Client ID).',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      // serverClientId إلزامي على أندرويد: بدونه تعود idToken = null دائمًا
      // ويفشل الدخول في كل مرة. على iOS/الويب لا يضرّ تمريره.
      final googleUser = await GoogleSignIn(
        serverClientId: OAuthConfig.googleWebClientId,
        scopes: const ['email', 'profile'],
      ).signIn();
      if (googleUser == null) return; // ألغى المستخدم
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw StateError(
          'لم يُعِد Google رمز هوية. تأكّد من تطابق بصمة SHA-1 ومعرّف الحزمة '
          'في عميل أندرويد، ومن صحّة Web Client ID.',
        );
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
      final rawNonce = _rawNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: _sha256(rawNonce),
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw StateError('تعذّر الحصول على Apple identity token.');
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
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
