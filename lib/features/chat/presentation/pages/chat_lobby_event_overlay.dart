part of 'chat_lobby_page.dart';

// طبقة أحداث المنصّة العامة
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _GlobalEventOverlay extends StatefulWidget {
  final Map<String, dynamic> event;
  const _GlobalEventOverlay({super.key, required this.event});
  @override
  State<_GlobalEventOverlay> createState() => _GlobalEventOverlayState();
}

class _GlobalEventOverlayState extends State<_GlobalEventOverlay> {
  Timer? _hideTimer;
  bool _visible = true;

  /// أصوات الدخول الملكي محفوظة في الخادم (royal_<effect>) وليست في المشروع.
  String _effectSoundKey(String effect) {
    const allowed = <String>{
      'lion_fire',
      'lion_gold',
      'dragon_fire',
      'crown_light',
      'phoenix_flame',
      'thunder_crown',
      'ice_dragon',
      'diamond_storm',
      'cosmic_gate',
      'golden_rain',
    };
    return allowed.contains(effect) ? 'royal_$effect' : 'royal_lion_fire';
  }

  @override
  void initState() {
    super.initState();
    final effect = widget.event['event_type']?.toString() == 'owner_entry'
        ? ((widget.event['payload'] is Map)
            ? (widget.event['payload'] as Map)['effect']?.toString()
            : null)
        : null;
    if (effect != null) {
      unawaited(ServerSounds.instance.play(_effectSoundKey(effect), volume: 1.0));
    }
    final expires = DateTime.tryParse(widget.event['expires_at']?.toString() ?? '');
    if (expires != null) {
      final delay = expires.difference(DateTime.now());
      _hideTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final type = widget.event['event_type']?.toString() ?? '';
    final payload = widget.event['payload'] is Map
        ? Map<String, dynamic>.from(widget.event['payload'] as Map)
        : const <String, dynamic>{};
    final actor = (payload['from_name'] ?? payload['actor_name'])?.toString().trim();
    final actorLabel = (actor == null || actor.isEmpty) ? 'عضو' : actor;
    final actorEffect = UsernameEffectX.fromWire(payload['username_effect']?.toString());
    final actorTemplateKey = payload['username_template_key']?.toString();
    final actorFontSize = ((payload['username_font_size'] as num?)?.toDouble() ?? 12.0)
        .clamp(8.0, 26.0)
        .toDouble();
    final actorBackgroundMode = payload['username_background_mode']?.toString();
    final actorBackgroundColor1 = payload['username_background_color1']?.toString();
    final actorBackgroundColor2 = payload['username_background_color2']?.toString();
    final actorBackgroundOpacity = ((payload['username_background_opacity'] as num?)?.toDouble() ?? .82).clamp(0.0, 1.0).toDouble();
    final actorBackgroundExternal = payload['username_background_external_effect']?.toString();
    final welcomeName = (payload['target_username'] ?? payload['actor_name'] ?? payload['from_name'])?.toString().trim();
    final rawWelcome = payload['message']?.toString().trim();
    final welcomeText = (rawWelcome == null || rawWelcome.isEmpty)
        ? 'أهلًا وسهلًا${welcomeName == null || welcomeName.isEmpty ? '' : ' يا $welcomeName'}، نورت الشات ونتمنى لك وقتًا جميلًا معنا'
        : (rawWelcome.contains(welcomeName ?? '') || welcomeName == null || welcomeName.isEmpty
            ? rawWelcome
            : 'أهلًا وسهلًا يا $welcomeName، $rawWelcome');
    final text = switch (type) {
      'welcome_bot' => welcomeText,
      'owner_entry' => '👑 ${payload['actor_name'] ?? payload['from_name'] ?? 'المالك'} دخل الغرفة',
      'gift' => '🎁 $actorLabel أهدى ${payload['gift_name'] ?? 'هدية'} ${payload['emoji'] ?? '🎁'}',
      'points_transfer' => '⭐ $actorLabel حوّل ${payload['amount'] ?? 0} نقطة إلى ${(payload['to_name'] ?? 'عضو')}',
      'gems_transfer' => '💎 $actorLabel حوّل ${payload['amount'] ?? 0} جوهرة إلى ${(payload['to_name'] ?? 'عضو')}',
      'platform_idea_suggestion' => '💡 اقتراح للمنصة',
      'platform_live_suggestion' => '🔴 اقتراح بث مباشر',
      'user_joined' => '✨ $actorLabel انضم إلى الغرفة',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    final imageUrl = (payload['image_url'] ?? payload['avatar_url'])?.toString();
    final isWelcome = type == 'welcome_bot';
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final cardWidth = math.min(420.0, math.max(0.0, availableWidth - 24.0));
          final cardMaxHeight = math.min(420.0, math.max(140.0, availableHeight * 0.62));
          final imageWidth = math.min(170.0, math.max(90.0, cardWidth * 0.46));

          Widget welcomeImage() {
            if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();
            final image = imageUrl.startsWith('asset://')
                ? Image.asset(
                    imageUrl.substring('asset://'.length),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  );
            return SizedBox(
              width: imageWidth,
              child: AspectRatio(aspectRatio: 480 / 854, child: image),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cardWidth,
                maxHeight: cardMaxHeight,
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xE62A0E42),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isWelcome ? const Color(0xFFFFD45C) : const Color(0xFFB85CFF),
                  ),
                  boxShadow: isWelcome
                      ? const [BoxShadow(color: Colors.black54, blurRadius: 18)]
                      : null,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWelcome)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: welcomeImage(),
                        ),
                      if (!isWelcome && imageUrl != null && imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            imageUrl,
                            width: math.min(140.0, cardWidth * 0.4),
                            height: math.min(95.0, cardWidth * 0.27),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      if (isWelcome || (imageUrl != null && imageUrl.isNotEmpty))
                        const SizedBox(height: 8),
                      if (isWelcome)
                        RichText(
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: cardWidth < 300 ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(text: 'أهلًا وسهلًا يـ '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: actorTemplateKey != null && actorTemplateKey.trim().isNotEmpty
                                    ? UsernameCosmeticName(
                                        name: (welcomeName == null || welcomeName.isEmpty) ? actorLabel : welcomeName,
                                        effect: actorEffect,
                                        fontSize: actorFontSize,
                                        backgroundMode: actorBackgroundMode,
                                        backgroundColor1: actorBackgroundColor1,
                                        backgroundColor2: actorBackgroundColor2,
                                        backgroundOpacity: actorBackgroundOpacity,
                                        externalEffect: actorBackgroundExternal,
                                        templateKey: actorTemplateKey,
                                      )
                                    : UsernameCosmeticName(
                                        name: (welcomeName == null || welcomeName.isEmpty) ? actorLabel : welcomeName,
                                        effect: actorEffect,
                                        fontSize: actorFontSize,
                                        backgroundMode: actorBackgroundMode,
                                        backgroundColor1: actorBackgroundColor1,
                                        backgroundColor2: actorBackgroundColor2,
                                        backgroundOpacity: actorBackgroundOpacity,
                                        externalEffect: actorBackgroundExternal,
                                      ),
                              ),
                              const TextSpan(text: '، نورت الشات ونتمنى لك وقتًا جميلًا معنا'),
                            ],
                          ),
                        )
                      else
                        LocalGlyphText(
                          text,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          softWrap: true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// إعلان هدية داخل الغرفة. النص والرمز يأتيان كلاهما من الخادم حصرًا
/// (public_chat_messages.metadata التي يكتبها send_gift_atomic من كتالوج
/// الهدايا) — لا قائمة رموز محلية إطلاقًا، فأي هدية يضيفها المالك للكتالوج
/// تظهر برمزها الصحيح تلقائيًا بلا أي تعديل في التطبيق.
/// فقاعة بوت المحتوى (معلومات الخياطة/أذكار/أسرار المهنة/الحياة/تجارب/
/// تجارة). تُنشر من الخادم (pg_cron → private.content_bot_tick) في كل غرفة.
/// لون مختلف عن كل فقاعات الأعضاء (تدرّج زمردي/كحلي بحافة ذهبية) وخط
/// MashareenaAmiri المضمَّن في التطبيق، للفت النظر.
