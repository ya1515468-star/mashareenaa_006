begin;

create temporary table tmp_big_store_seed (
    section_id bigint,
    code text,
    name text,
    item_type text,
    asset_url text,
    rarity text,
    is_featured boolean,
    sku text,
    price_points bigint,
    price_gems bigint
) on commit drop;

insert into tmp_big_store_seed (
    section_id,
    code,
    name,
    item_type,
    asset_url,
    rarity,
    is_featured,
    sku,
    price_points,
    price_gems
)
values
    (2, 'big_glow_01', 'توهج ذهبي ملكي', 'username_glow', 'assets/store_gifs/glow/glow_01.gif', 'common', true, 'MSH-GLOW-01', 175, 0),
    (2, 'big_glow_02', 'توهج بنفسجي نيون', 'username_glow', 'assets/store_gifs/glow/glow_02.gif', 'common', true, 'MSH-GLOW-02', 200, 0),
    (2, 'big_glow_03', 'توهج وردي رومانسي', 'username_glow', 'assets/store_gifs/glow/glow_03.gif', 'common', true, 'MSH-GLOW-03', 225, 0),
    (2, 'big_glow_04', 'توهج أزرق جليدي', 'username_glow', 'assets/store_gifs/glow/glow_04.gif', 'common', true, 'MSH-GLOW-04', 250, 0),
    (2, 'big_glow_05', 'توهج ناري', 'username_glow', 'assets/store_gifs/glow/glow_05.gif', 'common', true, 'MSH-GLOW-05', 275, 0),
    (2, 'big_glow_06', 'توهج ماسي', 'username_glow', 'assets/store_gifs/glow/glow_06.gif', 'common', true, 'MSH-GLOW-06', 300, 0),
    (2, 'big_glow_07', 'توهج فضي معدني', 'username_glow', 'assets/store_gifs/glow/glow_07.gif', 'common', true, 'MSH-GLOW-07', 325, 0),
    (2, 'big_glow_08', 'توهج قوس قزح', 'username_glow', 'assets/store_gifs/glow/glow_08.gif', 'common', true, 'MSH-GLOW-08', 350, 0),
    (2, 'big_glow_09', 'توهج نجمي', 'username_glow', 'assets/store_gifs/glow/glow_09.gif', 'common', false, 'MSH-GLOW-09', 375, 0),
    (2, 'big_glow_10', 'توهج ملكي أحمر', 'username_glow', 'assets/store_gifs/glow/glow_10.gif', 'common', false, 'MSH-GLOW-10', 400, 0),
    (2, 'big_glow_11', 'توهج سماوي', 'username_glow', 'assets/store_gifs/glow/glow_11.gif', 'rare', false, 'MSH-GLOW-11', 425, 0),
    (2, 'big_glow_12', 'توهج زمردي', 'username_glow', 'assets/store_gifs/glow/glow_12.gif', 'rare', false, 'MSH-GLOW-12', 450, 0),
    (2, 'big_glow_13', 'توهج كريستالي', 'username_glow', 'assets/store_gifs/glow/glow_13.gif', 'rare', false, 'MSH-GLOW-13', 475, 0),
    (2, 'big_glow_14', 'توهج ليلي', 'username_glow', 'assets/store_gifs/glow/glow_14.gif', 'rare', false, 'MSH-GLOW-14', 500, 0),
    (2, 'big_glow_15', 'توهج شمسي', 'username_glow', 'assets/store_gifs/glow/glow_15.gif', 'rare', false, 'MSH-GLOW-15', 525, 0),
    (2, 'big_glow_16', 'توهج قمري', 'username_glow', 'assets/store_gifs/glow/glow_16.gif', 'rare', false, 'MSH-GLOW-16', 550, 0),
    (2, 'big_glow_17', 'توهج كهربائي', 'username_glow', 'assets/store_gifs/glow/glow_17.gif', 'rare', false, 'MSH-GLOW-17', 575, 0),
    (2, 'big_glow_18', 'توهج دخاني', 'username_glow', 'assets/store_gifs/glow/glow_18.gif', 'rare', false, 'MSH-GLOW-18', 600, 0),
    (2, 'big_glow_19', 'توهج ملكة', 'username_glow', 'assets/store_gifs/glow/glow_19.gif', 'rare', false, 'MSH-GLOW-19', 625, 0),
    (2, 'big_glow_20', 'توهج ملك', 'username_glow', 'assets/store_gifs/glow/glow_20.gif', 'rare', false, 'MSH-GLOW-20', 650, 0),
    (2, 'big_glow_21', 'توهج تنين', 'username_glow', 'assets/store_gifs/glow/glow_21.gif', 'rare', false, 'MSH-GLOW-21', 675, 0),
    (2, 'big_glow_22', 'توهج ملاك', 'username_glow', 'assets/store_gifs/glow/glow_22.gif', 'rare', false, 'MSH-GLOW-22', 700, 0),
    (2, 'big_glow_23', 'توهج شيطاني', 'username_glow', 'assets/store_gifs/glow/glow_23.gif', 'rare', false, 'MSH-GLOW-23', 725, 0),
    (2, 'big_glow_24', 'توهج بحري', 'username_glow', 'assets/store_gifs/glow/glow_24.gif', 'rare', false, 'MSH-GLOW-24', 750, 0),
    (2, 'big_glow_25', 'توهج زهري', 'username_glow', 'assets/store_gifs/glow/glow_25.gif', 'rare', false, 'MSH-GLOW-25', 775, 0),
    (2, 'big_glow_26', 'توهج موسيقي', 'username_glow', 'assets/store_gifs/glow/glow_26.gif', 'epic', false, 'MSH-GLOW-26', 800, 0),
    (2, 'big_glow_27', 'توهج فراشة', 'username_glow', 'assets/store_gifs/glow/glow_27.gif', 'epic', false, 'MSH-GLOW-27', 825, 0),
    (2, 'big_glow_28', 'توهج ملكي أسود', 'username_glow', 'assets/store_gifs/glow/glow_28.gif', 'epic', false, 'MSH-GLOW-28', 850, 0),
    (2, 'big_glow_29', 'توهج فضائي', 'username_glow', 'assets/store_gifs/glow/glow_29.gif', 'epic', false, 'MSH-GLOW-29', 875, 0),
    (2, 'big_glow_30', 'توهج نيزكي', 'username_glow', 'assets/store_gifs/glow/glow_30.gif', 'epic', false, 'MSH-GLOW-30', 900, 0),
    (2, 'big_glow_31', 'توهج زجاجي', 'username_glow', 'assets/store_gifs/glow/glow_31.gif', 'epic', false, 'MSH-GLOW-31', 925, 0),
    (2, 'big_glow_32', 'توهج لهبي أزرق', 'username_glow', 'assets/store_gifs/glow/glow_32.gif', 'epic', false, 'MSH-GLOW-32', 950, 0),
    (2, 'big_glow_33', 'توهج لؤلؤي', 'username_glow', 'assets/store_gifs/glow/glow_33.gif', 'epic', false, 'MSH-GLOW-33', 975, 0),
    (2, 'big_glow_34', 'توهج صحراوي', 'username_glow', 'assets/store_gifs/glow/glow_34.gif', 'epic', false, 'MSH-GLOW-34', 1000, 0),
    (2, 'big_glow_35', 'توهج غابة', 'username_glow', 'assets/store_gifs/glow/glow_35.gif', 'epic', false, 'MSH-GLOW-35', 1025, 0),
    (2, 'big_glow_36', 'توهج مائي', 'username_glow', 'assets/store_gifs/glow/glow_36.gif', 'legendary', false, 'MSH-GLOW-36', 1050, 0),
    (2, 'big_glow_37', 'توهج ملكي مزدوج', 'username_glow', 'assets/store_gifs/glow/glow_37.gif', 'legendary', false, 'MSH-GLOW-37', 1075, 0),
    (2, 'big_glow_38', 'توهج قلب نابض', 'username_glow', 'assets/store_gifs/glow/glow_38.gif', 'legendary', false, 'MSH-GLOW-38', 1100, 0),
    (2, 'big_glow_39', 'توهج تاج', 'username_glow', 'assets/store_gifs/glow/glow_39.gif', 'legendary', false, 'MSH-GLOW-39', 1125, 0),
    (2, 'big_glow_40', 'توهج سيف', 'username_glow', 'assets/store_gifs/glow/glow_40.gif', 'legendary', false, 'MSH-GLOW-40', 1150, 0),
    (2, 'big_glow_41', 'توهج مخملي', 'username_glow', 'assets/store_gifs/glow/glow_41.gif', 'legendary', false, 'MSH-GLOW-41', 1175, 0),
    (2, 'big_glow_42', 'توهج كرنفالي', 'username_glow', 'assets/store_gifs/glow/glow_42.gif', 'legendary', false, 'MSH-GLOW-42', 1200, 0),
    (2, 'big_glow_43', 'توهج ثلجي', 'username_glow', 'assets/store_gifs/glow/glow_43.gif', 'legendary', false, 'MSH-GLOW-43', 1225, 0),
    (2, 'big_glow_44', 'توهج عاصفة', 'username_glow', 'assets/store_gifs/glow/glow_44.gif', 'legendary', false, 'MSH-GLOW-44', 1250, 0),
    (2, 'big_glow_45', 'توهج وردة ذهبية', 'username_glow', 'assets/store_gifs/glow/glow_45.gif', 'legendary', false, 'MSH-GLOW-45', 1275, 0),
    (2, 'big_glow_46', 'توهج أسطوري', 'username_glow', 'assets/store_gifs/glow/glow_46.gif', 'mythic', false, 'MSH-GLOW-46', 1300, 0),
    (2, 'big_glow_47', 'توهج تنفسي', 'username_glow', 'assets/store_gifs/glow/glow_47.gif', 'mythic', false, 'MSH-GLOW-47', 1325, 0),
    (2, 'big_glow_48', 'توهج مخفي', 'username_glow', 'assets/store_gifs/glow/glow_48.gif', 'mythic', false, 'MSH-GLOW-48', 1350, 0),
    (2, 'big_glow_49', 'توهج احترافي', 'username_glow', 'assets/store_gifs/glow/glow_49.gif', 'mythic', false, 'MSH-GLOW-49', 1375, 0),
    (2, 'big_glow_50', 'توهج إمبراطوري', 'username_glow', 'assets/store_gifs/glow/glow_50.gif', 'mythic', false, 'MSH-GLOW-50', 1400, 0),
    (3, 'big_frame_01', 'إطار تاج ذهبي', 'avatar_frame', 'assets/store_gifs/frame/frame_01.gif', 'common', true, 'MSH-FRAME-01', 175, 0),
    (3, 'big_frame_02', 'إطار ناري', 'avatar_frame', 'assets/store_gifs/frame/frame_02.gif', 'common', true, 'MSH-FRAME-02', 200, 0),
    (3, 'big_frame_03', 'إطار ماسي', 'avatar_frame', 'assets/store_gifs/frame/frame_03.gif', 'common', true, 'MSH-FRAME-03', 225, 0),
    (3, 'big_frame_04', 'إطار فضي', 'avatar_frame', 'assets/store_gifs/frame/frame_04.gif', 'common', true, 'MSH-FRAME-04', 250, 0),
    (3, 'big_frame_05', 'إطار بنفسجي نيون', 'avatar_frame', 'assets/store_gifs/frame/frame_05.gif', 'common', true, 'MSH-FRAME-05', 275, 0),
    (3, 'big_frame_06', 'إطار وردي', 'avatar_frame', 'assets/store_gifs/frame/frame_06.gif', 'common', true, 'MSH-FRAME-06', 300, 0),
    (3, 'big_frame_07', 'إطار أجنحة', 'avatar_frame', 'assets/store_gifs/frame/frame_07.gif', 'common', true, 'MSH-FRAME-07', 325, 0),
    (3, 'big_frame_08', 'إطار ملكي أحمر', 'avatar_frame', 'assets/store_gifs/frame/frame_08.gif', 'common', true, 'MSH-FRAME-08', 350, 0),
    (3, 'big_frame_09', 'إطار أسود ذهبي', 'avatar_frame', 'assets/store_gifs/frame/frame_09.gif', 'common', false, 'MSH-FRAME-09', 375, 0),
    (3, 'big_frame_10', 'إطار قلوب', 'avatar_frame', 'assets/store_gifs/frame/frame_10.gif', 'common', false, 'MSH-FRAME-10', 400, 0),
    (3, 'big_frame_11', 'إطار نجوم', 'avatar_frame', 'assets/store_gifs/frame/frame_11.gif', 'rare', false, 'MSH-FRAME-11', 425, 0),
    (3, 'big_frame_12', 'إطار كريستال', 'avatar_frame', 'assets/store_gifs/frame/frame_12.gif', 'rare', false, 'MSH-FRAME-12', 450, 0),
    (3, 'big_frame_13', 'إطار ثلجي', 'avatar_frame', 'assets/store_gifs/frame/frame_13.gif', 'rare', false, 'MSH-FRAME-13', 475, 0),
    (3, 'big_frame_14', 'إطار بحري', 'avatar_frame', 'assets/store_gifs/frame/frame_14.gif', 'rare', false, 'MSH-FRAME-14', 500, 0),
    (3, 'big_frame_15', 'إطار زهري', 'avatar_frame', 'assets/store_gifs/frame/frame_15.gif', 'rare', false, 'MSH-FRAME-15', 525, 0),
    (3, 'big_frame_16', 'إطار موسيقي', 'avatar_frame', 'assets/store_gifs/frame/frame_16.gif', 'rare', false, 'MSH-FRAME-16', 550, 0),
    (3, 'big_frame_17', 'إطار فراشة', 'avatar_frame', 'assets/store_gifs/frame/frame_17.gif', 'rare', false, 'MSH-FRAME-17', 575, 0),
    (3, 'big_frame_18', 'إطار برق', 'avatar_frame', 'assets/store_gifs/frame/frame_18.gif', 'rare', false, 'MSH-FRAME-18', 600, 0),
    (3, 'big_frame_19', 'إطار تنين', 'avatar_frame', 'assets/store_gifs/frame/frame_19.gif', 'rare', false, 'MSH-FRAME-19', 625, 0),
    (3, 'big_frame_20', 'إطار ملاك', 'avatar_frame', 'assets/store_gifs/frame/frame_20.gif', 'rare', false, 'MSH-FRAME-20', 650, 0),
    (3, 'big_frame_21', 'إطار سحري', 'avatar_frame', 'assets/store_gifs/frame/frame_21.gif', 'rare', false, 'MSH-FRAME-21', 675, 0),
    (3, 'big_frame_22', 'إطار قمر', 'avatar_frame', 'assets/store_gifs/frame/frame_22.gif', 'rare', false, 'MSH-FRAME-22', 700, 0),
    (3, 'big_frame_23', 'إطار شمس', 'avatar_frame', 'assets/store_gifs/frame/frame_23.gif', 'rare', false, 'MSH-FRAME-23', 725, 0),
    (3, 'big_frame_24', 'إطار لؤلؤ', 'avatar_frame', 'assets/store_gifs/frame/frame_24.gif', 'rare', false, 'MSH-FRAME-24', 750, 0),
    (3, 'big_frame_25', 'إطار زمرد', 'avatar_frame', 'assets/store_gifs/frame/frame_25.gif', 'rare', false, 'MSH-FRAME-25', 775, 0),
    (3, 'big_frame_26', 'إطار ياقوت', 'avatar_frame', 'assets/store_gifs/frame/frame_26.gif', 'epic', false, 'MSH-FRAME-26', 800, 0),
    (3, 'big_frame_27', 'إطار فيروزي', 'avatar_frame', 'assets/store_gifs/frame/frame_27.gif', 'epic', false, 'MSH-FRAME-27', 825, 0),
    (3, 'big_frame_28', 'إطار رخامي', 'avatar_frame', 'assets/store_gifs/frame/frame_28.gif', 'epic', false, 'MSH-FRAME-28', 850, 0),
    (3, 'big_frame_29', 'إطار مخملي', 'avatar_frame', 'assets/store_gifs/frame/frame_29.gif', 'epic', false, 'MSH-FRAME-29', 875, 0),
    (3, 'big_frame_30', 'إطار حديدي', 'avatar_frame', 'assets/store_gifs/frame/frame_30.gif', 'epic', false, 'MSH-FRAME-30', 900, 0),
    (3, 'big_frame_31', 'إطار عربي', 'avatar_frame', 'assets/store_gifs/frame/frame_31.gif', 'epic', false, 'MSH-FRAME-31', 925, 0),
    (3, 'big_frame_32', 'إطار هندسي', 'avatar_frame', 'assets/store_gifs/frame/frame_32.gif', 'epic', false, 'MSH-FRAME-32', 950, 0),
    (3, 'big_frame_33', 'إطار دائري مزدوج', 'avatar_frame', 'assets/store_gifs/frame/frame_33.gif', 'epic', false, 'MSH-FRAME-33', 975, 0),
    (3, 'big_frame_34', 'إطار ثلاثي الطبقات', 'avatar_frame', 'assets/store_gifs/frame/frame_34.gif', 'epic', false, 'MSH-FRAME-34', 1000, 0),
    (3, 'big_frame_35', 'إطار متحرك', 'avatar_frame', 'assets/store_gifs/frame/frame_35.gif', 'epic', false, 'MSH-FRAME-35', 1025, 0),
    (3, 'big_frame_36', 'إطار شارة', 'avatar_frame', 'assets/store_gifs/frame/frame_36.gif', 'legendary', false, 'MSH-FRAME-36', 1050, 0),
    (3, 'big_frame_37', 'إطار كأس', 'avatar_frame', 'assets/store_gifs/frame/frame_37.gif', 'legendary', false, 'MSH-FRAME-37', 1075, 0),
    (3, 'big_frame_38', 'إطار ملوك', 'avatar_frame', 'assets/store_gifs/frame/frame_38.gif', 'legendary', false, 'MSH-FRAME-38', 1100, 0),
    (3, 'big_frame_39', 'إطار أميرات', 'avatar_frame', 'assets/store_gifs/frame/frame_39.gif', 'legendary', false, 'MSH-FRAME-39', 1125, 0),
    (3, 'big_frame_40', 'إطار أسطوري', 'avatar_frame', 'assets/store_gifs/frame/frame_40.gif', 'legendary', false, 'MSH-FRAME-40', 1150, 0),
    (3, 'big_frame_41', 'إطار ألعاب', 'avatar_frame', 'assets/store_gifs/frame/frame_41.gif', 'legendary', false, 'MSH-FRAME-41', 1175, 0),
    (3, 'big_frame_42', 'إطار دعم', 'avatar_frame', 'assets/store_gifs/frame/frame_42.gif', 'legendary', false, 'MSH-FRAME-42', 1200, 0),
    (3, 'big_frame_43', 'إطار مشرف', 'avatar_frame', 'assets/store_gifs/frame/frame_43.gif', 'legendary', false, 'MSH-FRAME-43', 1225, 0),
    (3, 'big_frame_44', 'إطار إدارة', 'avatar_frame', 'assets/store_gifs/frame/frame_44.gif', 'legendary', false, 'MSH-FRAME-44', 1250, 0),
    (3, 'big_frame_45', 'إطار متصل', 'avatar_frame', 'assets/store_gifs/frame/frame_45.gif', 'legendary', false, 'MSH-FRAME-45', 1275, 0),
    (3, 'big_frame_46', 'إطار غامض', 'avatar_frame', 'assets/store_gifs/frame/frame_46.gif', 'mythic', false, 'MSH-FRAME-46', 1300, 0),
    (3, 'big_frame_47', 'إطار احتفالي', 'avatar_frame', 'assets/store_gifs/frame/frame_47.gif', 'mythic', false, 'MSH-FRAME-47', 1325, 0),
    (3, 'big_frame_48', 'إطار بسيط فاخر', 'avatar_frame', 'assets/store_gifs/frame/frame_48.gif', 'mythic', false, 'MSH-FRAME-48', 1350, 0),
    (3, 'big_frame_49', 'إطار VIP كبير', 'avatar_frame', 'assets/store_gifs/frame/frame_49.gif', 'mythic', false, 'MSH-FRAME-49', 1375, 0),
    (3, 'big_frame_50', 'إطار SSSVIP', 'avatar_frame', 'assets/store_gifs/frame/frame_50.gif', 'mythic', false, 'MSH-FRAME-50', 1400, 0),
    (4, 'big_background_01', 'سماء بنفسجية نجمية', 'animated_background', 'assets/store_gifs/background/background_01.gif', 'common', true, 'MSH-BACKGROUND-01', 175, 0),
    (4, 'big_background_02', 'دخان ملكي', 'animated_background', 'assets/store_gifs/background/background_02.gif', 'common', true, 'MSH-BACKGROUND-02', 200, 0),
    (4, 'big_background_03', 'أمواج ضوئية', 'animated_background', 'assets/store_gifs/background/background_03.gif', 'common', true, 'MSH-BACKGROUND-03', 225, 0),
    (4, 'big_background_04', 'ألماس متلألئ', 'animated_background', 'assets/store_gifs/background/background_04.gif', 'common', true, 'MSH-BACKGROUND-04', 250, 0),
    (4, 'big_background_05', 'مطر ذهبي', 'animated_background', 'assets/store_gifs/background/background_05.gif', 'common', true, 'MSH-BACKGROUND-05', 275, 0),
    (4, 'big_background_06', 'شبكة نيون', 'animated_background', 'assets/store_gifs/background/background_06.gif', 'common', true, 'MSH-BACKGROUND-06', 300, 0),
    (4, 'big_background_07', 'غبار فضائي', 'animated_background', 'assets/store_gifs/background/background_07.gif', 'common', true, 'MSH-BACKGROUND-07', 325, 0),
    (4, 'big_background_08', 'خلفية قلوب', 'animated_background', 'assets/store_gifs/background/background_08.gif', 'common', true, 'MSH-BACKGROUND-08', 350, 0),
    (4, 'big_background_09', 'خلفية فراشات', 'animated_background', 'assets/store_gifs/background/background_09.gif', 'common', false, 'MSH-BACKGROUND-09', 375, 0),
    (4, 'big_background_10', 'خلفية نيران', 'animated_background', 'assets/store_gifs/background/background_10.gif', 'common', false, 'MSH-BACKGROUND-10', 400, 0),
    (4, 'big_background_11', 'خلفية جليدية', 'animated_background', 'assets/store_gifs/background/background_11.gif', 'rare', false, 'MSH-BACKGROUND-11', 425, 0),
    (4, 'big_background_12', 'خلفية بحرية', 'animated_background', 'assets/store_gifs/background/background_12.gif', 'rare', false, 'MSH-BACKGROUND-12', 450, 0),
    (4, 'big_background_13', 'خلفية غروب', 'animated_background', 'assets/store_gifs/background/background_13.gif', 'rare', false, 'MSH-BACKGROUND-13', 475, 0),
    (4, 'big_background_14', 'خلفية ليل ملكي', 'animated_background', 'assets/store_gifs/background/background_14.gif', 'rare', false, 'MSH-BACKGROUND-14', 500, 0),
    (4, 'big_background_15', 'خلفية ذهبية فاخرة', 'animated_background', 'assets/store_gifs/background/background_15.gif', 'rare', false, 'MSH-BACKGROUND-15', 525, 0),
    (4, 'big_background_16', 'خلفية رخام', 'animated_background', 'assets/store_gifs/background/background_16.gif', 'rare', false, 'MSH-BACKGROUND-16', 550, 0),
    (4, 'big_background_17', 'خلفية مخملية', 'animated_background', 'assets/store_gifs/background/background_17.gif', 'rare', false, 'MSH-BACKGROUND-17', 575, 0),
    (4, 'big_background_18', 'خلفية قصر', 'animated_background', 'assets/store_gifs/background/background_18.gif', 'rare', false, 'MSH-BACKGROUND-18', 600, 0),
    (4, 'big_background_19', 'خلفية مدينة ليلية', 'animated_background', 'assets/store_gifs/background/background_19.gif', 'rare', false, 'MSH-BACKGROUND-19', 625, 0),
    (4, 'big_background_20', 'خلفية كواكب', 'animated_background', 'assets/store_gifs/background/background_20.gif', 'rare', false, 'MSH-BACKGROUND-20', 650, 0),
    (4, 'big_background_21', 'خلفية برق', 'animated_background', 'assets/store_gifs/background/background_21.gif', 'rare', false, 'MSH-BACKGROUND-21', 675, 0),
    (4, 'big_background_22', 'خلفية ورود', 'animated_background', 'assets/store_gifs/background/background_22.gif', 'rare', false, 'MSH-BACKGROUND-22', 700, 0),
    (4, 'big_background_23', 'خلفية موسيقية', 'animated_background', 'assets/store_gifs/background/background_23.gif', 'rare', false, 'MSH-BACKGROUND-23', 725, 0),
    (4, 'big_background_24', 'خلفية ألعاب', 'animated_background', 'assets/store_gifs/background/background_24.gif', 'rare', false, 'MSH-BACKGROUND-24', 750, 0),
    (4, 'big_background_25', 'خلفية كريستال', 'animated_background', 'assets/store_gifs/background/background_25.gif', 'rare', false, 'MSH-BACKGROUND-25', 775, 0),
    (4, 'big_background_26', 'خلفية زجاجية', 'animated_background', 'assets/store_gifs/background/background_26.gif', 'epic', false, 'MSH-BACKGROUND-26', 800, 0),
    (4, 'big_background_27', 'خلفية عربية زخرفية', 'animated_background', 'assets/store_gifs/background/background_27.gif', 'epic', false, 'MSH-BACKGROUND-27', 825, 0),
    (4, 'big_background_28', 'خلفية هندسية', 'animated_background', 'assets/store_gifs/background/background_28.gif', 'epic', false, 'MSH-BACKGROUND-28', 850, 0),
    (4, 'big_background_29', 'خلفية شبكة اجتماعية', 'animated_background', 'assets/store_gifs/background/background_29.gif', 'epic', false, 'MSH-BACKGROUND-29', 875, 0),
    (4, 'big_background_30', 'خلفية تاجية', 'animated_background', 'assets/store_gifs/background/background_30.gif', 'epic', false, 'MSH-BACKGROUND-30', 900, 0),
    (4, 'big_background_31', 'خلفية ماسية سوداء', 'animated_background', 'assets/store_gifs/background/background_31.gif', 'epic', false, 'MSH-BACKGROUND-31', 925, 0),
    (4, 'big_background_32', 'خلفية وردية نيون', 'animated_background', 'assets/store_gifs/background/background_32.gif', 'epic', false, 'MSH-BACKGROUND-32', 950, 0),
    (4, 'big_background_33', 'خلفية قوس قزح هادئ', 'animated_background', 'assets/store_gifs/background/background_33.gif', 'epic', false, 'MSH-BACKGROUND-33', 975, 0),
    (4, 'big_background_34', 'خلفية فقاعات', 'animated_background', 'assets/store_gifs/background/background_34.gif', 'epic', false, 'MSH-BACKGROUND-34', 1000, 0),
    (4, 'big_background_35', 'خلفية صحراوية ذهبية', 'animated_background', 'assets/store_gifs/background/background_35.gif', 'epic', false, 'MSH-BACKGROUND-35', 1025, 0),
    (4, 'big_background_36', 'خلفية غابة مضيئة', 'animated_background', 'assets/store_gifs/background/background_36.gif', 'legendary', false, 'MSH-BACKGROUND-36', 1050, 0),
    (4, 'big_background_37', 'خلفية أجنحة', 'animated_background', 'assets/store_gifs/background/background_37.gif', 'legendary', false, 'MSH-BACKGROUND-37', 1075, 0),
    (4, 'big_background_38', 'خلفية ملكية حمراء', 'animated_background', 'assets/store_gifs/background/background_38.gif', 'legendary', false, 'MSH-BACKGROUND-38', 1100, 0),
    (4, 'big_background_39', 'خلفية سحرية', 'animated_background', 'assets/store_gifs/background/background_39.gif', 'legendary', false, 'MSH-BACKGROUND-39', 1125, 0),
    (4, 'big_background_40', 'خلفية احتفالية', 'animated_background', 'assets/store_gifs/background/background_40.gif', 'legendary', false, 'MSH-BACKGROUND-40', 1150, 0),
    (4, 'big_background_41', 'خلفية مطر زجاجي', 'animated_background', 'assets/store_gifs/background/background_41.gif', 'legendary', false, 'MSH-BACKGROUND-41', 1175, 0),
    (4, 'big_background_42', 'خلفية فضة', 'animated_background', 'assets/store_gifs/background/background_42.gif', 'legendary', false, 'MSH-BACKGROUND-42', 1200, 0),
    (4, 'big_background_43', 'خلفية لؤلؤ', 'animated_background', 'assets/store_gifs/background/background_43.gif', 'legendary', false, 'MSH-BACKGROUND-43', 1225, 0),
    (4, 'big_background_44', 'خلفية شاشة رقمية', 'animated_background', 'assets/store_gifs/background/background_44.gif', 'legendary', false, 'MSH-BACKGROUND-44', 1250, 0),
    (4, 'big_background_45', 'خلفية رقص ألوان', 'animated_background', 'assets/store_gifs/background/background_45.gif', 'legendary', false, 'MSH-BACKGROUND-45', 1275, 0),
    (4, 'big_background_46', 'خلفية هالة مركزية', 'animated_background', 'assets/store_gifs/background/background_46.gif', 'mythic', false, 'MSH-BACKGROUND-46', 1300, 0),
    (4, 'big_background_47', 'خلفية ظل ووميض', 'animated_background', 'assets/store_gifs/background/background_47.gif', 'mythic', false, 'MSH-BACKGROUND-47', 1325, 0),
    (4, 'big_background_48', 'خلفية شرارات', 'animated_background', 'assets/store_gifs/background/background_48.gif', 'mythic', false, 'MSH-BACKGROUND-48', 1350, 0),
    (4, 'big_background_49', 'خلفية فخامة سوداء', 'animated_background', 'assets/store_gifs/background/background_49.gif', 'mythic', false, 'MSH-BACKGROUND-49', 1375, 0),
    (4, 'big_background_50', 'خلفية VIP ديناميكية', 'animated_background', 'assets/store_gifs/background/background_50.gif', 'mythic', false, 'MSH-BACKGROUND-50', 1400, 0);

