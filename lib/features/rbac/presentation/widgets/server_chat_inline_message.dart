import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gamification/domain/entities/username_effect.dart';
import '../../../gamification/presentation/widgets/username_cosmetic_name.dart';
import '../../../gamification/presentation/providers/name_animation_providers.dart';
import '../../../gamification/presentation/widgets/name_animation_widget.dart';
import '../../../profile/presentation/widgets/arabic_font_catalog.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/typography/local_glyph_text.dart';
import 'server_user_identity_badges.dart';
import '../../../chat/presentation/widgets/chat_mention_badge.dart';

class ServerChatInlineMessage extends ConsumerWidget {
  final String uid;
  final String? roomId;
  final String fallbackName;
  final String text;
  final Color messageColor;
  final Color? mentionColor;
  final VoidCallback? onNameTap;
  final double nameFontSize;
  final double messageFontSize;
  final Set<String> mentionNames;
  final bool showMentionBadge;
  /// The bubble's actual fill colour. Needed to guarantee the message text
  /// stays readable — see _readableOn below for why this exists.
  final Color? backgroundColor;

  const ServerChatInlineMessage({
    super.key,
    required this.uid,
    required this.fallbackName,
    required this.text,
    required this.messageColor,
    this.roomId,
    this.mentionColor,
    this.onNameTap,
    this.nameFontSize = 12,
    this.messageFontSize = 14,
    this.mentionNames = const <String>{},
    this.showMentionBadge = false,
    this.backgroundColor,
  });

  /// A user can pick their own message text colour as a VIP customization,
  /// entirely independent of whatever bubble colour they happen to be
  /// rendered on (a room's own theme, say). Nothing previously checked the
  /// two against each other, so a bright colour on a similarly bright bubble
  /// (or the reverse) could make a message unreadable — reported as
  /// "يمكن رؤية الرسائل" on a themed room. This keeps the user's chosen hue
  /// but flips it to a readable tone whenever contrast against the actual
  /// bubble is too low, rather than silently discarding their choice.
  /// يحوّل "#RRGGBB" القادم من كتالوج الألوان الخادمي إلى Color، ويتجاهل
  /// بأمان أي قيمة فارغة أو غير صالحة بدل الانهيار.
  static Color? _hexColor(String? v) {
    final s = (v ?? '').replaceAll('#', '').trim();
    if (s.length != 6) return null;
    final n = int.tryParse('FF$s', radix: 16);
    return n == null ? null : Color(n);
  }

