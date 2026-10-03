from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
registry=(ROOT/'lib/features/store/presentation/widgets/visual_effect_config.dart').read_text()
painter=(ROOT/'lib/features/store/presentation/widgets/visual_effect_painter.dart').read_text()
engine=(ROOT/'lib/features/store/presentation/widgets/visual_effect_engine.dart').read_text()
support=(ROOT/'lib/features/store/presentation/widgets/effect_engine_support.dart').read_text()
migration=(ROOT/'supabase/migrations/20260906120000_effects_engine_50_owner_unlimited_hardening.sql').read_text()
migdir=ROOT/'supabase/migrations'
strict_migration=(migdir/'20260906141918_strict_completion_membership_security.sql').read_text()
strict_matrix=(migdir/'20260906141936_strict_completion_membership_matrix_repair.sql').read_text()
strict_admin=(migdir/'20260906142031_strict_completion_vip_membership_rules.sql').read_text()
strict_preserve=(migdir/'20260906142224_strict_completion_membership_admin_preserve_rules.sql').read_text()
strict_security=(migdir/'20260906142228_strict_completion_security_helper_execute_hardening.sql').read_text()
strict_admin_read=(migdir/'20260906142601_strict_completion_admin_rules_read_and_seed_fix.sql').read_text()
legacy_retire=(migdir/'20260906142721_strict_completion_retire_legacy_cosmetic_purchase_rpc.sql').read_text()
owner_claim=(migdir/'20260906142811_strict_completion_harden_owner_claim_and_drop_legacy_rpc.sql').read_text()
admin=(ROOT/'lib/features/admin/presentation/pages/dragon_control_tab.dart').read_text()
store=(ROOT/'lib/features/subscriptions/presentation/widgets/membership_store_tab.dart').read_text()

reg=set(re.findall(r"^\s*'([^']+)':\s*VisualEffectConfig", registry, re.M))
cases=set(re.findall(r"case '([^']+)'", painter))
meta=set(re.findall(r"'effect_key'\s*:\s*'([^']+)'", migration))
seed=set(re.findall(r"values \('visualfx_([^']+)'", migration))
checks=[]
def check(name, ok, detail): checks.append((name,ok,detail))
check('registry_50', len(reg)==50, f'{len(reg)}')
check('registry_unique', len(reg)==50, f'{len(reg)} unique')
check('painter_50', len(cases)==50, f'{len(cases)}')
check('registry_to_painter', reg==cases, f'missing={sorted(reg-cases)}, extra={sorted(cases-reg)}')
check('sql_new_20', len(seed)==20, f'{len(seed)}')
check('sql_new_unique', len(seed)==20, f'{len(seed)} unique')
check('sql_has_all_new', all(k in migration for k in [f"visualfx_{x}" for x in seed]), 'catalog keys present')
check('migration_hardens_purchase', 'create or replace function public.purchase_profile_cosmetic' in migration, 'purchase RPC replacement present')
check('migration_hardens_gift', 'create or replace function public.send_gift_atomic' in migration, 'gift RPC replacement present')
check('server_owner_authority', 'public.is_platform_owner(v_uid)' in migration, 'server authority helper used')

owner_flag_patterns=[r'owner.*unlimited.*(?:true|false)',r'balance.*unlimited.*999999',r'999999999999999',r'999999999']
lib_text='\n'.join(q.read_text(errors='ignore') for q in (ROOT/'lib').rglob('*.dart'))
check('no_client_balance_owner_flag', not any(re.search(p, lib_text, re.I) for p in owner_flag_patterns), 'no client-side owner/unlimited numeric bypass detected')
check('engine_uses_registry', 'EffectEngine' in engine and 'resolve(widget.effectKey, widget.quality)' in engine and 'VisualEffectRegistry.get' in support, 'central engine resolves registry through cache')
check('engine_animation_controller', 'AnimationController' in engine and '..repeat()' in engine, 'continuous animation active')
check('no_banned_placeholders_effect_scope', not any(tok in (registry+painter+migration+support).upper() for tok in ['FIXME','MOCK','DUMMY','PLACEHOLDER','COMING SOON','UNIMPLEMENTED']), 'no banned placeholder tokens')
required=['"animation":true','"renderer":"custom_painter"','"engine":"custom_painter"','"duration_ms":2400','"supported_targets":["username","avatar","both"]']
check('new_catalog_runtime_metadata', all(x in migration for x in required), 'core metadata present')
econ='\n'.join([migration,(ROOT/'lib/features/store/presentation/profile_cosmetic_store_page.dart').read_text()])
check('no_hardcoded_unlimited_constant', not re.search(r'999999999999999|999999999', econ), 'no huge numeric unlimited substitute in effect economy scope')
check('strict_membership_catalog', 'subscription_tier_service_rules' in strict_migration and "'ultimate'" in strict_migration, 'membership/service matrix migration present')
check('strict_membership_runtime_expiry', '_active_membership_tier_id' in strict_migration and 'expiresAt' in strict_migration, 'server-time expiry resolver present')
check('strict_membership_matrix_36', "('ultimate',36)" in strict_matrix and 'row_number()' in strict_matrix, 'all 36 services are rank-mapped despite sparse catalog sort_order')
check('strict_sensitive_rpc_auth_surface', 'revoke all on function public.purchase_membership' in strict_migration and 'grant execute on function public.purchase_membership' in strict_migration, 'sensitive RPCs restricted to authenticated role')
check('owner_admin_ui_real_rpc', 'admin_upsert_membership_tier' in admin and 'admin_set_membership_service_rule' in admin, 'owner UI writes membership configuration through server RPCs')
check('membership_ui_dynamic_catalog', '_membershipCatalogProvider' in store and 'subscription_tiers' in store, 'membership store is server-catalog driven')
check('vip_admin_rule_rpc', 'admin_set_membership_service_rule' in strict_admin, 'per-service membership rule RPC exists')
check('membership_edit_preserves_rules', 'if not v_exists then' in strict_preserve and 'subscription_tier_service_rules' in strict_preserve, 'editing an existing membership does not silently reset custom service mapping')
check('membership_rule_read_owner_only', 'admin_get_membership_service_rules' in strict_admin_read and 'public.is_my_platform_owner()' in strict_admin_read, 'rule reads are owner-gated through RPC')
check('legacy_client_priced_rpc_retired', 'revoke all on function public.purchase_and_equip_vip_cosmetic' in legacy_retire, 'obsolete client-priced purchase path is revoked')
check('owner_claim_search_path_hardened', "set search_path=''" in owner_claim and 'purchase_and_equip_vip_cosmetic' in owner_claim, 'owner claim is hardened and legacy RPC is removed')
failed=[c for c in checks if not c[1]]
for name,ok,detail in checks: print(('PASS' if ok else 'FAIL'), name, '-', detail)
print('TOTAL',len(checks),'PASSED',len(checks)-len(failed),'FAILED',len(failed))
if failed: sys.exit(1)
