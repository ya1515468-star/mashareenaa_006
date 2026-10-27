part of 'chat_lobby_page.dart';

// صف الرسالة وترويسة الهوية
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _ChatMessageRow extends ConsumerWidget {
  final Map<String, dynamic> row;
  final bool mine;
  final String mentionFrameColor;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyQuote;
  final ValueChanged<String>? onJumpToMessage;
  final VoidCallback? onNameTap;
  final ValueChanged<String>? onVideoTap;

  /// الضغط على سمايل متحرك في الفقاعة ينسخه إلى صندوق الإرسال.
  final ValueChanged<String>? onGifTap;
  final String? roomId;
  final int rankRevision;
  final bool isSystemBot;
  final int messageFrameIndex;
  final String? currentUid;

  const _ChatMessageRow({
    required this.row,
    required this.mine,
    this.mentionFrameColor = 'gold',
    this.onAvatarTap,
    this.onLongPress,
    this.onReplyQuote,
    this.onJumpToMessage,
    this.onNameTap,
    this.onVideoTap,
    this.onGifTap,
    this.roomId,
    this.rankRevision = 0,
    this.isSystemBot = false,
    this.messageFrameIndex = -1,
    this.currentUid,
  });

  static final RegExp _linkPattern = RegExp(
      r'^(https?:\/\/)?(www\.)?(youtube\.com|youtu\.be|tiktok\.com)\/\S+$',
      caseSensitive: false);

  /// كان اللون هنا ثابتًا (0xFF1E293B) فيدهس لون الرسالة الذي يختاره
  /// العضو من المتجر ويحفظه الخادم في profiles.message_color — وهو سبب
  /// شكوى "ألوان كتابة الرسائل لم تظهر في الغرفة". صار يُمرَّر من
  /// build() بعد قراءته من هوية المُرسِل الخادمية.
  /// بطاقة الرسالة الأصلية كاملة (المرسل + المحتوى)، والضغط عليها يقفز
  /// لتلك الرسالة إن كانت محمَّلة ضمن الشاشة (نفس آلية _jumpToPublicMessage
  /// وonJumpToMessage الموجودتين أصلًا). replyToPreview مخزَّنة بصيغة
  /// "اسم المرسل|المحتوى" (انظر _sendMessage)؛ قيمة قديمة بلا الفاصل
  /// (من قبل هذا الإصلاح) تُعرض كمحتوى فقط بلا اسم.
  Widget? _replyQuoteCard() {
    final replyToId = row['reply_to_id']?.toString();
    if (replyToId == null || replyToId.isEmpty) return null;
    final raw = row['reply_to_preview']?.toString() ?? '';
    // صيغة قديمة محتملة (قبل إضافة رابط المصغّرة): جزءان فقط بلا كسر.
    final parts = raw.split('|');
    final senderName = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : 'عضو';
    final content = parts.length > 1 ? parts[1] : (parts.isNotEmpty ? parts[0] : '');
    final thumbUrl = parts.length > 2 ? parts[2] : '';
    final isQuote = row['metadata'] is Map &&
        (row['metadata'] as Map)['reply_mode'] == 'quote';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onJumpToMessage?.call(replyToId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(8),
          border: const Border(right: BorderSide(color: Color(0xFFFFD700), width: 2.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isQuote ? 'اقتباس من $senderName' : senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFFD700), fontSize: 11.5, fontWeight: FontWeight.w800)),
                  if (content.trim().isNotEmpty)
                    Text(content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            // السمايل/الصورة الأصلية تُعرض مصغَّرة فعلياً هنا، لا وصفاً
            // نصياً فقط — هذا بالضبط ما كان غائباً ("يظهر gif بدل ظهوره").
            if (thumbUrl.isNotEmpty) ...[
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbUrl.startsWith('assets/')
                    ? Image.asset(thumbUrl, width: 28, height: 28, fit: BoxFit.contain)
                    : Image.network(thumbUrl, width: 28, height: 28, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _content(double smileySize, Color textColor,
      {bool bold = false, bool italic = false, double scale = 1.0, String? fontFamily}) {
    final fw = bold ? FontWeight.w800 : FontWeight.w500;
    final fs = italic ? FontStyle.italic : FontStyle.normal;
    final sz = (14.0 * scale).clamp(11.0, 22.0);
    final body = (row['body'] ?? row['message'])?.toString() ?? '';
    final type = row['kind']?.toString() ?? 'text';
    final url = row['attachment_url']?.toString() ?? '';

    if (type == 'gif') {
      // البند 4: رسالة واحدة قد تحمل عدّة سمايلات في metadata.gif_urls.
      // كان هذا الموضع يقرأ attachment_url وحده (أي أول سمايل فقط)، فتُرسَل
      // الثلاثة في فقاعة واحدة ولا يظهر منها إلا واحد — وهذا ما كان ناقصًا
      // في الغرف بعد إصلاح الإرسال.
      final metaGifs = () {
        final raw = row['metadata'] is Map
            ? (row['metadata'] as Map)['gif_urls']
            : null;
        if (raw is! List) return const <String>[];
        final list = raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
        return list.length > 1 ? list : const <String>[];
      }();
      if (metaGifs.isNotEmpty) {
        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final u in metaGifs)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGifTap == null ? null : () => onGifTap!(u),
                child: SizedBox(
                  width: isMashareenaBannerGif(u) ? 150.0 : 25.0,
                  height: isMashareenaBannerGif(u) ? 47.0 : 25.0,
                  child: u.startsWith('assets/')
                      ? Image.asset(u, fit: BoxFit.contain)
                      : Image.network(u,
                          fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
          ],
        );
      }
      final banner = isMashareenaBannerGif(url);
      final gifW = banner ? 150.0 : 25.0;
      final gifH = banner ? 47.0 : 25.0;
      final image = url.startsWith('assets/')
          ? Image.asset(url, width: gifW, height: gifH, fit: BoxFit.contain)
          : Image.network(url, width: gifW, height: gifH, fit: BoxFit.contain, gaplessPlayback: true);
      final tile = SizedBox(width: gifW, height: gifH, child: image);
      if (onGifTap == null || url.isEmpty) return tile;
      // لقمة لمس 40×40 حول صورة 25×25 — نفس منطق الاختيار من القائمة،
      // فلا يبدو الضغط على فقاعة مرسَلة "لا يعمل" لضيق مساحته الفعلية.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onGifTap!(url),
        child: SizedBox(width: banner ? gifW : 40, height: banner ? gifH : 40, child: Center(child: tile)),
      );
    }
    if (type == 'image' && url.isNotEmpty) {
      // الضغط يفتح الصورة كاملة، وزر النقاط الثلاث في العارض يفتح قائمة الفقاعة.
      Widget buildImage(String u) => Builder(
            builder: (context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showFullscreenImage(context, u, onMore: onLongPress),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(u,
                    width: 220,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Text('تعذر تحميل الصورة', style: TextStyle(color: textColor))),
              ),
            ),
          );
      // mediaUrl قد يكون مسار تخزين خامًا (لا رابطًا جاهزًا) حين يأتي من
      // bucket خاص — chat-media-plus لمستخدمي VIP+ — فيحتاج توقيعًا عبر
      // جلسة القارئ الحالية قبل أي عرض فعلي؛ راجع التعليق على
      // _needsPrivateSigning أعلى الملف وSupabaseService.resolvePrivateMediaUrl.
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? buildImage(snap.data!)
              : const SizedBox(
                  width: 220,
                  height: 170,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
        );
      }
      return buildImage(url);
    }
    // كانت الرسائل الصوتية تُفتح خارج التطبيق عبر launchUrl تمامًا كالملفات
    // والفيديو — لا مشغّل داخلي إطلاقًا. صوت الغرفة الآن يُشغَّل من الفقاعة
    // نفسها حصرًا؛ الفيديو والملف يبقيان بفتح خارجي كما كانا.
    if (type == 'audio' && url.isNotEmpty) {
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? VoiceMessagePlayer(url: snap.data!)
              : const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
        );
      }
      return VoiceMessagePlayer(url: url);
    }
    if ((type == 'video' || type == 'file') && url.isNotEmpty) {
      final icon = type == 'video' ? Icons.play_circle_fill : Icons.insert_drive_file;
      Widget buildOpenRow(String u) => InkWell(
            onTap: () async {
              await safeLaunch(u);
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedGoldIcon(icon, size: 30),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(body.isEmpty ? 'مرفق' : body,
                      style: TextStyle(
                          color: textColor, fontWeight: FontWeight.w700))),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, size: 16),
            ]),
          );
      if (_needsPrivateSigning(url)) {
        return FutureBuilder<String>(
          future: SupabaseService.resolvePrivateMediaUrl(
              bucket: 'chat-media-plus', pathOrUrl: url),
          builder: (context, snap) => snap.hasData
              ? buildOpenRow(snap.data!)
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return buildOpenRow(url);
    }
    // اليوتيوب/تيك توك: إن كان جسم الرسالة رابطًا خامًا من هاتين
    // المنصتين، يُضمَّن مباشرة عبر EmbeddedMediaPlayer (يوتيوب فعليًا
    // داخل التطبيق، وتيك توك ببطاقة فتح خارجي أنيقة) بدل عرضه كنص.
    final trimmedBody = body.trim();
    if (type == 'text' && _linkPattern.hasMatch(trimmedBody)) {
      final normalized =
          trimmedBody.startsWith('http') ? trimmedBody : 'https://$trimmedBody';
      // يوتيوب: البطاقة نفسها (EmbeddedMediaPlayer مع routeYoutubeToFloating
      // Player) تملك ضغطتها الخاصة لتشغيل المشغّل العائم مباشرة — لا حاجة
      // لـonVideoTap هنا، وتفعيله أيضًا كان سيفتح "مشغل الوسائط" الذي
      // يُضمِّن الفيديو من جديد داخل الغرفة، فيناقض "حصرًا بمشغل عائم".
      // تيك توك يبقى بسلوكه القديم (فتح مشغل الوسائط) لأنه غير مطلوب تغييره.
      final isYoutubeLink = Uri.tryParse(normalized)?.host.toLowerCase().contains('youtu') ?? false;
      return InkWell(
        onTap: (onVideoTap == null || isYoutubeLink)
            ? null
            : () => onVideoTap!(normalized),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
            width: 240,
            // يوتيوب يُشغَّل حصرًا عبر المشغّل العائم العام لا تضمينًا داخل
            // الفقاعة — تيك توك يبقى كما هو.
            child: EmbeddedMediaPlayer(
                url: normalized, routeYoutubeToFloatingPlayer: true)),
      );
    }
    final metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : const <String, dynamic>{};
    final mentionedIds = metadata['mention_user_ids'] is List
        ? (metadata['mention_user_ids'] as List<dynamic>)
            .map((e) => e.toString())
            .toSet()
        : const <String>{};
    final showMentionBadge = currentUid != null &&
        currentUid!.isNotEmpty && mentionedIds.contains(currentUid);

    return _MentionRichText(
      text: body.isEmpty ? 'رسالة فارغة' : body,
      baseColor: textColor,
      fontFamily: fontFamily,
      fontWeight: fw,
      fontStyle: fs,
      fontSize: sz.toDouble(),
      showMentionBadge: showMentionBadge,
      mentionNames: (metadata['mention_user_names'] is List)
          ? (metadata['mention_user_names'] as List<dynamic>)
              .map<String>((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toSet()
          : const <String>{},
    );
  }


  Widget _systemBotIdentity() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      children: [
        Text('👋', style: TextStyle(fontSize: 13)),
        SizedBox(width: 4),
        Text(
          'بوت الترحيب',
          style: TextStyle(
            color: Color(0xFFE9C46A),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(width: 3),
        Text(':', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualSize = isSystemBot || row['user_id']?.toString().trim().isEmpty != false
        ? null
        : ref.watch(chatVisualSizeProvider(row['user_id'].toString())).valueOrNull;
    final smileySize = visualSize?.smileySize ?? 18.0;

    // لون نص الرسالة = ما اختاره المُرسِل نفسه في المتجر، لا لونًا
    // ثابتًا. الخادم يعيده عبر get_user_chat_identity بمفتاحين:
    // message_color_1 (hex من كتالوج الألوان، وهو ما تكتبه
    // set_my_message_color فعليًا) وmessage_color (bigint قديم).
    // 4294967295 = أبيض افتراضي أي "بلا اختيار" فيُترك اللون الأساسي.
    final senderUid = row['user_id']?.toString().trim() ?? '';
    Color messageTextColor = const Color(0xFF1E293B);
    // تنسيق الخط الذي اختاره المُرسِل (غامق/مائل/حجم) — يُحفظ على
    // profiles ويصل مع اللون في نداء الهوية نفسه.
    bool msgBold = false;
    bool msgItalic = false;
    double msgScale = 1.0;
    if (!isSystemBot && senderUid.isNotEmpty) {
      final identity = (roomId == null || roomId!.isEmpty)
          ? ref.watch(serverUserIdentityProvider(senderUid)).valueOrNull
          : ref
              .watch(serverUserIdentityInRoomProvider(
                  (uid: senderUid, roomId: roomId!)))
              .valueOrNull;
      if (identity != null) {
        final hex = (identity['message_color_1'] ?? '')
            .toString()
            .replaceAll('#', '')
            .trim();
        final legacy =
            int.tryParse(identity['message_color']?.toString() ?? '');
        if (hex.length == 6) {
          final n = int.tryParse('FF$hex', radix: 16);
          if (n != null) messageTextColor = Color(n);
        } else if (legacy != null && legacy != 4294967295) {
          messageTextColor = Color(legacy);
        }
        msgBold = identity['message_bold'] == true;
        msgItalic = identity['message_italic'] == true;
        msgScale = double.tryParse(
                identity['message_font_scale']?.toString() ?? '') ??
            1.0;
      }
    }
    // Username size is profile-owned and rendered at its exact server value.
    // The frame/smiley visual-size control must not distort the user's name.
    // رسالة مجهولة: الخادم لم يعد يكتب الاسم/الصورة/البصمة التجميلية في
    // الصف أصلًا، لكن الواجهة كانت ما تزال تمرّر user_id وتفتح البروفايل
    // الحقيقي عند الضغط على الأفاتار — وهو تسريب للهوية رغم إخفاء الاسم.
    final isAnonymous = row['metadata'] is Map &&
        (row['metadata'] as Map)['anonymous_chat'] == true;
    final displayName = row['display_name']?.toString().trim();
    final username = row['username']?.toString().trim();
    final avatarName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : ((username != null && username.isNotEmpty) ? username : 'عضو');
    final chatDisplayName = avatarName;

    final identity = isSystemBot
        ? _systemBotIdentity()
        : _ChatIdentityHeader(
            // بلا uid للمجهول: الترويسة تجلب الرتبة والهوية من الخادم بالـuid.
            uid: isAnonymous ? null : row['user_id']?.toString(),
            roomId: roomId,
            fallbackName: chatDisplayName,
            revision: rankRevision,
            onTap: isAnonymous ? null : onNameTap,
            sizeMultiplier: 1.0,
            anonymous: isAnonymous,
          );

    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final timeText = createdAt == null
        ? ''
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} • ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    // أفاتار البوت كان 58×58 بينما أفاتار العضو 50×50، فيبدو أضخم
    // من الجميع ويكسر انتظام الصف. صار 42 — أصغر من أفاتار العضو
    // لأنه رسالة نظام لا مشارِكًا.
    // أفاتار بوت الترحيب (مُغيَّر بطلب المالك): دائرة بتدرّج ذهبي/عنابي
    // بحافة ذهبية ويد ملوّحة بدل أيقونة الروبوت البنفسجية.
    final baseAvatar = isSystemBot
        ? Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFE9C46A), Color(0xFF7A1F3D)],
              ),
              border: Border.all(color: const Color(0xFFFFE8A3), width: 1.6),
              boxShadow: const [
                BoxShadow(color: Color(0x66E9C46A), blurRadius: 8),
              ],
            ),
            child: const Text('👋', style: TextStyle(fontSize: 20)),
          )
        : _VideoStyleAvatar(
            url: isAnonymous ? null : row['avatar_url']?.toString(),
            // بلا uid للمجهول: شارة الرتبة وأي استعلام هوية يكشف صاحبها.
            rowUid: isAnonymous ? null : row['user_id']?.toString(),
            name: isAnonymous ? 'عضو مجهول' : avatarName,
            roomId: roomId,
            frameKey: isAnonymous
                ? null
                : (row['metadata'] is Map
                    ? (row['metadata'] as Map)['avatar_frame_key']?.toString()
                    : null),
            below: (!isAnonymous &&
                    row['user_id']?.toString().trim().isNotEmpty == true)
                ? IgnorePointer(
                    child: ServerRoleBadgeUnderAvatar(
                      uid: row['user_id'].toString(),
                      roomId: roomId,
                    ),
                  )
                : null,
          );

    // شارة الرتبة/السلطة (مالك المنصة، سوبر أدمن، الرتب المهنية...)
    // كانت تُرسم بجانب الاسم داخل ServerUsernameDisplay — نُقلت تحت
    // الأفاتار كما طُلب.
    //
    // أول محاولة استعملت Positioned بإزاحات سالبة (bottom:-8, left/
    // right:-6) داخل الـStack، فظهرت الشارة بعيدة عن الأفاتار فعليًا:
    // Positioned بـleft وright معًا يتمدّد ليملأ عرض صندوق الـStack
    // كاملًا لا عرض الأفاتار نفسه، وأي اختلاف بسيط في حجم الصندوق
    // (من الإطارات المتحركة، توسّع الخط...) يُبعد المركز الفعلي عن
    // مركز الأفاتار المرئي. Column بترتيب طبيعي (لا تمركز حسابي ولا
    // إزاحات سالبة) يضمن التصاقها مباشرة بلا أي احتمال انحراف.
    final avatarWithBadges = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isSystemBot || row['user_id']?.toString().trim().isEmpty != false)
          baseAvatar
        else
          Stack(
            clipBehavior: Clip.none,
            children: [
              baseAvatar,
              Positioned(
                right: -3,
                top: -4,
                child: IgnorePointer(
                  child: ServerRankBadge(
                    uid: row['user_id'].toString(),
                    diameter: 20,
                  ),
                ),
              ),
            ],
          ),
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: onLongPress,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Username/identity is deliberately OUTSIDE ChatMessageFrame.
                    //
                    // DefaultTextStyle.merge كان يفرض هنا لونًا كحليًا
                    // ثابتًا (#152033) على أي Text بلا style صريح تحته —
                    // وServerUsernameDisplay بالضبط هو ذلك النص: يرث اللون
                    // المفروض فتُدهَس ألوان المؤثرات والقوالب كلها قبل أن
                    // تصل الشاشة. هذا هو سبب "الاسم يظهر أبيض/كحلي عاديًا"
                    // رغم صحة كل حلقة في السلسلة الخادمية — الودجت الصحيح
                    // كان يُبنى وسط شجرة تفرض عليه لونًا لا يملك حق رفضه.
                    // إزالة اللون من DefaultTextStyle تكفي: كل نص فرعي لم
                    // يعد يُجبَر على الكحلي، بينما الحجم والوزن يبقيان
                    // كافتراض يستطيع أي نص فرعي تجاوزه.
                    SizedBox(
                      width: double.infinity,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: DefaultTextStyle.merge(
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            child: identity,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // The panel grows with the message and is capped for comfortable
                    // reading on both mobile and web.
                    Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .82,
                        ),
                        child: ChatMessageFrame(
                          silver: messageFrameIndex.isOdd,
                          child: Directionality(
                            textDirection: _chatMessageDirection(
                              row['body']?.toString() ?? '',
                            ),
                            // كان الوقت يُرسم فوق النص داخل Stack بافتراض أن
                            // الزاوية السفلية اليسرى للفقاعة تبقى فارغة
                            // دائمًا — وينكسر هذا الافتراض كلما وصل آخر سطر
                            // من الرسالة إلى تلك الزاوية فعلًا (رسالة قصيرة،
                            // أو عربية تنتهي يسارًا)، فيتراكب الوقت على
                            // النص كما في صورتك. Column يضع الوقت دائمًا
                            // بعد النص في تدفّق طبيعي — نفس الترتيب ونفس
                            // الزاوية، بلا أي احتمال تراكب. المحاذاتان
                            // (يمين للنص، يسار للوقت) مطلقتان كما كانتا في
                            // الأصل (Alignment لا AlignmentDirectional) حتى
                            // لا ينعكس الترتيب مع رسائل الاتجاه المختلف
                            // (الأصل استعمل Positioned(left:0) أي يسار
                            // فعلي بصرف النظر عن اتجاه هذا الـDirectionality).
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // بطاقة الاقتباس/الرد: البيانات كانت تُلتقَط
                                // عند الإرسال (reply_to_id/preview) وtamam
                                // _jumpToPublicMessage جاهزة ومُمرَّرة أصلًا
                                // عبر onJumpToMessage — لكن build() هنا لم
                                // يكن يرسم منها أي بطاقة إطلاقًا، فتصل
                                // البيانات وتُفقَد بصمت. هذا هو العطل الذي
                                // وصفته الوثيقة بالضبط.
                                if (_replyQuoteCard() case final card?)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: SizedBox(width: double.infinity, child: card),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    // فقاعة الغرفة كانت ترسم النص بلا أي fontFamily
                                    // إطلاقًا — منطق خطوط الخادم كان في
                                    // ServerChatInlineMessage التي لا تستعملها
                                    // الغرف أصلًا (الخاص وحده). الخط هنا من مفتاح
                                    // المرسِل الخادمي، ويُعاد البناء حين يجهز.
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: ServerFonts.revision,
                                      builder: (_, __, ___) => _content(
                                          smileySize, messageTextColor,
                                          bold: msgBold,
                                          italic: msgItalic,
                                          scale: msgScale,
                                          fontFamily: loadedServerFontFamily(ref
                                              .watch(serverMessageFontKeyProvider(
                                                  row['user_id']?.toString() ?? ''))
                                              .valueOrNull)),
                                    ),
                                  ),
                                ),
                                if (timeText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        timeText,
                                        textAlign: TextAlign.left,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                          color: Color(0xFF6F7783),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                  // النقاط الثلاث: رد، اقتباس، مشاركة، حذف (نفس قائمة الضغط المطوّل).
                  if (onLongPress != null)
                    Positioned(
                      left: 2,
                      top: 0,
                      child: GestureDetector(
                        onTap: onLongPress,
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar + rank are deliberately outside ChatMessageFrame and remain
          // on the right side of the message row. Kept as a plain child:
          // wrapping it in SizedBox/OverflowBox to fine-tune vertical
          // alignment gave it an unbounded width inside the Row and broke the
          // whole message layout, so alignment stays with crossAxisAlignment.
          GestureDetector(
            // الضغط على أفاتار رسالة مجهولة كان يفتح البروفايل الحقيقي.
            onTap: (isSystemBot || isAnonymous) ? null : onAvatarTap,
            child: avatarWithBadges,
          ),
          ],
        ),
      ),
    );
  }

}

