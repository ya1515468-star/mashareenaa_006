part of 'chat_lobby_page.dart';

// شريط الكتابة والأشرطة السفلية والمعلّقة
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BottomItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoStyleBottomBar extends StatelessWidget {
  final bool showOptions;
  final VoidCallback onOptions;
  final VoidCallback onRooms;
  final VoidCallback onOnline;
  final VoidCallback onFriends;
  final VoidCallback onChatStore;
  final VoidCallback? onMedia;
  final bool showMediaPlay;

  const _VideoStyleBottomBar({
    required this.showOptions,
    required this.onOptions,
    required this.onRooms,
    required this.onOnline,
    required this.onFriends,
    required this.onChatStore,
    required this.onMedia,
    this.showMediaPlay = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8A6D1C), Color(0xFF3A2C0A)],
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (final item
                  in <({IconData icon, String label, VoidCallback onTap})>[
                if (showMediaPlay && onMedia != null)
                  (icon: Icons.play_circle_fill, label: 'تشغيل', onTap: onMedia!),
                (icon: Icons.meeting_room_outlined, label: 'الغرف', onTap: onRooms),
                (icon: Icons.people_outline, label: 'المتصلون', onTap: onOnline),
                (icon: Icons.person_add, label: 'الأصدقاء', onTap: onFriends),
                (icon: Icons.storefront_outlined, label: 'المتجر', onTap: onChatStore),
                if (showOptions)
                  (
                    icon: Icons.settings_rounded,
                    label: 'الخيارات',
                    onTap: onOptions
                  ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    width: 76,
                    child: InkWell(
                      onTap: item.onTap,
                      child: _BottomItem(item.icon, item.label),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onSticker;
  final Future<void> Function(String url) onVoice;
  final VoidCallback onSend;
  final Color? textColor;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onSticker,
    required this.onVoice,
    required this.onSend,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Widget actionButton({
      required IconData icon,
      required VoidCallback onPressed,
      String? tooltip,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: sending ? null : onPressed,
        splashRadius: 22,
        icon: Icon(icon, size: 21),
        color: p.accentBright,
        disabledColor: p.textMuted,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .98),
        border: Border(
          top: BorderSide(color: p.divider.withValues(alpha: .75)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [p.accent, p.secondary],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: .22),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'إرسال',
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.arrow_upward_rounded, size: 21),
              color: p.background,
              disabledColor: p.background.withValues(alpha: .5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 138),
              decoration: BoxDecoration(
                color: p.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: p.divider.withValues(alpha: .9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 9,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final direction = _chatMessageDirection(value.text);
                  return Directionality(
                    textDirection: direction,
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textAlign: direction == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      textDirection: direction,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: p.accentBright,
                      style: TextStyle(
                      color: textColor ?? p.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: direction == TextDirection.rtl
                          ? 'اكتب رسالتك…'
                          : 'Write a message…',
                      hintStyle: TextStyle(
                        color: p.textMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        10,
                        14,
                        10,
                      ),
                    ),
                      onSubmitted: (_) => onSend(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 2),
          // السمايل: إيموجي ثابتة + GIF متحركة معًا بتبويبين ضمن قسم واحد
          // (بدل زرين/ورقتين منفصلتين).
          actionButton(
            icon: Icons.emoji_emotions_outlined,
            onPressed: onSticker,
            tooltip: 'السمايلات',
          ),
          // أيقونة المشغّل المصغَّر (تظهر فقط حين تُصغَّر نافذة اليوتيوب).
          const MiniPlayerChip(),
          // زر الموسيقى دُمج داخل زر + (مرفق) كأحد خياراته — "بحث أغنية"
          // في _showQuickActionsSheet — بدل أيقونة مستقلة هنا.
          actionButton(
            icon: Icons.add_circle_outline_rounded,
            onPressed: onAttach,
            tooltip: 'مرفق',
          ),
          // تسجيل بنمط واتساب: اضغط مطوّلًا، حرّر للإرسال، اسحب للإلغاء أو للقفل.
          VoiceHoldButton(onUploaded: onVoice),
        ],
      ),
    );
  }
}

/// شريط صغير أعلى صندوق الكتابة يعرض حالة معلَّقة (رد جارٍ تحضيره،
/// أو GIF بانتظار التأكيد) مع زر إلغاء — يُستخدم لكل من معاينة الرد
/// ومعاينة الـ GIF المعلَّق في _ChatLobbyPageState.build.
class _PendingBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onCancel;
  const _PendingBar(
      {required this.icon, required this.label, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF1E1C24),
      child: Row(children: [
        Icon(icon, color: const Color(0xFFC187FF), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        InkWell(
          onTap: onCancel,
          child: const Icon(Icons.close, color: Colors.white54, size: 18),
        ),
      ]),
    );
  }
}

class _PendingGifBar extends StatelessWidget {
  final List<String> gifs;
  final void Function(int index) onRemove;

  const _PendingGifBar({required this.gifs, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: const Color(0xFF1E1C24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gifs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: gifs[i].startsWith('http')
                  ? Image.network(gifs[i], fit: BoxFit.contain, gaplessPlayback: true)
                  : Image.asset(gifs[i], fit: BoxFit.contain, gaplessPlayback: true),
            ),
            PositionedDirectional(
              top: -4,
              start: -4,
              child: InkWell(
                onTap: () => onRemove(i),
                child: const CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.black87,
                  child: Icon(Icons.close, color: Colors.white, size: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
