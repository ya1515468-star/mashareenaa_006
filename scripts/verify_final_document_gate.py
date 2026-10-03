from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[1]
errors=[]
animals=list((ROOT/'assets/name_animations/animals').glob('animal_*.json'))
if len(animals)!=40: errors.append(f'animal count={len(animals)}')
for f in animals:
    try:
        j=json.loads(f.read_text(encoding='utf-8'))
        if j.get('nm')!=f.stem: errors.append(f'{f.name}: key mismatch')
        if j.get('meta',{}).get('transparent') is not True: errors.append(f'{f.name}: not transparent')
        dur=(float(j['op'])-float(j['ip']))/float(j['fr'])*1000
        if not 1200<=dur<=2400: errors.append(f'{f.name}: duration {dur}')
    except Exception as e: errors.append(f'{f.name}: {e}')
sp=ROOT/'lib/features/rbac/presentation/widgets/server_username_display.dart'
aw=ROOT/'lib/features/gamification/presentation/widgets/name_animation_widget.dart'
np=ROOT/'lib/features/gamification/presentation/providers/name_animation_providers.dart'
mini=ROOT/'lib/features/chat/presentation/widgets/mini_profile_popup.dart'
full=ROOT/'lib/features/profile/presentation/pages/user_profile_view_page.dart'
ad=ROOT/'lib/features/admin/presentation/pages/admin_user_titles_tab.dart'
for p in [sp,aw,np,mini,full,ad]:
    if not p.exists(): errors.append(f'missing {p}')
for p,needle in [(sp,'class ServerUsernameDisplay'),(aw,'class AnimatedNameAnimalAboveName'),(np,'nameAnimationAssetBytesProvider'),(mini,'showTitle: true'),(full,'showTitle: true'),(ad,'admin_lookup_user_identity')]:
    t=p.read_text(encoding='utf-8')
    if needle not in t: errors.append(f'{p}: missing {needle}')
text=full.read_text(encoding='utf-8')
if 'minimumSize: const Size(0, 44)' not in text: errors.append('follow/chat buttons still use unconstrained infinity minimum')
if 'Wrap(' not in text: errors.append('profile action buttons are not Wrap-constrained')
# Runtime animal rendering is GIF-only and must download the server Storage asset.
t=np.read_text(encoding='utf-8')
if "storage.from('name-animations').download(path)" not in t: errors.append('server GIF storage path missing')
if 'animation_json' in t: errors.append('legacy animation_json must not be used by runtime animal provider')
if errors: raise SystemExit('\n'.join(errors))
print('PASS static final document gate: 40 animals, canonical renderer, independent animal layer, titles, exact UID/ID, mini→full, constrained follow actions.')
