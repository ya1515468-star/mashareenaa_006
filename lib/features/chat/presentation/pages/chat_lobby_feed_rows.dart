part of 'chat_lobby_page.dart';

// صفوف الموجز: بوت المحتوى، الهدايا، الأحداث
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _ContentBotRow extends StatelessWidget {
  final String message;
  final String label;
  final String icon;
  final String category;
  const _ContentBotRow({
    required this.message,
    required this.label,
    required this.icon,
    required this.category,
  });

  List<Color> get _colors => switch (category) {
        'adhkar' => const [Color(0xFF0F4D3A), Color(0xFF0B2B3F)],
        'trade' => const [Color(0xFF4A2A0C), Color(0xFF1E1A3A)],
        'life' => const [Color(0xFF1F4A2A), Color(0xFF13283F)],
        _ => const [Color(0xFF0E3F4F), Color(0xFF2A1640)],
      };

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE9C46A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: _colors,
          ),
          border: Border.all(color: gold.withValues(alpha: .75), width: 1.3),
          boxShadow: [
            BoxShadow(color: gold.withValues(alpha: .18), blurRadius: 12),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'بوت مشاريعنا',
                  style: TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'MashareenaAmiri',
                fontSize: 16.5,
                height: 1.6,
                color: Color(0xFFFFF6E0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftAnnouncementRow extends StatelessWidget {
  final String message;
  final String emoji;
  final String? imageUrl;
  const _GiftAnnouncementRow({
    required this.message,
    required this.emoji,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              const Color(0xFFD4AF37).withValues(alpha: .22),
              const Color(0xFF7A1F3D).withValues(alpha: .22),
            ]),
            border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: .45), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              // صورة الهدية الحقيقية إن وُجدت، وإلا الإيموجي الخاص بها.
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                )
              else
                Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF5F1E8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalChatEventRow extends StatelessWidget {
  final Map<String, dynamic> event;
  const _GlobalChatEventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return _GlobalEventOverlay(event: event);
  }
}

TextDirection _chatMessageDirection(String value) {
  final arabic = RegExp(r'[\u0600-\u06FF]');
  final latin = RegExp(r'[A-Za-z]');
  final arabicMatch = arabic.firstMatch(value);
  final latinMatch = latin.firstMatch(value);

  if (arabicMatch == null && latinMatch == null) {
    return TextDirection.rtl;
  }
  if (arabicMatch == null) return TextDirection.ltr;
  if (latinMatch == null) return TextDirection.rtl;

  return arabicMatch.start < latinMatch.start
      ? TextDirection.rtl
      : TextDirection.ltr;
}
