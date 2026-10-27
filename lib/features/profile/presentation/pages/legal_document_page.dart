import 'dart:async';
import '../../../../core/error/failure_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';

/// قارئ المستندات القانونية داخل التطبيق.
///
/// كانت الأربعة (الخصوصية، الشروط، إرشادات المجتمع، حذف الحساب) تفتح
/// نافذة متصفّح على دالّة legal فتظهر صفحة خام — وهو ما وُصف بـ«تفتح
/// نافذة متصفّح وتظهر كتابات غريبة».
///
/// الرابط العام يبقى موجودًا (المتجران يشترطان رابطًا يُفتَح بلا تسجيل
/// دخول) لكنّه صار خيارًا ثانيًا، والقراءة الأولى هنا.
///
/// والمحتوى من القاعدة لا من الشيفرة: تعديل بند قانوني لا يصحّ أن
/// يستلزم بناء نسخة وانتظار تحديث كل مستخدم.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.docKey});

  final String docKey;

  static const privacy = 'privacy_policy';
  static const terms = 'terms_of_use';
  static const guidelines = 'community_guidelines';
  static const accountDeletion = 'account_deletion';

  static Future<void> open(BuildContext context, String docKey) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LegalDocumentPage(docKey: docKey),
    ));
  }

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Map<String, dynamic>? _doc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client
          .rpc('get_legal_document', params: {'p_doc_key': widget.docKey});
      if (!mounted) return;
      setState(() {
        _doc = raw is Map ? Map<String, dynamic>.from(raw) : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FailureText.of(e);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _sections {
    final v = _doc?['sections'];
    return v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0718),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorView()
                : doc == null
                    ? _missingView()
                    : _content(doc),
      ),
    );
  }

  Widget _errorView() => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('📡', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل المستند',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11.5)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة')),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('رجوع')),
            ]),
          ),
        ),
      );

  Widget _missingView() => SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📄', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            const Text('هذا المستند غير متاح حاليًا',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 14),
            TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('رجوع')),
          ]),
        ),
      );

  Widget _content(Map<String, dynamic> doc) {
    final sections = _sections;
    return CustomScrollView(
      slivers: [
        // ترويسة متدرّجة تتقلّص مع التمرير: المستند القانوني طويل، وعنوان
        // ثابت يأكل ثلث الشاشة طوال القراءة.
        SliverAppBar(
          pinned: true,
          expandedHeight: 196,
          backgroundColor: const Color(0xFF1A0F33),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding:
                const EdgeInsetsDirectional.only(start: 54, bottom: 14, end: 16),
            title: Text(
              '${doc['emoji'] ?? '📄'}  ${doc['title'] ?? ''}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            background: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF2B1A55), Color(0xFF120A24)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 52),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${doc['emoji'] ?? '📄'}',
                          style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      if ((doc['subtitle']?.toString() ?? '').isNotEmpty)
                        Text(doc['subtitle'].toString(),
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 36),
          sliver: SliverList.list(children: [
            _meta(doc),
            if ((doc['intro']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              _introCard(doc['intro'].toString()),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < sections.length; i++)
              _sectionCard(sections[i], i + 1),
            // معلومات المالك والتواصل الفوري وحقوق النشر — تظهر حيث
            // يضعها الخادم (إرشادات المجتمع) ولا تُبنى في الشيفرة.
            if ((doc['owner_whatsapp']?.toString() ?? '').isNotEmpty)
              _ownerContact(doc),
            if ((doc['copyright']?.toString() ?? '').isNotEmpty)
              _copyright(doc['copyright'].toString()),
            const SizedBox(height: 10),
            _footer(doc),
          ]),
        ),
      ],
    );
  }

  Widget _meta(Map<String, dynamic> doc) {
    final version = doc['version']?.toString() ?? '';
    final updated = DateTime.tryParse('${doc['updated_at']}');
    return Wrap(spacing: 6, runSpacing: 6, children: [
      if (version.isNotEmpty) _chip('🏷️', 'النسخة $version'),
      if (updated != null)
        _chip('🗓️',
            'آخر تحديث ${updated.year}/${updated.month.toString().padLeft(2, '0')}/${updated.day.toString().padLeft(2, '0')}'),
      _chip('📱', 'يُقرأ داخل التطبيق'),
    ]);
  }

  Widget _chip(String emoji, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
        ]),
      );

  Widget _introCard(String intro) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.gold.withValues(alpha: .14),
              Colors.white.withValues(alpha: .03),
            ],
          ),
          border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
        ),
        child: Text(intro,
            style: const TextStyle(
                color: Colors.white, fontSize: 13.5, height: 1.75)),
      );

  Widget _sectionCard(Map<String, dynamic> s, int index) {
    final bullets = s['bullets'] is List
        ? (s['bullets'] as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList()
        : const <String>[];
    final body = s['body']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF160C2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // رقم القسم مع الإيموجي: الترقيم يسمح بالإحالة إلى بند بعينه
        // عند السؤال أو الاعتراض.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${s['emoji'] ?? '•'}',
                  style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$index',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold.withValues(alpha: .7))),
                  Text('${s['heading'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          height: 1.3)),
                ],
              ),
            ),
          ]),
        ),
        if (body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(body,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.8)),
          ),
        if (bullets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final b in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(b,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    height: 1.7)),
                          ),
                        ]),
                  ),
              ],
            ),
          ),
      ]),
    );
  }

  /// زرّ تواصل فوري يفتح واتساب.
  ///
  /// الرقم من الخادم بصيغته الدولية، فتعديله لا يستلزم نسخة جديدة.
  /// وإن لم يكن واتساب مُثبَّتًا يُفتَح في المتصفّح — وإن تعذّر ذلك
  /// أيضًا يُنسَخ الرقم، فلا تبقى الضغطة بلا نتيجة.
  Widget _ownerContact(Map<String, dynamic> doc) {
    final wa = doc['owner_whatsapp'].toString();
    final phone = doc['owner_phone']?.toString() ?? wa;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF115E3A), Color(0xFF0C2B1E)],
        ),
        border: Border.all(color: const Color(0x5525D366)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Text('💬', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('تواصل فوري مع المالك',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.black),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text(phone,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
            onPressed: () => _openWhatsapp(wa, phone),
          ),
        ),
      ]),
    );
  }

  Future<void> _openWhatsapp(String intl, String phone) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    for (final uri in [
      Uri.parse('whatsapp://send?phone=$intl'),
      Uri.parse('https://wa.me/$intl'),
    ]) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // يُجرَّب البديل
      }
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: phone));
    messenger?.showSnackBar(const SnackBar(
        content: Text('تعذّر فتح واتساب — نُسخ الرقم، اتصل به مباشرةً')));
  }

  Widget _copyright(String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(children: [
          const Text('©️', style: TextStyle(fontSize: 17)),
          const SizedBox(height: 6),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11, height: 1.8)),
        ]),
      );

  Widget _footer(Map<String, dynamic> doc) {
    final email = doc['contact_email']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        const Text('🧵', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        const Text('مشاريعنا',
            style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w900,
                fontSize: 13)),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('📬 $email',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ]),
    );
  }
}