  static Color _readableOn(Color text, Color? background) {
    if (background == null) return text;
    // كان هنا عطلان حقيقيان جعلا ألوان المستخدم تُرفض وتُستبدل بالأبيض/
    // الأسود في معظم الحالات — وهو سبب شكوى "ألوان الخط لا تُنفَّذ":
    //   1) الدالة الداخلية كانت تأخذ المعامل c ثم تتجاهله وتستخدم
    //      background دائمًا، فلا يمكنها قياس لون النص إطلاقًا.
    //   2) لون النص كان يُحسب بلا تصحيح جاما بينما الخلفية تُحسب به،
    //      فتُقارَن قيمتان بمقياسين مختلفين وتخرج نتيجة بلا معنى.
    // الحساب الآن موحَّد وصحيح للطرفين، والعتبة أصبحت أدق (نسبة تباين
    // قياسية) فلا تُلغى إلا الألوان غير المقروءة فعلًا.
    double relativeLuminance(Color c) {
      double ch(double v) =>
          v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    final bgLum = relativeLuminance(background);
    final textLum = relativeLuminance(text);
    final lighter = bgLum > textLum ? bgLum : textLum;
    final darker = bgLum > textLum ? textLum : bgLum;
    final ratio = (lighter + 0.05) / (darker + 0.05);
    // 2.2:1 حدّ متساهل عمدًا: يحترم اختيار المستخدم ما دام النص مقروءًا،
    // ولا يتدخّل إلا عند التصادم الحقيقي (لون على لون شبه مطابق).
    if (ratio >= 2.2) return text;
    return bgLum > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = roomId == null
        ? ref.watch(serverUserIdentityProvider(uid))
        : ref.watch(serverUserIdentityInRoomProvider((uid: uid, roomId: roomId)));
    return async.when(
      loading: () => _fallback(),
      error: (_, __) => _fallback(),
      data: (identity) {
        final display = identity['display_name']?.toString().trim();
        final username = identity['username']?.toString().trim();
        final resolvedName = display?.isNotEmpty == true
            ? display!
            : username?.isNotEmpty == true
                ? username!
                : fallbackName;
        final effect = UsernameEffectX.fromWire(identity['username_effect']?.toString() ?? 'none');
        final templateKey = identity['username_template_key']?.toString();
        // كلا الحقلين (username_color وmessage_color) أعمدة bigint، وكانا
        // يُفحصان بـ"as num?" الذي يفشل صامتًا إن وصلت القيمة كنص (شائع عبر
        // PostgREST لأعمدة bigint) — فيسقط اللون المخصَّص دائمًا للافتراضي
        // بصرف النظر عمّا اختاره المستخدم فعليًا واحتفظ به الخادم بشكل صحيح.
        final nameColor = int.tryParse(identity['username_color']?.toString() ?? '');
        final nameSize = ((identity['username_font_size'] as num?)?.toDouble() ?? nameFontSize).clamp(8.0, 34.0).toDouble();
        final nameFont = localArabicFontFamily(identity['username_font_family']?.toString());
        final messageFont = localArabicFontFamily(identity['message_font_family']?.toString());
        final identityMessageColor = int.tryParse(identity['message_color']?.toString() ?? '');
        // الخادم يوفّر نظام ألوان أحدث وأكمل لم يكن يُقرأ إطلاقًا:
        // message_color_1/message_color_2 بصيغة hex (ولون ثانٍ يعني لونًا
        // مدمجًا متدرّجًا)، إضافة إلى message_color_key من كتالوج الألوان
        // الخادمي. هذه لها الأولوية على الحقل الرقمي القديم لأنها هي ما
        // تكتبه set_my_message_color فعليًا عند اختيار المستخدم أي لون.
        final hex1 = _hexColor(identity['message_color_1']?.toString());
        final hex2 = _hexColor(identity['message_color_2']?.toString());
        final rawMessageColor = hex1 ??
            (identityMessageColor == null ? messageColor : Color(identityMessageColor));
        final effectiveMessageColor = _readableOn(rawMessageColor, backgroundColor);
        // اللون المدمج: تدرّج حقيقي يُرسم على النص نفسه عبر ShaderMask.
        final blendSecond = hex2 == null ? null : _readableOn(hex2, backgroundColor);
        final vip = ref.watch(profilePublicVipEffectsProvider(uid)).valueOrNull ?? const <String, dynamic>{};
        final gradientEnabled = (vip['chat_name_gradient'] as Map?)?['enabled'] == true;
        final glowEnabled = (vip['chat_message_glow'] as Map?)?['enabled'] == true;
        final priorityEnabled = (vip['chat_priority_badge'] as Map?)?['enabled'] == true;
        final mentionEnabled = (vip['chat_mention_highlight'] as Map?)?['enabled'] == true;
        Widget renderedName = UsernameCosmeticName(
          name: resolvedName,
          effect: effect,
          fontSize: nameSize,
          // Same rule as ServerUsernameDisplay: a custom colour must not
          // flatten a selected effect into one shade.
          overrideColor: (effect == UsernameEffect.none && nameColor != null)
              ? Color(nameColor)
              : null,
          fontFamily: nameFont,
          backgroundMode: identity['username_background_mode']?.toString(),
          backgroundColor1: identity['username_background_color1']?.toString(),
          backgroundColor2: identity['username_background_color2']?.toString(),
          backgroundOpacity: ((identity['username_background_opacity'] as num?)?.toDouble() ?? .82).clamp(0.0, 1.0).toDouble(),
          externalEffect: identity['username_background_external_effect']?.toString(),
          templateKey: templateKey,
        );
        if (templateKey == null || templateKey.trim().isEmpty) {
          if (gradientEnabled) {
            renderedName = ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD166), Color(0xFF7DD3FC)],
              ).createShader(bounds),
              child: renderedName,
            );
          }
          if (glowEnabled) {
            renderedName = Container(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(blurRadius: 9, spreadRadius: 1, color: Color(0x557DD3FC))],
              ),
              child: renderedName,
            );
          }
        }
        final activeAnimal = ref.watch(activeNameAnimationProvider(uid)).valueOrNull;
        final safeAnimal = activeAnimal != null && activeAnimal.isActive && activeAnimal.key.trim().isNotEmpty ? activeAnimal : null;
        final animalName = AnimatedNameAnimalAboveName(
          animation: safeAnimal,
          name: renderedName,
          scale: (nameSize / 22.0).clamp(0.55, 2.0).toDouble(),
        );
        final inlineName = onNameTap == null ? animalName : InkWell(onTap: onNameTap, child: animalName);
        final priorityBadge = priorityEnabled
            ? const Padding(
                padding: EdgeInsetsDirectional.only(end: 2),
                child: Icon(Icons.priority_high_rounded, size: 11, color: Color(0xFFFFD166)),
              )
            : const SizedBox.shrink();
        final effectiveMentionColor = mentionEnabled ? const Color(0xFFFFD166) : mentionColor;
        final body = Directionality(
          textDirection: TextDirection.rtl,
          child: RichText(
            softWrap: true,
            text: TextSpan(children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Row(mainAxisSize: MainAxisSize.min, children: [priorityBadge, const SizedBox(width: 3), inlineName]),
              ),
              _messageSpan(text, effectiveMessageColor, messageFont, messageFontSize, showMentionBadge ? effectiveMentionColor : null, mentionNames, showMentionBadge),
            ]),
          ),
        );
        // لون مدمج (تدرّج): يُرسم التدرّج على النص نفسه. بلا لون ثانٍ يُعاد
        // النص كما هو تمامًا، فلا أثر إطلاقًا على الألوان العادية.
        if (blendSecond == null) return body;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [effectiveMessageColor, blendSecond],
          ).createShader(bounds),
          child: body,
        );
      },
    );
  }

  Widget _fallback() => Text(
        text,
        textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: messageFontSize, color: messageColor, fontFamily: null, height: 1.15),
      );

  TextSpan _messageSpan(
    String value,
    Color color,
    String? family,
    double size,
    Color? mention,
    Set<String> mentionNames,
    bool showMentionBadge,
  ) {
    final base = TextStyle(fontSize: size, color: color, fontFamily: family, height: 1.15);
    final names = mentionNames
        .map((name) => name.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final re = names.isEmpty
        ? RegExp(r'@[\w\u0600-\u06FF._-]+')
        : RegExp(r'@(?:' + names.map(RegExp.escape).join('|') + r')(?![\w\u0600-\u06FF._-])', caseSensitive: false);
    final matches = re.allMatches(value);
    final children = <InlineSpan>[];
    var cursor = 0;
    if (matches.isEmpty) {
      children.addAll(localGlyphSpans(value, base));
    } else {
      for (final match in matches) {
        if (match.start > cursor) {
          children.addAll(localGlyphSpans(value.substring(cursor, match.start), base));
        }
        final raw = value.substring(match.start, match.end);
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: showMentionBadge
              ? ChatMentionBadge(name: raw, fontSize: (size - 1).clamp(11.0, 14.0).toDouble())
              : Text(raw, style: base),
        ));
        cursor = match.end;
      }
      if (cursor < value.length) {
        children.addAll(localGlyphSpans(value.substring(cursor), base));
      }
    }
    children.insert(0, TextSpan(text: ' ', style: base));
    return TextSpan(children: children);
  }


}