insert into public.store_items (
    section_id,
    code,
    name,
    description,
    item_type,
    asset_url,
    metadata,
    is_active,
    is_limited,
    stock_quantity,
    sort_order
)
select
    s.section_id,
    s.code,
    s.name,
    null,
    s.item_type,
    s.asset_url,
    jsonb_build_object(
        'sku', s.sku,
        'rarity', s.rarity,
        'isFeatured', s.is_featured,
        'source', 'BigStoreCatalog'
    ),
    true,
    false,
    null,
    row_number() over (
        partition by s.section_id
        order by s.code
    )::integer
from tmp_big_store_seed s
where not exists (
    select 1
    from public.store_items x
    where x.code = s.code
);

insert into public.store_item_prices (
    item_id,
    currency,
    amount,
    is_active,
    effective_from,
    created_by
)
select
    i.id,
    'points',
    s.price_points,
    true,
    now(),
    '1e0eb6a1-640f-49f0-830c-aba188cd55a2'
from public.store_items i
join tmp_big_store_seed s
    on s.code = i.code
where not exists (
    select 1
    from public.store_item_prices p
    where p.item_id = i.id
      and p.currency = 'points'
      and p.is_active = true
);

insert into public.store_item_prices (
    item_id,
    currency,
    amount,
    is_active,
    effective_from,
    created_by
)
select
    i.id,
    'gems',
    s.price_gems,
    true,
    now(),
    '1e0eb6a1-640f-49f0-830c-aba188cd55a2'
from public.store_items i
join tmp_big_store_seed s
    on s.code = i.code
where not exists (
    select 1
    from public.store_item_prices p
    where p.item_id = i.id
      and p.currency = 'gems'
      and p.is_active = true
);

commit;