class _ChatIdentityHeader extends StatelessWidget {
  final String? uid;
  final String? roomId;
  final String fallbackName;
  final int revision;
  final VoidCallback? onTap;
  final bool anonymous;
  final double sizeMultiplier;

  const _ChatIdentityHeader({
    this.uid,
    this.roomId,
    required this.fallbackName,
    this.revision = 0,
    this.onTap,
    this.anonymous = false,
    this.sizeMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (anonymous || uid == null || uid!.trim().isEmpty) {
      return Text(
        '${anonymous ? 'عضو مجهول' : fallbackName} :',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      );
    }

    // revision is deliberately kept in the widget API because chat lobby
    // invalidates/rebuilds identity after profile changes.
    final _ = revision;

    final username = ServerUsernameDisplay(
      uid: uid!,
      roomId: roomId,
      fallbackName: fallbackName,
      fallbackFontSize: 11,
      showTitle: true,
      showBadges: true,
      showAchievements: false,
      sizeMultiplier: sizeMultiplier,
      badgesBeforeName: false,
      // Status is intentionally profile-only; public rooms must not show it.
      showStatus: false,
      onNameTap: onTap,
      // شارة الرتبة تُرسَم الآن تحت الأفاتار (ServerRoleBadgeUnderAvatar
      // في _avatar أعلاه)، فتُعطَّل هنا لمنع ازدواجها بجانب الاسم.
      hideRoleBadge: true,
    );

    return username;
  }
}
