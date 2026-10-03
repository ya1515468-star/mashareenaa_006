from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
errors = []

animals = list((ROOT / 'assets/name_animations/animals').glob('animal_*.json'))
if len(animals) != 40:
    errors.append(f'expected 40 local source animals, found {len(animals)}')
for f in animals:
    try:
        j = json.loads(f.read_text(encoding='utf-8'))
        if j.get('nm') != f.stem:
            errors.append(f'{f.name}: key mismatch')
        if j.get('meta', {}).get('transparent') is not True:
            errors.append(f'{f.name}: transparent contract missing')
        dur = ((float(j['op'])-float(j['ip']))/float(j['fr']))*1000
        if not 1200 <= dur <= 2400:
            errors.append(f'{f.name}: duration={dur}')
    except Exception as exc:
        errors.append(f'{f.name}: invalid JSON: {exc}')

server_widget = (ROOT / 'lib/features/rbac/presentation/widgets/server_username_display.dart').read_text()
animal_widget = (ROOT / 'lib/features/gamification/presentation/widgets/name_animation_widget.dart').read_text()
mini = (ROOT / 'lib/features/chat/presentation/widgets/mini_profile_popup.dart').read_text()
full = (ROOT / 'lib/features/profile/presentation/pages/user_profile_view_page.dart').read_text()
admin = (ROOT / 'lib/features/admin/presentation/pages/admin_user_titles_tab.dart').read_text()

for label, text, needle in [
    ('canonical username renderer', server_widget, 'class ServerUsernameDisplay'),
    ('independent animal widget', animal_widget, 'class AnimatedNameAnimalAboveName'),
    ('mini target uid flow', (mini + full + (ROOT / 'lib/features/chat/presentation/pages/chat_lobby_page.dart').read_text()), 'MiniProfilePopup.show'),
    ('full profile title', full, 'showTitle: true'),
    ('admin exact lookup', admin, "admin_lookup_user_identity"),
]:
    if needle not in text:
        errors.append(f'{label}: missing {needle}')

if 'showTitle = false' not in server_widget or 'showTitle: true' not in mini or 'showTitle: true' not in full:
    errors.append('title visibility contract not explicit')

if errors:
    raise SystemExit('\n'.join(errors))
print(f'PASS static strict checks: {len(animals)} source animals; canonical renderer; isolated animal layer; exact UID/ID admin lookup; title surfaces.')
