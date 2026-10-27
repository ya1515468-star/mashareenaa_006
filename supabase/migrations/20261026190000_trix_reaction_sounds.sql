-- أصوات سمايلات التركس — مولَّدة ومخزَّنة في الخادم (app_sounds) حصرًا،
-- بلا أي ملف صوت داخل مشروع التطبيق، عبر private.synth_wav_b64.
-- ✅ طُبِّقت على القاعدة الحيّة aknksnctyqjcsxcwnvdz بتاريخ 2026-10-26.
--
-- تحقُّق بعد التطبيق (كلها مرّت):
--   • 10 صفوف، md5 مطابق للبايتات المفكوكة، وترويسة RIFF/WAVE سليمة.
--   • mono / 16000Hz / 16-bit، وحجم data المعلن = الحمولة الفعلية.
--   • المدد 0.26–0.56 ثانية، والذروة 31%–65% من المدى:
--     أي لا صمت ولا قصّ (clipping).
--
-- لتغيير أي نغمة لاحقًا: أعد تنفيذ سطرها وحده — بلا تحديث للتطبيق.
-- صيغة الطبقة: {"w":موجة,"f0":تردد البداية,"f1":النهاية,"at":البدء,
--               "dur":المدة,"vol":الشدة,"decay":التخامد,"am":الارتعاش}

select private.upsert_synth_sound('react_laugh','تفاعل: ضحك 😂', '[
  {"w":"tri","f0":540,"f1":430,"at":0.00,"dur":0.075,"vol":0.45,"decay":9},
  {"w":"tri","f0":500,"f1":400,"at":0.10,"dur":0.075,"vol":0.42,"decay":9},
  {"w":"tri","f0":460,"f1":365,"at":0.20,"dur":0.075,"vol":0.39,"decay":9},
  {"w":"tri","f0":415,"f1":310,"at":0.30,"dur":0.105,"vol":0.36,"decay":8}
]'::jsonb, 0.45);

select private.upsert_synth_sound('react_wow','تفاعل: دهشة 😮', '[
  {"w":"sine","f0":300,"f1":940,"at":0.00,"dur":0.34,"vol":0.46,"decay":2.2},
  {"w":"sine","f0":600,"f1":1880,"at":0.02,"dur":0.30,"vol":0.14,"decay":3.5}
]'::jsonb, 0.38);

select private.upsert_synth_sound('react_fire','تفاعل: نار 🔥', '[
  {"w":"noise","f0":0,"f1":0,"at":0.00,"dur":0.46,"vol":0.34,"decay":6},
  {"w":"sine","f0":95,"f1":58,"at":0.00,"dur":0.40,"vol":0.40,"decay":4.5}
]'::jsonb, 0.48);

select private.upsert_synth_sound('react_clap','تفاعل: تصفيق 👏', '[
  {"w":"noise","f0":0,"f1":0,"at":0.00,"dur":0.055,"vol":0.55,"decay":34},
  {"w":"noise","f0":0,"f1":0,"at":0.095,"dur":0.055,"vol":0.50,"decay":34},
  {"w":"noise","f0":0,"f1":0,"at":0.195,"dur":0.070,"vol":0.46,"decay":28}
]'::jsonb, 0.29);

select private.upsert_synth_sound('react_cry','تفاعل: بكاء 😭', '[
  {"w":"sine","f0":760,"f1":290,"at":0.00,"dur":0.52,"vol":0.42,"decay":2.4,"am":11}
]'::jsonb, 0.55);

select private.upsert_synth_sound('react_strong','تفاعل: قوة 💪', '[
  {"w":"square","f0":155,"f1":88,"at":0.00,"dur":0.22,"vol":0.44,"decay":7},
  {"w":"noise","f0":0,"f1":0,"at":0.00,"dur":0.035,"vol":0.30,"decay":42}
]'::jsonb, 0.26);

select private.upsert_synth_sound('react_mind','تفاعل: انفجار 🤯', '[
  {"w":"sine","f0":210,"f1":1450,"at":0.00,"dur":0.24,"vol":0.38,"decay":1.5},
  {"w":"noise","f0":0,"f1":0,"at":0.23,"dur":0.32,"vol":0.46,"decay":9},
  {"w":"sine","f0":130,"f1":70,"at":0.23,"dur":0.26,"vol":0.32,"decay":7}
]'::jsonb, 0.56);

select private.upsert_synth_sound('react_think','تفاعل: تفكير 🧠', '[
  {"w":"sine","f0":880,"f1":880,"at":0.00,"dur":0.19,"vol":0.38,"decay":7},
  {"w":"sine","f0":1175,"f1":1175,"at":0.145,"dur":0.22,"vol":0.34,"decay":6}
]'::jsonb, 0.38);

select private.upsert_synth_sound('react_cool','تفاعل: أناقة 😎', '[
  {"w":"sine","f0":523,"f1":523,"at":0.00,"dur":0.20,"vol":0.36,"decay":6},
  {"w":"sine","f0":659,"f1":659,"at":0.080,"dur":0.20,"vol":0.36,"decay":6},
  {"w":"sine","f0":784,"f1":784,"at":0.160,"dur":0.26,"vol":0.38,"decay":5}
]'::jsonb, 0.44);

select private.upsert_synth_sound('react_shy','تفاعل: خجل 🙈', '[
  {"w":"tri","f0":720,"f1":430,"at":0.00,"dur":0.12,"vol":0.42,"decay":10},
  {"w":"tri","f0":540,"f1":300,"at":0.125,"dur":0.15,"vol":0.38,"decay":9}
]'::jsonb, 0.29);
