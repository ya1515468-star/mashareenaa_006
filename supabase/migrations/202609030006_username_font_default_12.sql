-- MASHAREENA: username font default lowered to 12px.
-- Preserve users who intentionally chose a non-default size; only migrate the previous 16px default.

alter table public.profiles
  alter column username_font_size set default 12;

update public.profiles
set username_font_size = 12
where username_font_size = 16;
