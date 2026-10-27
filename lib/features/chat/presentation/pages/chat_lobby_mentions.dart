part of 'chat_lobby_page.dart';

// نص الإشارات (المنشن) وتحليل نطاقاتها
// نُقل من chat_lobby_page.dart بلا أي تغيير في الشيفرة (تقسيم بنيوي فقط).

class _MentionRichText extends StatelessWidget {
  final String text;
  final Color baseColor;
  final Set<String> mentionNames;
  final bool showMentionBadge;

  /// تنسيق الخط الذي اختاره المُرسِل. كان الحجم والوزن مثبّتين
  /// (15 / w600) فيتجاهلان اختيار العضو تمامًا.
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final double fontSize;
  // خط الرسائل الخادمي للمرسِل (cairo, rakkas…). null = الافتراضي.
  final String? fontFamily;

  const _MentionRichText({
    this.fontWeight = FontWeight.w600,
    this.fontStyle = FontStyle.normal,
    this.fontSize = 15,
    this.fontFamily,
    required this.text,
    required this.baseColor,
    this.mentionNames = const <String>{},
    this.showMentionBadge = false,
  });

  static final RegExp _wordChar = RegExp(r'[\w\u0600-\u06FF._-]');

  bool _isWordChar(String value) => _wordChar.hasMatch(value);

  bool _boundaryBefore(String source, int index) {
    if (index <= 0) return true;
    final previous = source.substring(index - 1, index);
    return previous == '@' || !_isWordChar(previous);
  }

  bool _boundaryAfter(String source, int index) {
    if (index >= source.length) return true;
    return !_isWordChar(source.substring(index, index + 1));
  }

  List<_MentionRange> _findMentionRanges() {
    final names = mentionNames
        .map((name) => name.trim().replaceFirst(RegExp(r'^@'), ''))
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final ranges = <_MentionRange>[];
    final occupied = <int>{};

    void addRange(int start, int end, String display) {
      for (var i = start; i < end; i++) {
        if (occupied.contains(i)) return;
      }
      for (var i = start; i < end; i++) {
        occupied.add(i);
      }
      ranges.add(_MentionRange(start: start, end: end, display: display));
    }

    if (names.isEmpty) {
      final legacy = RegExp(r'@[\w\u0600-\u06FF._-]+');
      for (final match in legacy.allMatches(text)) {
        final raw = text.substring(match.start, match.end);
        final display = raw.substring(1);
        if (display.isNotEmpty) addRange(match.start, match.end, display);
      }
    } else {
      // New messages deliberately store the visible text without `@`. The
      // mention target is carried in metadata, so match both forms here.
      for (final name in names) {
        var searchFrom = 0;
        final lowerText = text.toLowerCase();
        final lowerName = name.toLowerCase();
        while (searchFrom < lowerText.length) {
          final index = lowerText.indexOf(lowerName, searchFrom);
          if (index < 0) break;
          final nameEnd = index + name.length;
          final hasAt = index > 0 && text[index - 1] == '@';
          final start = hasAt ? index - 1 : index;
          if ((hasAt || _boundaryBefore(text, index)) && _boundaryAfter(text, nameEnd)) {
            addRange(start, nameEnd, name);
          }
          searchFrom = nameEnd;
        }
      }
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _findMentionRanges();
    if (matches.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: _chatMessageDirection(text),
        softWrap: true,
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: 1.4,
          fontFamily: fontFamily,
        ),
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      // كان غير المُنشَن يرى المنشن بلا أي تمييز بصري — نفس لون
      // الرسالة العادي بالضبط — فيبدو "المنشن لا يعمل" رغم أن
      // المطابقة والبيانات كلاهما سليم. الشارة الكاملة تبقى محجوزة
      // لصاحب المنشن وحده (تنبيه شخصي)، لكن الجميع الآن يرى الاسم
      // بلون مميَّز وخلفية خفيفة فيُدرَك أنه إشارة لا نص عادي.
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: showMentionBadge
              ? ChatMentionBadge(name: match.display, fontSize: 13)
              // الإطار الأزرق يظهر حصرًا للعضو الذي أُشير إليه (showMentionBadge
              // = هو المُنشَن). بقية الأعضاء يرون الاسم نصًّا عاديًا بلون الرسالة.
              : Text(
                  text.substring(match.start, match.end),
                  style: TextStyle(
                    color: baseColor,
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    fontStyle: fontStyle,
                    height: 1.4,
          fontFamily: fontFamily,
                  ),
                ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    final direction = _chatMessageDirection(text);
    return RichText(
      textAlign: TextAlign.right,
      textDirection: direction,
      softWrap: true,
      text: TextSpan(
        style: TextStyle(
          color: baseColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: 1.4,
          fontFamily: fontFamily,
        ),
        children: spans,
      ),
    );
  }
}

class _MentionRange {
  final int start;
  final int end;
  final String display;

  const _MentionRange({
    required this.start,
    required this.end,
    required this.display,
  });
}


String? _normalizeProfileAvatarUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final segments = [...uri.pathSegments];
  final marker = segments.indexOf('public');
  if (marker >= 0 && marker + 3 < segments.length &&
      segments[marker + 1] == 'profile-avatars' &&
      segments[marker + 2] == 'profile-avatars') {
    final fixed = [
      ...segments.sublist(0, marker + 2),
      ...segments.sublist(marker + 3),
    ];
    return uri.replace(pathSegments: fixed).toString();
  }
  return raw;
}
