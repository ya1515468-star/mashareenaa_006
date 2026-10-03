import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gamification/domain/entities/username_effect.dart';
import '../../../chat/domain/chat_visual_size_service.dart';
import '../../../gamification/presentation/widgets/username_cosmetic_name.dart';
import '../../../profile/presentation/widgets/arabic_font_catalog.dart';
import '../../../gamification/presentation/providers/name_animation_providers.dart';
import '../../../gamification/presentation/widgets/name_animation_widget.dart';
import 'server_user_identity_badges.dart';
import '../../../../core/monitoring/error_monitor.dart';
import 'dart:async';
import 'server_chat_badge_above_name.dart';

/// Single canonical server-backed username renderer for all user surfaces.
class ServerUsernameDisplay extends ConsumerWidget {
  final String uid;
  final String? roomId;
  final String? fallbackName;
  final double? fallbackFontSize;
  final bool showBadges;
  final bool showAchievements;
  final bool compactBadges;
  final bool center;
  final bool showStatus;

  final bool badgesBeforeName;
  final VoidCallback? onNameTap;
  final bool ownerOnlyRole;
  final double sizeMultiplier;
  final bool showTitle;

  /// يمنع رسم شارة الرتبة هنا حين تُعرَض في مكان آخر (تحت الأفاتار
  /// في صف الشات) لتفادي ازدواجها.
  final bool hideRoleBadge;

