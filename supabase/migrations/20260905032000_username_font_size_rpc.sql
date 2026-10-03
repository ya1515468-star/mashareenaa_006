-- Server-authoritative username font-size update.
-- Only the authenticated owner of the profile can change this value.
create or replace function public.set_my_username_font_size(p_font_size numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if p_font_size is null or p_font_size < 8 or p_font_size > 26 then
    raise exception 'USERNAME_FONT_SIZE_OUT_OF_RANGE';
  end if;

  update public.profiles
  set username_font_size = round(p_font_size, 1),
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'PROFILE_NOT_FOUND';
  end if;
end;
$$;

grant execute on function public.set_my_username_font_size(numeric) to authenticated;
revoke execute on function public.set_my_username_font_size(numeric) from anon;
