-- Username typography default: smaller, compact chat-friendly size.
-- Existing explicitly saved values are preserved.
alter table public.profiles
  alter column username_font_size set default 16;

-- Client-side and server identity fallbacks in this release also use 16px.
