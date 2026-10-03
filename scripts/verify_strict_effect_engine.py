from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
config=(ROOT/'lib/features/store/presentation/widgets/visual_effect_config.dart').read_text()
painter=(ROOT/'lib/features/store/presentation/widgets/visual_effect_painter.dart').read_text()
engine=(ROOT/'lib/features/store/presentation/widgets/effect_engine_support.dart').read_text()
test=(ROOT/'test/visual_effect_registry_test.dart').read_text()

keys=re.findall(r"'([a-z0-9_]+)': VisualEffectConfig\(",config)
cases=re.findall(r"case '([a-z0-9_]+)':",painter)
result={}
result['registry_50']=len(keys)==50
result['registry_unique']=len(set(keys))==50
result['painter_covers_registry']=set(keys)<=set(cases)
result['quality_ultra']='VisualEffectQuality { low, medium, high, ultra }' in config
for name in ['EffectEngine','EffectRegistry','EffectDefinition','EffectController','EffectRenderer','ParticleSystem','LayerManager','AnimationTimeline','EffectCache','EffectPool','QualityManager','AudioManager','ServerEffectRepository']:
    result[f'engine_component_{name}']=name in engine
result['test_targets_50']='exactly the 50 contracted effect keys' in test
print('STRICT EFFECT ENGINE CONTRACT')
for k,v in result.items(): print(('PASS' if v else 'FAIL'), k)
failed=[k for k,v in result.items() if not v]
print(f'TOTAL {len(result)-len(failed)} PASSED {len(failed)} FAILED')
raise SystemExit(1 if failed else 0)