  const ServerUsernameDisplay({
    super.key,
    required this.uid,
    this.roomId,
    this.fallbackName,
    this.fallbackFontSize,
    this.showBadges = false,
    this.showAchievements = false,
    this.compactBadges = true,
    this.center = false,
    this.showStatus = false,

    this.badgesBeforeName = false,
    this.onNameTap,
    this.ownerOnlyRole = false,
    this.sizeMultiplier = 1.0,
    this.showTitle = false,
    this.hideRoleBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = roomId == null
        ? ref.watch(serverUserIdentityProvider(uid))
        : ref.watch(
            serverUserIdentityInRoomProvider((uid: uid, roomId: roomId)));

    return async.when(
      loading: () => _fallbackWithAnimal(ref),
      // كان الخطأ يُبتلَع صامتًا تمامًا: لا سجل، لا أثر — فمؤثر الاسم
      // أو خلفيته أو قالبه قد يختفي لأي سبب (RLS، انقطاع شبكة، خطأ
      // تحويل نوع) ولا يظهر أي دليل على ذلك في أي مكان. هذا بالضبط
      // ما جعل تشخيص "المؤثرات لا تظهر" مستحيلًا رغم أن كل حلقة على
      // الخادم أُثبتت سليمة بالاختبار. من الآن يُسجَّل كل فشل في
      // client_error_logs بدل أن يختفي بصمت.
      error: (e, st) {
        unawaited(ErrorMonitor.report(e,
            stack: st, screen: 'server_username_display', source: 'identity_fetch'));
        return _fallbackWithAnimal(ref);
      },
      data: (identity) {
        // The visible room name is always the profile display_name.
        // username is an account identifier and must never replace it here.
        final name = _text(identity['display_name']) ??
            fallbackName ??
            _text(identity['username']) ??
            'عضو';

        final effect = UsernameEffectX.fromWire(
          _text(identity['username_effect']) ?? 'none',
        );
        // username_color وstatus_color أعمدة bigint — كانتا تُفحصان بـ"as
        // num?" الذي يفشل صامتًا إن وصلت القيمة كنص (شائع عبر PostgREST)،
        // فيسقط اللون المخصَّص دائمًا رغم حفظه بشكل صحيح على الخادم.
        final usernameColor = int.tryParse(identity['username_color']?.toString() ?? '');
        final storedFontSize = ((identity['username_font_size'] as num?)?.toDouble() ??
                fallbackFontSize ??
                12).clamp(8.0, 34.0).toDouble();
        final fontSize = (storedFontSize * sizeMultiplier).clamp(6.0, 34.0).toDouble();

        final status = _text(identity['status_text']);
        final statusColor = int.tryParse(identity['status_color']?.toString() ?? '');
        final statusFontSize = ((identity['status_font_size'] as num?)?.toDouble() ?? 12.5).clamp(9.0, 22.0).toDouble();
        final statusBold = identity['status_bold'] == true;
        final statusItalic = identity['status_italic'] == true;

        final badges = (showBadges || showAchievements)
            ? ServerUserIdentityBadges(
                uid: uid,
                roomId: roomId,
                // كان الحد الأقصى 11 يجعل "مالك المنصة" بالكاد يُقرأ تحت
                // الأفاتار. رُفع إلى 13 — لا يزال أصغر من اسم العضو
                // نفسه لكنه واضح.
                fontSize: (fontSize - 4).clamp(9.0, 13.0).toDouble(),
                showAchievements: showAchievements,
                showChatBadge: false,
                compact: compactBadges,
                ownerOnlyRole: ownerOnlyRole,
                hideRole: hideRoleBadge,
              )
            : const SizedBox.shrink();

        Widget nameWidget() {
          Widget widget = UsernameCosmeticName(
            name: name,
            effect: effect,
            fontSize: fontSize,
            // A custom username colour must NOT override a chosen effect:
            // UsernameEffectText replaces the effect's whole gradient with
            // shades of overrideColor, which collapsed all 100 effects into a
            // single flat colour — the effect looked like it "did nothing".
            // The colour now applies only when no effect is selected.
            overrideColor: (effect == UsernameEffect.none && usernameColor != null)
                ? Color(usernameColor)
                : null,
            backgroundMode: _text(identity['username_background_mode']),
            backgroundColor1: _text(identity['username_background_color1']),
            backgroundColor2: _text(identity['username_background_color2']),
            backgroundOpacity: ((identity['username_background_opacity'] as num?)?.toDouble() ?? .82).clamp(0.0, 1.0).toDouble(),
            externalEffect: _text(identity['username_background_external_effect']),
            fontFamily: localArabicFontFamily(_text(identity['username_font_family']) ?? 'system_default'),
            templateKey: _text(identity['username_template_key']),
            userId: uid,
          );
          // UsernameEffect remains inside the name renderer. The animal animation
          // is an independent layer above the name and never changes its layout.
          final animalAsync = ref.watch(activeNameAnimationProvider(uid));
          final animal = animalAsync.valueOrNull;
          final safeAnimal = animal != null && animal.isActive && animal.key.trim().isNotEmpty
              ? animal
              : null;
          // The animal badge is sized by BOTH the user's own name size and the
          // owner-controlled animal level (global, or an override for this
          // specific member) — read for the DISPLAYED user, not the viewer.
          final ownerAnimalScale =
              ref.watch(chatVisualSizeProvider(uid)).valueOrNull?.animalScale ?? 1.0;
          Widget wrapped = AnimatedNameAnimalAboveName(
            animation: safeAnimal,
            name: widget,
            scale: ((fontSize / 22.0) * ownerAnimalScale).clamp(0.4, 3.0).toDouble(),
          );
          if (onNameTap == null) return wrapped;
          return InkWell(
            onTap: onNameTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1), child: wrapped),
          );
        }

        final title = showTitle && identity['title'] is Map
            ? _text((identity['title'] as Map)['name_ar'])
            : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              center ? CrossAxisAlignment.center : CrossAxisAlignment.end,
          children: [
            if (showBadges)
              ServerChatBadgeAboveName(
                uid: uid,
                center: center,
                size: (fontSize * 1.35).clamp(20.0, 34.0).toDouble(),
              ),
            Align(
              alignment: center ? Alignment.center : Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment:
                    center ? MainAxisAlignment.center : MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: badgesBeforeName
                    ? [badges, const SizedBox(width: 4), nameWidget()]
                    : [nameWidget(), const SizedBox(width: 4), badges],
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  textAlign: center ? TextAlign.center : TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
                ),
              ),
            if (showStatus && status != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: statusColor == null ? Colors.white70 : Color(statusColor),
                    fontSize: statusFontSize,
                    fontWeight: statusBold ? FontWeight.w800 : FontWeight.w500,
                    fontStyle: statusItalic ? FontStyle.italic : FontStyle.normal,
                    fontFamily: localArabicFontFamily(_text(identity['message_font_family'])),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fallbackWithAnimal(WidgetRef ref) {
    final animal = ref.watch(activeNameAnimationProvider(uid)).valueOrNull;
    return AnimatedNameAnimalAboveName(
      animation: animal,
      name: _fallback(),
      scale: ((((fallbackFontSize ?? 14) * sizeMultiplier).clamp(6.0, 34.0)) / 22.0).clamp(0.55, 2.0).toDouble(),
    );
  }

  Widget _fallback() => Text(
        fallbackName ?? 'عضو',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: ((fallbackFontSize ?? 14) * sizeMultiplier).clamp(6.0, 34.0).toDouble(),
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
