-- حذف نهائي للنسخ المكرّرة بطلب المالك («ان كانت تكرارا احذفها بلا عوده»).
-- التحقق قبل الحذف:
--  • خلفيات إطار الاسم: 38 صفًا غير مفعّل، كلٌّ منها مطابق تمامًا لصف مفعّل
--    (نفس animation_mode + color1 + color2).
--  • قوالب الاسم: 37 صفًا غير مفعّل؛ مقارنة الصور بكسلًا ببكسل أثبتت أنها
--    نسخ شبه مطابقة (فرق < 5/255) لتسعة تصاميم مفعّلة. حُذفت ملفات صورها
--    من التطبيق أيضًا.
--  • لا توجد أي مشتريات (profile_cosmetic_purchases) ولا أي مستخدم يستعمل
--    أيًّا منها، فلا يتأثر أحد.
delete from public.profile_cosmetic_catalog c
 where c.is_active = false
   and c.category = 'background'
   and exists (
     select 1 from public.profile_cosmetic_catalog a
      where a.is_active and a.category = 'background'
        and coalesce(a.animation_mode,'') = coalesce(c.animation_mode,'')
        and coalesce(a.color1,'') = coalesce(c.color1,'')
        and coalesce(a.color2,'') = coalesce(c.color2,''));

delete from public.profile_cosmetic_catalog c
 where c.is_active = false
   and c.category = 'name_template'
   and c.item_key not in ('name_template_01','name_template_03','name_template_04',
                          'name_template_05','name_template_06','name_template_07',
                          'name_template_08','name_template_09','name_template_12');

-- بقايا فحص قديم من بداية الجلسة.
drop table if exists public._probe_ddl_check;
