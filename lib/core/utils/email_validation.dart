/// تحقّق جدّي من صيغة البريد + كشف أخطاء النطاقات الشائعة.
///
/// سبب وجود هذا الملف: تسجيل حقيقي على القاعدة الحيّة بتاريخ 2026-10-26
/// مرّ بالعنوان `…@gmail.co` (لا `.com`). النطاق `gmail.co` غير موجود،
/// فأرسل الخادم الرسالة (ظهر حدث mail.send بلا خطأ) ولم تصل أبدًا.
/// المدقّق السابق كان يفحص وجود `@` فقط، فيقبل `a@b` أيضًا.
class EmailValidation {
  const EmailValidation._();

  // صيغة عملية: اسم محلّي معقول، نطاق بنقطة واحدة على الأقل، وامتداد
  // من حرفين أو أكثر. مقصود أن تكون أضيق من RFC 5322 الكامل، لأنّ
  // الهدف منع الأخطاء المطبعية لا قبول كل ما يسمح به المعيار.
  static final RegExp _re = RegExp(
    r"^[A-Za-z0-9](?:[A-Za-z0-9._%+\-]*[A-Za-z0-9])?"
    r"@[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?"
    r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?)*"
    r"\.[A-Za-z]{2,}$",
  );

  /// أخطاء مطبعية شائعة ⇒ النطاق الصحيح. المفتاح كما يكتبه المستخدم.
  static const Map<String, String> _typos = {
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmail.om': 'gmail.com',
    'gmail.comm': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'googlemail.co': 'googlemail.com',
    'hotmail.co': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'outlook.co': 'outlook.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'yahoo.co': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'icloud.co': 'icloud.com',
    'iclod.com': 'icloud.com',
  };

  static String domainOf(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0 || at == email.length - 1) return '';
    return email.substring(at + 1).toLowerCase();
  }

  /// النطاق الصحيح المقترح إن كان المكتوب خطأً مطبعيًا معروفًا، وإلا null.
  static String? suggestedFix(String email) {
    final d = domainOf(email.trim());
    final fixed = _typos[d];
    if (fixed == null) return null;
    return '${email.trim().substring(0, email.trim().lastIndexOf('@'))}@$fixed';
  }

  /// رسالة الخطأ بالعربية، أو null إن كان البريد مقبولًا.
  /// تُستخدم مباشرة كـvalidator في النماذج.
  static String? validate(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'الرجاء إدخال البريد الإلكتروني';
    if (v.contains(' ')) return 'البريد لا يحتوي مسافات';
    if (v.split('@').length != 2) return 'صيغة البريد الإلكتروني غير صحيحة';
    if (!_re.hasMatch(v)) {
      if (!v.contains('.', v.lastIndexOf('@'))) {
        return 'النطاق ناقص — مثال صحيح: name@gmail.com';
      }
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    final fix = suggestedFix(v);
    if (fix != null) {
      return 'هل تقصد $fix ؟ النطاق المكتوب غير موجود فلن تصل الرسالة.';
    }
    return null;
  }
}
