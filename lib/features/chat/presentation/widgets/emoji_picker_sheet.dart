import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/typography/local_glyph_text.dart';

/// مكتبة إيموجي منسَّقة بفئات (وليست قاعدة Unicode كاملة بآلاف
/// الرموز — بل مجموعة واسعة وشائعة الاستخدام فعليًا تغطي كل فئة
/// أساسية)، مع بحث نصي بالوصف الإنجليزي المختصر، وقائمة "الأكثر
/// استخدامًا" محفوظة محليًا.
class _EmojiCategory {
  final String nameAr;
  final IconData icon;
  final List<String> emojis;
  const _EmojiCategory(this.nameAr, this.icon, this.emojis);
}

const _categories = [
  _EmojiCategory('وجوه', Icons.emoji_emotions_outlined, [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '🙃',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😗',
    '😋',
    '😜',
    '🤪',
    '🤨',
    '🧐',
    '😎',
    '🤩',
    '🥳',
    '😏',
    '😒',
    '😞',
    '😔',
    '😟',
    '😕',
    '🙁',
    '☹️',
    '😣',
    '😖',
    '😫',
    '😩',
    '🥺',
    '😢',
    '😭',
    '😤',
    '😠',
    '😡',
    '🤬',
    '🤯',
    '😳',
    '🥵',
    '🥶',
    '😱',
    '😨',
    '😰',
    '😥',
    '😓',
    '🤗',
    '🤔',
    '🤭',
    '🤫',
    '🤥',
    '😶',
    '😐',
    '😑',
    '😬',
    '🙄',
    '😯',
  ]),
  _EmojiCategory('إيماءات', Icons.back_hand_outlined, [
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '👏',
    '🙌',
    '👐',
    '🤲',
    '🙏',
    '✊',
    '👊',
    '🤝',
    '💪',
    '👋',
    '🖐️',
    '✋',
    '👆',
    '👇',
    '👈',
    '👉',
    '☝️',
    '💅',
    '🤳',
  ]),
  _EmojiCategory('قلوب ورموز', Icons.favorite_outline, [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '❣️',
    '💕',
    '💞',
    '💓',
    '💗',
    '💖',
    '💘',
    '💝',
    '🔥',
    '✨',
    '⭐',
    '🌟',
    '💫',
    '💯',
    '💢',
    '💥',
    '💦',
    '💤',
  ]),
  _EmojiCategory('أعمال وأدوات', Icons.work_outline, [
    '💼',
    '📁',
    '📂',
    '🗂️',
    '📊',
    '📈',
    '📉',
    '🧾',
    '💳',
    '💰',
    '💵',
    '📦',
    '🛍️',
    '🛒',
    '✅',
    '❌',
    '⚠️',
    '🔔',
    '📌',
    '📎',
    '🖇️',
    '✂️',
    '🔒',
    '🔓',
    '🔑',
    '⏰',
    '📅',
    '✍️',
  ]),
  _EmojiCategory('طبيعة وطعام', Icons.eco_outlined, [
    '🌸',
    '🌹',
    '🌺',
    '🌻',
    '🌷',
    '🌳',
    '🍀',
    '☀️',
    '🌙',
    '⭐',
    '☕',
    '🍵',
    '🍰',
    '🎂',
    '🍕',
    '🍔',
    '🍎',
    '🍉',
    '🎉',
    '🎊',
    '🎁',
    '🏆',
    '🥇',
  ]),
];

/// شريط تفاعل سريع (مثل واتساب/تليجرام): يظهر عند الضغط المطوّل على
/// رسالة، ويحتوي أشهر 6 إيموجي + زر "المزيد" يفتح الـ Picker الكامل.
class QuickReactionBar extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  const QuickReactionBar(
      {super.key, required this.onSelect, required this.onMore});

  static const _quick = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: p.accent.withValues(alpha: 0.15), blurRadius: 12)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _quick)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelect(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: LocalGlyphText(e, style: const TextStyle(fontSize: 22)),
              ),
            ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: p.accent, size: 20),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class EmojiPickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelect;
  const EmojiPickerSheet({super.key, required this.onSelect});

  static Future<void> show(
      BuildContext context, ValueChanged<String> onSelect) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmojiPickerSheet(onSelect: onSelect),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  static const _kRecentKey = 'recent_emojis';
  List<String> _recent = [];
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recent = prefs.getStringList(_kRecentKey) ?? []);
    }
  }

  Future<void> _remember(String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final updated =
        [emoji, ..._recent.where((e) => e != emoji)].take(20).toList();
    await prefs.setStringList(_kRecentKey, updated);
  }

  void _pick(String emoji) {
    _remember(emoji);
    widget.onSelect(emoji);
    Navigator.of(context).pop();
  }

  List<String> get _filtered {
    if (_query.isEmpty) return [];
    final all = _categories.expand((c) => c.emojis).toSet().toList();
    // بحث بسيط: لا وصف نصي لكل إيموجي هنا، لذا البحث يعمل ضمن نفس
    // الفئة إن كتب المستخدم اسم فئة عربي مطابق (وجوه/إيماءات..).
    final matchingCategory =
        _categories.where((c) => c.nameAr.contains(_query));
    if (matchingCategory.isNotEmpty) {
      return matchingCategory.expand((c) => c.emojis).toList();
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: p.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: p.divider, borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  textAlign: TextAlign.right,
                  style: TextStyle(color: p.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن فئة (وجوه، قلوب، أعمال...)',
                    prefixIcon: Icon(Icons.search, color: p.textMuted),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 200), () {
                      if (mounted) setState(() => _query = v.trim());
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    if (_query.isNotEmpty)
                      _EmojiGrid(emojis: _filtered, onTap: _pick)
                    else ...[
                      if (_recent.isNotEmpty) ...[
                        const _SectionTitle(
                            title: 'الأكثر استخدامًا', icon: Icons.history),
                        _EmojiGrid(emojis: _recent, onTap: _pick),
                      ],
                      for (final category in _categories) ...[
                        _SectionTitle(
                            title: category.nameAr, icon: category.icon),
                        _EmojiGrid(emojis: category.emojis, onTap: _pick),
                      ],
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title,
              style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: p.accent),
        ],
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onTap;
  const _EmojiGrid({required this.emojis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        for (final e in emojis)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(e),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LocalGlyphText(e, style: const TextStyle(fontSize: 26)),
            ),
          ),
      ],
    );
  }
}
