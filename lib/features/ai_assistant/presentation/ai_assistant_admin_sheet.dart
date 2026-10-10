import 'package:flutter/material.dart';

import '../data/ai_assistant_service.dart';

const _bg = Color(0xFF17101F);
const _card = Color(0xFF241733);
const _gold = Color(0xFFFFD700);

/// لوحة المالك: سعر السؤال بالنقاط، الحصة اليومية المجانية، حد الطلبات في
/// الساعة، تشغيل/إيقاف الخدمة، والباقات التي تحصل عليها مجانًا.
class AiAssistantAdminSheet extends StatefulWidget {
  const AiAssistantAdminSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AiAssistantAdminSheet(),
      );

  @override
  State<AiAssistantAdminSheet> createState() => _AiAssistantAdminSheetState();
}

class _AiAssistantAdminSheetState extends State<AiAssistantAdminSheet> {
  AiAdminConfig? _cfg;
  final _cost = TextEditingController();
  final _imgCost = TextEditingController();
  final _free = TextEditingController();
  final _hourly = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cost.dispose();
    _imgCost.dispose();
    _free.dispose();
    _hourly.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await AiAssistantService.adminGet();
      if (!mounted) return;
      setState(() {
        _cfg = c;
        _cost.text = '${c.costPoints}';
        _imgCost.text = '${c.imageCostPoints}';
        _free.text = '${c.freeDaily}';
        _hourly.text = '${c.hourlyLimit}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الإعدادات.');
    }
  }

  Future<void> _save() async {
    final c = _cfg;
    if (c == null) return;
    final cost = int.tryParse(_cost.text.trim());
    final free = int.tryParse(_free.text.trim());
    final hourly = int.tryParse(_hourly.text.trim());
    final imgCost = int.tryParse(_imgCost.text.trim());
    if (imgCost == null || imgCost < 0 || cost == null || free == null || hourly == null || cost < 0 || free < 0 || hourly < 1) {
      setState(() => _error = 'أدخل أرقامًا صحيحة.');
      return;
    }
    c
      ..costPoints = cost
      ..imageCostPoints = imgCost
      ..freeDaily = free
      ..hourlyLimit = hourly;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AiAssistantService.adminSave(c);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر الحفظ.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = _cfg;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          // Material شفاف بين الخلفية الملوّنة والـ ListTile (وإلا يخفي الـ
          // DecoratedBox تأثيرات اللمس ويرمي assertion).
          child: Material(
            type: MaterialType.transparency,
            child: c == null
              ? SizedBox(
                  height: 180,
                  child: Center(
                    child: _error != null
                        ? Text(_error!, style: const TextStyle(color: Colors.redAccent))
                        : const CircularProgressIndicator(color: _gold),
                  ),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('إعدادات المساعد الذكي',
                        style: TextStyle(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: c.enabled,
                      activeColor: _gold,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الخدمة مفعّلة',
                          style: TextStyle(color: Colors.white)),
                      onChanged: (v) => setState(() => c.enabled = v),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cost,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('سعر السؤال بالنقاط (بعد انتهاء الحصة المجانية)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imgCost,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('سعر توليد الصورة بالنقاط (المالك والمشتركون مجانًا)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _free,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('الأسئلة المجانية يوميًا لغير المشتركين'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _hourly,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('الحد الأقصى لأسئلة المستخدم في الساعة'),
                    ),
                    const SizedBox(height: 14),
                    const Text('الباقات التي تحصل على الخدمة مجانًا',
                        style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                    for (final t in c.tiers)
                      CheckboxListTile(
                        value: t.included,
                        activeColor: _gold,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(t.name, style: const TextStyle(color: Colors.white)),
                        onChanged: (v) => setState(() => t.included = v ?? false),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold, foregroundColor: Colors.black),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('حفظ'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
