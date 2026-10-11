-- خطوط الرسائل في المحادثات الخاصة.
--
-- سياسة profiles للقراءة (profiles_select_owner_or_authorized) تقصر كل
-- عضو على صفّه وحده، فلم يكن للعميل أي طريق لمعرفة خط رسائل محدّثه في
-- الخاص — ولهذا كان خط الطرف الآخر لا يظهر إطلاقًا.
--
-- تُرجع الدالة مفتاح الخط وحده: حقل تجميلي لا يكشف أي بيانات خاصة.
create or replace function public.get_message_font_key(p_uid uuid)
returns text
language sql
security definer
stable
set search_path to 'public'
as $$
  select nullif(btrim(coalesce(p.message_font_key, '')), '')
  from public.profiles p
  where p.id = p_uid
$$;

revoke all on function public.get_message_font_key(uuid) from public;
grant execute on function public.get_message_font_key(uuid) to authenticated;
